import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:pointycastle/export.dart';
import 'instance_manager.dart';
import '../models/service_instance.dart';

// ============================================================================
// Top-level functions for isolate execution
// ============================================================================

/// Encrypts data in an isolate to keep UI responsive
Future<Map<String, dynamic>> _encryptInIsolate(
  Map<String, dynamic> params,
) async {
  final dataJson = params['dataJson'] as String;
  final password = params['password'] as String;

  // Generate encryption parameters
  final salt = _generateSaltSync();
  final key = _deriveKeySync(password, salt);
  final iv = _generateIVSync();

  // Encrypt with AES-GCM
  final encrypter = encrypt_lib.Encrypter(
    encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
  );
  final encrypted = encrypter.encrypt(dataJson, iv: iv);

  return {
    'salt': base64Encode(salt),
    'iv': iv.base64,
    'encryptedData': encrypted.base64,
    'mac': encrypted.base16,
  };
}

/// Decrypts and validates data in an isolate
Future<Map<String, dynamic>> _decryptInIsolate(
  Map<String, dynamic> params,
) async {
  final password = params['password'] as String;
  final salt = base64Decode(params['salt'] as String);
  final iv = encrypt_lib.IV.fromBase64(params['iv'] as String);
  final encryptedData = encrypt_lib.Encrypted.fromBase64(
    params['encryptedData'] as String,
  );
  final version = params['version'] as int;

  // Derive key
  final key = _deriveKeySync(password, salt);

  // Decrypt
  final mode = version == 2 ? encrypt_lib.AESMode.gcm : encrypt_lib.AESMode.cbc;
  final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key, mode: mode));

  try {
    final decryptedJson = encrypter.decrypt(encryptedData, iv: iv);
    final data = jsonDecode(decryptedJson) as Map<String, dynamic>;
    return {'success': true, 'data': data};
  } catch (e) {
    return {'success': false, 'error': 'Invalid password or corrupted file'};
  }
}

/// Synchronous salt generation for isolate use
Uint8List _generateSaltSync() {
  final random = Random.secure();
  final salt = Uint8List(16);
  for (int i = 0; i < salt.length; i++) {
    salt[i] = random.nextInt(256);
  }
  return salt;
}

/// Synchronous IV generation for isolate use
encrypt_lib.IV _generateIVSync() {
  final random = Random.secure();
  final ivBytes = Uint8List(12);
  for (int i = 0; i < ivBytes.length; i++) {
    ivBytes[i] = random.nextInt(256);
  }
  return encrypt_lib.IV(ivBytes);
}

/// Synchronous PBKDF2 key derivation for isolate use
encrypt_lib.Key _deriveKeySync(String password, Uint8List salt) {
  final hmac = HMac(SHA256Digest(), 64);
  final derivator = PBKDF2KeyDerivator(hmac);
  derivator.init(Pbkdf2Parameters(salt, 600000, 32));
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final key = derivator.process(passwordBytes);
  return encrypt_lib.Key(key);
}

// ============================================================================
// BackupService class
// ============================================================================

/// Service for encrypting and exporting/importing instance configurations
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final InstanceManager _instanceManager = InstanceManager();

  /// Exports all instances to encrypted JSON bytes
  /// Returns the encrypted data as Uint8List
  /// Runs encryption in isolate to keep UI responsive
  Future<Uint8List> exportInstances(String password) async {
    // Get all instances
    final sonarrInstances = await _instanceManager.getSonarrInstances();
    final radarrInstances = await _instanceManager.getRadarrInstances();
    final activeSonarrId = _instanceManager.getActiveSonarrId();
    final activeRadarrId = _instanceManager.getActiveRadarrId();

    // Prepare data to export
    final data = {
      'sonarrInstances': sonarrInstances.map((i) => i.toJson()).toList(),
      'radarrInstances': radarrInstances.map((i) => i.toJson()).toList(),
      'activeSonarrId': activeSonarrId,
      'activeRadarrId': activeRadarrId,
    };

    final dataJson = jsonEncode(data);

    // Run expensive encryption in isolate to keep UI responsive
    final encryptionResult = await compute(_encryptInIsolate, {
      'dataJson': dataJson,
      'password': password,
    });

    // Create export file structure
    final exportData = {
      'version': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'salt': encryptionResult['salt'],
      'iv': encryptionResult['iv'],
      'encryptedData': encryptionResult['encryptedData'],
      'mac': encryptionResult['mac'],
    };

    // Return encrypted JSON as bytes
    final jsonString = jsonEncode(exportData);
    return utf8.encode(jsonString);
  }

  /// Imports instances from an encrypted JSON file
  /// Returns number of instances imported
  /// Runs decryption in isolate to keep UI responsive
  Future<Map<String, int>> importInstances(
    String password,
    String filePath,
  ) async {
    // Read file
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final fileContent = await file.readAsString();
    final exportData = jsonDecode(fileContent) as Map<String, dynamic>;

    // Validate version
    final version = exportData['version'] as int?;
    if (version != 1 && version != 2) {
      throw Exception('Unsupported backup version: $version');
    }

    // Run expensive decryption in isolate to keep UI responsive
    final result = await compute(_decryptInIsolate, {
      'password': password,
      'salt': exportData['salt'],
      'iv': exportData['iv'],
      'encryptedData': exportData['encryptedData'],
      'version': version,
    });

    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Invalid password or corrupted file');
    }

    final data = result['data'] as Map<String, dynamic>;

    // Parse instances
    final sonarrList =
        (data['sonarrInstances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final radarrList =
        (data['radarrInstances'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Import instances (this will overwrite existing ones with same IDs)
    int sonarrCount = 0;
    for (final instanceData in sonarrList) {
      final instance = ServiceInstance.fromJson(instanceData);
      final existing = await _instanceManager.getSonarrInstances();
      final exists = existing.any((i) => i.id == instance.id);

      if (exists) {
        await _instanceManager.updateSonarrInstance(instance);
      } else {
        await _instanceManager.addSonarrInstance(instance);
      }
      sonarrCount++;
    }

    int radarrCount = 0;
    for (final instanceData in radarrList) {
      final instance = ServiceInstance.fromJson(instanceData);
      final existing = await _instanceManager.getRadarrInstances();
      final exists = existing.any((i) => i.id == instance.id);

      if (exists) {
        await _instanceManager.updateRadarrInstance(instance);
      } else {
        await _instanceManager.addRadarrInstance(instance);
      }
      radarrCount++;
    }

    // Set active instances if they were saved
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

  /// Validates a backup file and password without importing
  /// Runs decryption in isolate to keep UI responsive
  Future<Map<String, dynamic>> validateBackup(
    String password,
    String filePath,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final fileContent = await file.readAsString();
    final exportData = jsonDecode(fileContent) as Map<String, dynamic>;

    // Validate version
    final version = exportData['version'] as int?;
    if (version != 1 && version != 2) {
      throw Exception('Unsupported backup version: $version');
    }

    final exportDate = exportData['exportDate'] as String;

    // Run expensive decryption in isolate to keep UI responsive
    final result = await compute(_decryptInIsolate, {
      'password': password,
      'salt': exportData['salt'],
      'iv': exportData['iv'],
      'encryptedData': exportData['encryptedData'],
      'version': version,
    });

    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Invalid password');
    }

    final data = result['data'] as Map<String, dynamic>;

    // Count instances
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
