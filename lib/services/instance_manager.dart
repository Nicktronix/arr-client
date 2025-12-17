import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/service_instance.dart';

class InstanceManager {
  // Keys for non-sensitive data (instance list structure without credentials)
  static const String _sonarrInstancesKey = 'sonarr_instances';
  static const String _radarrInstancesKey = 'radarr_instances';
  static const String _activeSonarrKey = 'active_sonarr_id';
  static const String _activeRadarrKey = 'active_radarr_id';

  // Singleton
  static final InstanceManager _instance = InstanceManager._internal();
  factory InstanceManager() => _instance;
  InstanceManager._internal();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('InstanceManager not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// Save sensitive instance credentials to secure storage
  Future<void> _saveInstanceCredentials(
    ServiceInstance instance,
    String serviceType,
  ) async {
    final prefix = '${serviceType}_${instance.id}';
    await _secureStorage.write(key: '${prefix}_apiKey', value: instance.apiKey);
    if (instance.basicAuthUsername != null) {
      await _secureStorage.write(
        key: '${prefix}_basicAuthUsername',
        value: instance.basicAuthUsername,
      );
    }
    if (instance.basicAuthPassword != null) {
      await _secureStorage.write(
        key: '${prefix}_basicAuthPassword',
        value: instance.basicAuthPassword,
      );
    }
  }

  /// Load sensitive credentials from secure storage
  Future<ServiceInstance> _loadInstanceCredentials(
    Map<String, dynamic> instanceData,
    String serviceType,
  ) async {
    final prefix = '${serviceType}_${instanceData['id']}';
    final apiKey = await _secureStorage.read(key: '${prefix}_apiKey') ?? '';
    final basicAuthUsername = await _secureStorage.read(
      key: '${prefix}_basicAuthUsername',
    );
    final basicAuthPassword = await _secureStorage.read(
      key: '${prefix}_basicAuthPassword',
    );

    return ServiceInstance(
      id: instanceData['id'] as String,
      name: instanceData['name'] as String,
      baseUrl: instanceData['baseUrl'] as String,
      apiKey: apiKey,
      basicAuthUsername: basicAuthUsername,
      basicAuthPassword: basicAuthPassword,
    );
  }

  /// Delete credentials from secure storage
  Future<void> _deleteInstanceCredentials(
    String instanceId,
    String serviceType,
  ) async {
    final prefix = '${serviceType}_$instanceId';
    await _secureStorage.delete(key: '${prefix}_apiKey');
    await _secureStorage.delete(key: '${prefix}_basicAuthUsername');
    await _secureStorage.delete(key: '${prefix}_basicAuthPassword');
  }

  // Sonarr Instances
  Future<List<ServiceInstance>> getSonarrInstances() async {
    final jsonString = _preferences.getString(_sonarrInstancesKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    final List<ServiceInstance> instances = [];

    for (var json in jsonList) {
      final instance = await _loadInstanceCredentials(json, 'sonarr');
      instances.add(instance);
    }

    return instances;
  }

  /// Fast method to get instance metadata only (no credentials from secure storage)
  /// Use this for listing instances in settings where credentials aren't needed
  List<Map<String, dynamic>> getSonarrInstancesMetadata() {
    final jsonString = _preferences.getString(_sonarrInstancesKey);
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
  }

  Future<void> saveSonarrInstances(List<ServiceInstance> instances) async {
    // Save non-sensitive metadata to SharedPreferences
    final jsonList = instances
        .map((i) => {'id': i.id, 'name': i.name, 'baseUrl': i.baseUrl})
        .toList();
    await _preferences.setString(_sonarrInstancesKey, jsonEncode(jsonList));

    // Save sensitive credentials to secure storage
    for (var instance in instances) {
      await _saveInstanceCredentials(instance, 'sonarr');
    }
  }

  Future<void> addSonarrInstance(ServiceInstance instance) async {
    final instances = await getSonarrInstances();
    instances.add(instance);
    await saveSonarrInstances(instances);

    // If this is the first instance, make it active
    if (instances.length == 1) {
      await setActiveSonarrId(instance.id);
    }
  }

  Future<void> updateSonarrInstance(ServiceInstance instance) async {
    final instances = await getSonarrInstances();
    final index = instances.indexWhere((i) => i.id == instance.id);
    if (index != -1) {
      instances[index] = instance;
      await saveSonarrInstances(instances);
    }
  }

  Future<void> deleteSonarrInstance(String id) async {
    final instances = await getSonarrInstances();
    instances.removeWhere((i) => i.id == id);
    await saveSonarrInstances(instances);

    // Delete credentials from secure storage
    await _deleteInstanceCredentials(id, 'sonarr');

    // If we deleted the active instance, clear it or set to first available
    final activeId = getActiveSonarrId();
    if (activeId == id) {
      if (instances.isNotEmpty) {
        await setActiveSonarrId(instances.first.id);
      } else {
        await _preferences.remove(_activeSonarrKey);
      }
    }
  }

  // Radarr Instances
  Future<List<ServiceInstance>> getRadarrInstances() async {
    final jsonString = _preferences.getString(_radarrInstancesKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    final List<ServiceInstance> instances = [];

    for (var json in jsonList) {
      final instance = await _loadInstanceCredentials(json, 'radarr');
      instances.add(instance);
    }

    return instances;
  }

  /// Fast method to get instance metadata only (no credentials from secure storage)
  /// Use this for listing instances in settings where credentials aren't needed
  List<Map<String, dynamic>> getRadarrInstancesMetadata() {
    final jsonString = _preferences.getString(_radarrInstancesKey);
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
  }

  Future<void> saveRadarrInstances(List<ServiceInstance> instances) async {
    // Save non-sensitive metadata to SharedPreferences
    final jsonList = instances
        .map((i) => {'id': i.id, 'name': i.name, 'baseUrl': i.baseUrl})
        .toList();
    await _preferences.setString(_radarrInstancesKey, jsonEncode(jsonList));

    // Save sensitive credentials to secure storage
    for (var instance in instances) {
      await _saveInstanceCredentials(instance, 'radarr');
    }
  }

  Future<void> addRadarrInstance(ServiceInstance instance) async {
    final instances = await getRadarrInstances();
    instances.add(instance);
    await saveRadarrInstances(instances);

    // If this is the first instance, make it active
    if (instances.length == 1) {
      await setActiveRadarrId(instance.id);
    }
  }

  Future<void> updateRadarrInstance(ServiceInstance instance) async {
    final instances = await getRadarrInstances();
    final index = instances.indexWhere((i) => i.id == instance.id);
    if (index != -1) {
      instances[index] = instance;
      await saveRadarrInstances(instances);
    }
  }

  Future<void> deleteRadarrInstance(String id) async {
    final instances = await getRadarrInstances();
    instances.removeWhere((i) => i.id == id);
    await saveRadarrInstances(instances);

    // Delete credentials from secure storage
    await _deleteInstanceCredentials(id, 'radarr');

    // If we deleted the active instance, clear it or set to first available
    final activeId = getActiveRadarrId();
    if (activeId == id) {
      if (instances.isNotEmpty) {
        await setActiveRadarrId(instances.first.id);
      } else {
        await _preferences.remove(_activeRadarrKey);
      }
    }
  }

  // Active Instance IDs
  String? getActiveSonarrId() {
    return _preferences.getString(_activeSonarrKey);
  }

  Future<void> setActiveSonarrId(String id) async {
    await _preferences.setString(_activeSonarrKey, id);
  }

  String? getActiveRadarrId() {
    return _preferences.getString(_activeRadarrKey);
  }

  Future<void> setActiveRadarrId(String id) async {
    await _preferences.setString(_activeRadarrKey, id);
  }

  // Get Active Instances
  Future<ServiceInstance?> getActiveSonarrInstance() async {
    final activeId = getActiveSonarrId();
    if (activeId == null) return null;

    final instances = await getSonarrInstances();
    try {
      return instances.firstWhere((i) => i.id == activeId);
    } catch (e) {
      return null;
    }
  }

  Future<ServiceInstance?> getActiveRadarrInstance() async {
    final activeId = getActiveRadarrId();
    if (activeId == null) return null;

    final instances = await getRadarrInstances();
    try {
      return instances.firstWhere((i) => i.id == activeId);
    } catch (e) {
      return null;
    }
  }
}
