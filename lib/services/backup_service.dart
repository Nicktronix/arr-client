import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:arr_client/services/instance_manager.dart';
import 'package:arr_client/models/service_instance.dart';

// ============================================================================
// Top-level functions for isolate execution
// ============================================================================

Future<Map<String, dynamic>> _encryptInIsolate(
  Map<String, dynamic> params,
) async {
  final dataJson = params['dataJson'] as String;
  final password = params['password'] as String;

  final salt = _randomBytes(16);
  final iv = _randomBytes(12);
  final key = await _deriveKey(password, salt);

  final algorithm = AesGcm.with256bits(nonceLength: 12);
  final secretBox = await algorithm.encrypt(
    utf8.encode(dataJson),
    secretKey: key,
    nonce: iv,
  );

  // Concatenate ciphertext + 16-byte GCM tag — consistent with v2 format
  final encryptedBytes = Uint8List.fromList([
    ...secretBox.cipherText,
    ...secretBox.mac.bytes,
  ]);

  return {
    'salt': base64Encode(salt),
    'iv': base64Encode(iv),
    'encryptedData': base64Encode(encryptedBytes),
  };
}

Future<Map<String, dynamic>> _decryptInIsolate(
  Map<String, dynamic> params,
) async {
  final password = params['password'] as String;
  final salt = base64Decode(params['salt'] as String);
  final iv = base64Decode(params['iv'] as String);
  final encryptedBytes = base64Decode(params['encryptedData'] as String);
  final version = params['version'] as int;

  final key = await _deriveKey(password, salt);

  try {
    final List<int> plainBytes;

    if (version == 1) {
      // Legacy AES-CBC (no authentication tag)
      final algorithm = AesCbc.with256bits(
        macAlgorithm: MacAlgorithm.empty,
      );
      final secretBox = SecretBox(
        encryptedBytes,
        nonce: iv,
        mac: Mac.empty,
      );
      plainBytes = await algorithm.decrypt(secretBox, secretKey: key);
    } else {
      // AES-GCM: ciphertext || 16-byte tag
      if (encryptedBytes.length < 16) throw Exception('Invalid data length');
      final cipherText = encryptedBytes.sublist(0, encryptedBytes.length - 16);
      final tag = encryptedBytes.sublist(encryptedBytes.length - 16);
      final algorithm = AesGcm.with256bits(nonceLength: iv.length);
      final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));
      plainBytes = await algorithm.decrypt(secretBox, secretKey: key);
    }

    final data = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
    return {'success': true, 'data': data};
  } catch (e) {
    return {'success': false, 'error': 'Invalid password or corrupted file'};
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List.generate(length, (_) => random.nextInt(256)),
  );
}

Future<SecretKey> _deriveKey(String password, Uint8List salt) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );
  return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
}

// ============================================================================
// BackupService class
// ============================================================================

@lazySingleton
class BackupService {
  final InstanceManager _instanceManager;

  BackupService(this._instanceManager);

  /// Exports all instances to encrypted JSON bytes.
  /// Runs encryption in an isolate to keep the UI responsive.
  Future<Uint8List> exportInstances(String password) async {
    final sonarrInstances = await _instanceManager.getSonarrInstances();
    final radarrInstances = await _instanceManager.getRadarrInstances();
    final activeSonarrId = _instanceManager.getActiveSonarrId();
    final activeRadarrId = _instanceManager.getActiveRadarrId();

    final data = {
      'sonarrInstances': sonarrInstances.map((i) => i.toJson()).toList(),
      'radarrInstances': radarrInstances.map((i) => i.toJson()).toList(),
      'activeSonarrId': activeSonarrId,
      'activeRadarrId': activeRadarrId,
    };

    final encryptionResult = await compute(_encryptInIsolate, {
      'dataJson': jsonEncode(data),
      'password': password,
    });

    final exportData = {
      'version': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'salt': encryptionResult['salt'],
      'iv': encryptionResult['iv'],
      'encryptedData': encryptionResult['encryptedData'],
    };

    return utf8.encode(jsonEncode(exportData));
  }

  /// Imports instances from an encrypted JSON file.
  /// Returns a map of counts: `{'sonarr': n, 'radarr': n}`.
  /// Runs decryption in an isolate to keep the UI responsive.
  Future<Map<String, int>> importInstances(
    String password,
    String filePath,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found');
    }

    final exportData =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final version = exportData['version'] as int?;
    if (version != 1 && version != 2) {
      throw Exception('Unsupported backup version: $version');
    }

    final result = await compute(_decryptInIsolate, {
      'password': password,
      'salt': exportData['salt'],
      'iv': exportData['iv'],
      'encryptedData': exportData['encryptedData'],
      'version': version,
    });

    if (result['success'] != true) {
      throw Exception(
        (result['error'] as String?) ?? 'Invalid password or corrupted file',
      );
    }

    final data = result['data'] as Map<String, dynamic>;

    final sonarrList =
        (data['sonarrInstances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final radarrList =
        (data['radarrInstances'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    var sonarrCount = 0;
    for (final instanceData in sonarrList) {
      final instance = ServiceInstance.fromJson(instanceData);
      final existing = await _instanceManager.getSonarrInstances();
      if (existing.any((i) => i.id == instance.id)) {
        await _instanceManager.updateSonarrInstance(instance);
      } else {
        await _instanceManager.addSonarrInstance(instance);
      }
      sonarrCount++;
    }

    var radarrCount = 0;
    for (final instanceData in radarrList) {
      final instance = ServiceInstance.fromJson(instanceData);
      final existing = await _instanceManager.getRadarrInstances();
      if (existing.any((i) => i.id == instance.id)) {
        await _instanceManager.updateRadarrInstance(instance);
      } else {
        await _instanceManager.addRadarrInstance(instance);
      }
      radarrCount++;
    }

    final activeSonarrId = data['activeSonarrId'] as String?;
    final activeRadarrId = data['activeRadarrId'] as String?;

    if (activeSonarrId != null) {
      await _instanceManager.setActiveSonarrId(activeSonarrId);
    }
    if (activeRadarrId != null) {
      await _instanceManager.setActiveRadarrId(activeRadarrId);
    }

    return {'sonarr': sonarrCount, 'radarr': radarrCount};
  }

  /// Validates a backup file and password without importing.
  /// Runs decryption in an isolate to keep the UI responsive.
  Future<Map<String, dynamic>> validateBackup(
    String password,
    String filePath,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found');
    }

    final exportData =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final version = exportData['version'] as int?;
    if (version != 1 && version != 2) {
      throw Exception('Unsupported backup version: $version');
    }

    final exportDate = exportData['exportDate'] as String;

    final result = await compute(_decryptInIsolate, {
      'password': password,
      'salt': exportData['salt'],
      'iv': exportData['iv'],
      'encryptedData': exportData['encryptedData'],
      'version': version,
    });

    if (result['success'] != true) {
      throw Exception(
        (result['error'] as String?) ?? 'Invalid password',
      );
    }

    final data = result['data'] as Map<String, dynamic>;

    final sonarrList =
        (data['sonarrInstances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final radarrList =
        (data['radarrInstances'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return {
      'valid': true,
      'exportDate': exportDate,
      'sonarrCount': sonarrList.length,
      'radarrCount': radarrList.length,
      'activeSonarrId': data['activeSonarrId'],
      'activeRadarrId': data['activeRadarrId'],
    };
  }
}
