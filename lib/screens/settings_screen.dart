import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/instance_manager.dart';
import '../services/app_state_manager.dart';
import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/backup_service.dart';
import '../models/service_instance.dart';
import '../utils/error_formatter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InstanceManager _instanceManager = InstanceManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.tv), text: 'Sonarr'),
            Tab(icon: Icon(Icons.movie), text: 'Radarr'),
            Tab(icon: Icon(Icons.security), text: 'Security'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InstanceListTab(
            serviceType: 'sonarr',
            instanceManager: _instanceManager,
          ),
          _InstanceListTab(
            serviceType: 'radarr',
            instanceManager: _instanceManager,
          ),
          const _SecuritySettingsTab(),
        ],
      ),
    );
  }
}

class _InstanceListTab extends StatefulWidget {
  final String serviceType; // 'sonarr' or 'radarr'
  final InstanceManager instanceManager;

  const _InstanceListTab({
    required this.serviceType,
    required this.instanceManager,
  });

  @override
  State<_InstanceListTab> createState() => _InstanceListTabState();
}

class _InstanceListTabState extends State<_InstanceListTab> {
  final AppStateManager _appState = AppStateManager();
  List<ServiceInstance> _instances = [];
  String? _activeInstanceId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstances();
  }

  Future<void> _loadInstances() async {
    setState(() => _isLoading = true);

    try {
      // Use fast metadata-only methods - no secure storage access needed
      final instancesMetadata = widget.serviceType == 'sonarr'
          ? widget.instanceManager.getSonarrInstancesMetadata()
          : widget.instanceManager.getRadarrInstancesMetadata();

      final activeId = widget.serviceType == 'sonarr'
          ? widget.instanceManager.getActiveSonarrId()
          : widget.instanceManager.getActiveRadarrId();

      // Convert metadata to ServiceInstance objects (no credentials needed for display)
      final instances = instancesMetadata
          .map(
            (json) => ServiceInstance(
              id: json['id'] as String,
              name: json['name'] as String,
              baseUrl: json['baseUrl'] as String,
              apiKey: '', // Not needed for display
              basicAuthUsername: null,
              basicAuthPassword: null,
            ),
          )
          .toList();

      setState(() {
        _instances = instances;
        _activeInstanceId = activeId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading instances: ${ErrorFormatter.format(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _setActiveInstance(String instanceId) async {
    // Update UI immediately for instant feedback
    setState(() => _activeInstanceId = instanceId);

    try {
      if (widget.serviceType == 'sonarr') {
        // Use consistent switchInstance method
        await _appState.switchSonarrInstance(instanceId);
      } else {
        // Use consistent switchInstance method
        await _appState.switchRadarrInstance(instanceId);
      }
    } catch (e) {
      // Revert radio button on error
      setState(
        () => _activeInstanceId = widget.serviceType == 'sonarr'
            ? widget.instanceManager.getActiveSonarrId()
            : widget.instanceManager.getActiveRadarrId(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ErrorFormatter.format(e)}')),
        );
      }
    }
  }

  Future<void> _deleteInstance(ServiceInstance instance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Instance'),
        content: Text('Are you sure you want to delete "${instance.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (widget.serviceType == 'sonarr') {
        await widget.instanceManager.deleteSonarrInstance(instance.id);
      } else {
        await widget.instanceManager.deleteRadarrInstance(instance.id);
      }

      await _loadInstances();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Instance deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting instance: ${ErrorFormatter.format(e)}',
            ),
          ),
        );
      }
    }
  }

  void _showAddEditDialog({ServiceInstance? instance}) {
    showDialog(
      context: context,
      builder: (context) => _InstanceFormDialog(
        serviceType: widget.serviceType,
        instanceManager: widget.instanceManager,
        instance: instance,
        onSaved: _loadInstances,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_instances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.serviceType == 'sonarr' ? Icons.tv : Icons.movie,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.serviceType == 'sonarr' ? 'Sonarr' : 'Radarr'} instances',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an instance to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Instance'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RadioGroup<String>(
            groupValue: _activeInstanceId,
            onChanged: (value) {
              if (value != null) _setActiveInstance(value);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _instances.length,
              itemBuilder: (context, index) {
                final instance = _instances[index];
                final isActive = instance.id == _activeInstanceId;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: Radio<String>(value: instance.id),
                    title: Text(
                      instance.name,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      instance.baseUrl,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          const Chip(
                            label: Text(
                              'Active',
                              style: TextStyle(fontSize: 11),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () =>
                              _showAddEditDialog(instance: instance),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _deleteInstance(instance),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Instance'),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstanceFormDialog extends StatefulWidget {
  final String serviceType;
  final InstanceManager instanceManager;
  final ServiceInstance? instance;
  final VoidCallback onSaved;

  const _InstanceFormDialog({
    required this.serviceType,
    required this.instanceManager,
    this.instance,
    required this.onSaved,
  });

  @override
  State<_InstanceFormDialog> createState() => _InstanceFormDialogState();
}

class _InstanceFormDialogState extends State<_InstanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _basicAuthUsernameController;
  late TextEditingController _basicAuthPasswordController;
  bool _isSaving = false;
  bool _useBasicAuth = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.instance?.name ?? '');
    _urlController = TextEditingController(
      text: widget.instance?.baseUrl ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.instance?.apiKey ?? '',
    );
    _basicAuthUsernameController = TextEditingController(
      text: widget.instance?.basicAuthUsername ?? '',
    );
    _basicAuthPasswordController = TextEditingController(
      text: widget.instance?.basicAuthPassword ?? '',
    );
    _useBasicAuth = widget.instance?.basicAuthUsername?.isNotEmpty == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _basicAuthUsernameController.dispose();
    _basicAuthPasswordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final baseUrl = _urlController.text.trim();
      final apiKey = _apiKeyController.text.trim();
      final basicAuthUsername = _useBasicAuth
          ? _basicAuthUsernameController.text.trim()
          : null;
      final basicAuthPassword = _useBasicAuth
          ? _basicAuthPasswordController.text.trim()
          : null;

      // Import services to test connection
      final ApiClient client = ApiClient(
        baseUrl: baseUrl,
        apiKey: apiKey,
        basicAuthUsername: basicAuthUsername,
        basicAuthPassword: basicAuthPassword,
      );

      // Try to get system status to verify connection
      final response = await client.get('/system/status');
      final appName = response['appName'] ?? 'Unknown';
      final version = response['version'] ?? 'Unknown';

      setState(() {
        _testResult = 'Success! Connected to $appName v$version';
        _isTesting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_testResult!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _testResult = 'Failed: ${ErrorFormatter.format(e)}';
        _isTesting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_testResult!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showHttpWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('Insecure Connection'),
        content: const Text(
          'You are using HTTP instead of HTTPS. This means your API key and credentials '
          'will be sent in plain text over the network.\n\n'
          'This is only safe for local network connections (e.g., 192.168.x.x or localhost).\n\n'
          'For remote instances, please use HTTPS to protect your credentials.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );

    if (result != true) {
      setState(() => _isSaving = false);
    } else {
      await _performSave();
    }
  }

  Future<void> _performSave() async {
    try {
      final instance = ServiceInstance(
        id:
            widget.instance?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        baseUrl: _urlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        basicAuthUsername: _useBasicAuth
            ? _basicAuthUsernameController.text.trim()
            : null,
        basicAuthPassword: _useBasicAuth
            ? _basicAuthPasswordController.text.trim()
            : null,
      );

      if (widget.instance != null) {
        // Update existing
        if (widget.serviceType == 'sonarr') {
          await widget.instanceManager.updateSonarrInstance(instance);
        } else {
          await widget.instanceManager.updateRadarrInstance(instance);
        }
      } else {
        // Add new
        if (widget.serviceType == 'sonarr') {
          await widget.instanceManager.addSonarrInstance(instance);
        } else {
          await widget.instanceManager.addRadarrInstance(instance);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.instance != null ? 'Instance updated' : 'Instance added',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ErrorFormatter.format(e)}')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Check if using HTTP (not HTTPS)
    final baseUrl = _urlController.text.trim().toLowerCase();
    if (baseUrl.startsWith('http://') &&
        !baseUrl.contains('localhost') &&
        !baseUrl.contains('127.0.0.1')) {
      // Show warning and let user decide
      await _showHttpWarning();
      return;
    }

    await _performSave();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.instance != null ? 'Edit Instance' : 'Add Instance'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Home Sonarr',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://sonarr.example.com',
                  helperText: 'Do not include /api/v3 at the end',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'URL is required';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'URL must start with http:// or https://';
                  }
                  if (value.contains('/api')) {
                    return 'Remove /api or /api/v3 from URL';
                  }
                  if (value.endsWith('/')) {
                    _urlController.text = value.substring(0, value.length - 1);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  helperText: 'Found in Settings → General → Security',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                maxLength: 32,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'API Key is required';
                  }
                  if (value.length != 32) {
                    return 'API Key should be 32 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Use Basic Authentication'),
                subtitle: const Text(
                  'Only needed if your instance is behind a proxy requiring HTTP Basic Auth',
                ),
                value: _useBasicAuth,
                onChanged: (value) {
                  setState(() => _useBasicAuth = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_useBasicAuth) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _basicAuthUsernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_useBasicAuth &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Username is required when using basic auth';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _basicAuthPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_useBasicAuth &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Password is required when using basic auth';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_isSaving || _isTesting)
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: (_isSaving || _isTesting) ? null : _testConnection,
          icon: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_find),
          label: const Text('Test'),
        ),
        FilledButton(
          onPressed: (_isSaving || _isTesting) ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.instance != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _SecuritySettingsTab extends StatefulWidget {
  const _SecuritySettingsTab();

  @override
  State<_SecuritySettingsTab> createState() => _SecuritySettingsTabState();
}

class _SecuritySettingsTabState extends State<_SecuritySettingsTab> {
  final BiometricService _biometricService = BiometricService();
  final BackupService _backupService = BackupService();
  bool _isLoading = true;
  bool _deviceSupported = false;
  List<BiometricType> _availableBiometrics = [];
  bool _biometricEnabled = false;
  bool _timeoutEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _exportInstances() async {
    // Show password dialog
    final password = await _showPasswordDialog(
      context: context,
      title: 'Export Instances',
      message: 'Enter a password to encrypt the backup file',
      confirmMode: true,
    );

    if (password == null || password.isEmpty) return;

    try {
      // Show progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Preparing export...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Generate encrypted bytes first
      final encryptedBytes = await _backupService.exportInstances(password);

      // Pick save location with bytes (required for Android/iOS)
      // Keep dialog open until file picker shows to prevent "frozen" appearance
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: 'arr_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: encryptedBytes, // Pass bytes directly for mobile platforms
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (result == null) return;

      // Export complete - bytes already written by saveFile()

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Instances exported successfully'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close encrypting dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${ErrorFormatter.format(e)}')),
        );
      }
    }
  }

  Future<void> _importInstances() async {
    try {
      // Show loading while file picker opens
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening file picker...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File',
      );

      if (mounted) Navigator.pop(context); // Close file picker loading

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;

      // Show password dialog
      if (!mounted) return;
      final password = await _showPasswordDialog(
        context: context,
        title: 'Import Instances',
        message: 'Enter the password used to encrypt this backup',
      );

      if (password == null || password.isEmpty) return;

      // Show progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Validating backup...'),
                  ],
                ),
              ),
            ),
          ),
        );
        // Give dialog time to render before expensive PBKDF2 operation
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Validate first (includes PBKDF2 key derivation - 600k iterations)
      final validation = await _backupService.validateBackup(
        password,
        filePath,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Import'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will import the following:'),
                const SizedBox(height: 12),
                Text('• ${validation['sonarrCount']} Sonarr instance(s)'),
                Text('• ${validation['radarrCount']} Radarr instance(s)'),
                const SizedBox(height: 12),
                Text(
                  'Exported: ${DateTime.parse(validation['exportDate']).toLocal().toString().split('.')[0]}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Existing instances with the same ID will be overwritten.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        // Show import progress
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Importing instances...'),
                  ],
                ),
              ),
            ),
          ),
        );
        // Give dialog time to render before expensive decryption operation
        await Future.delayed(const Duration(milliseconds: 50));

        // Import (includes PBKDF2 key derivation + AES-GCM decryption)
        final counts = await _backupService.importInstances(password, filePath);

        if (mounted) {
          Navigator.pop(context); // Close progress dialog

          // Reload all instances (loads credentials, clears cache, notifies)
          await AppStateManager().reloadInstances();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${counts['sonarr']} Sonarr and ${counts['radarr']} Radarr instances',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${ErrorFormatter.format(e)}')),
        );
      }
    }
  }

  Future<String?> _showPasswordDialog({
    required BuildContext context,
    required String title,
    required String message,
    bool confirmMode = false,
  }) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 12) {
                    return 'Password must be at least 12 characters';
                  }
                  return null;
                },
              ),
              if (confirmMode) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              Text(
                confirmMode
                    ? 'Use a strong password (min 12 characters). You will need it to import this backup.'
                    : 'Enter the password you used when exporting this backup.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBiometricSupport() async {
    setState(() => _isLoading = true);

    try {
      final supported = await _biometricService.isDeviceSupported();
      final biometrics = await _biometricService.getAvailableBiometrics();
      final enabled = await _biometricService.isBiometricEnabled();
      final timeout = await _biometricService.isTimeoutEnabled();

      if (mounted) {
        setState(() {
          _deviceSupported = supported;
          _availableBiometrics = biometrics;
          _biometricEnabled = enabled;
          _timeoutEnabled = timeout;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceSupported = false;
          _isLoading = false;
        });
      }
    }
  }

  String _getBiometricTypeName() {
    if (_availableBiometrics.isEmpty) return 'Biometric';

    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Enabling - authenticate first to verify it works
      try {
        final authenticated = await _biometricService.authenticate(
          reason: 'Enable biometric authentication',
          biometricOnly: false,
        );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Authentication cancelled')),
            );
          }
          return;
        }

        await _biometricService.setBiometricEnabled(true);
        setState(() => _biometricEnabled = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_getBiometricTypeName()} authentication enabled',
              ),
            ),
          );
        }
      } on PlatformException catch (e) {
        if (mounted) {
          String message = 'Authentication failed';

          // Provide more specific error messages
          if (e.code == 'NotAvailable') {
            message =
                'Biometric authentication is not available on this device';
          } else if (e.code == 'NotEnrolled') {
            message =
                'No biometrics enrolled. Please set up fingerprint or face recognition in device settings';
          } else if (e.code == 'LockedOut') {
            message =
                'Too many attempts. Biometric authentication is temporarily locked';
          } else if (e.code == 'PermanentlyLockedOut') {
            message =
                'Biometric authentication permanently locked. Use device credentials to unlock';
          } else if (e.message != null) {
            message = 'Authentication error: ${e.message}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
        return;
      }
    } else {
      // Disabling - require authentication first
      try {
        final authenticated = await _biometricService
            .authenticateForSensitiveOperation(
              operation: 'disable biometric authentication',
            );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required to disable'),
              ),
            );
          }
          return;
        }

        await _biometricService.setBiometricEnabled(false);
        setState(() => _biometricEnabled = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication disabled')),
          );
        }
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message ?? e.code}')),
          );
        }
        return;
      }
    }
  }

  Future<void> _toggleTimeout(bool value) async {
    await _biometricService.setTimeoutEnabled(value);
    setState(() => _timeoutEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_deviceSupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fingerprint_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Biometric Authentication Not Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your device does not support biometric authentication or no biometrics are enrolled.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Biometric Authentication',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Protect your app with ${_getBiometricTypeName()}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Enable ${_getBiometricTypeName()}'),
                  subtitle: const Text('Require authentication to unlock app'),
                  value: _biometricEnabled,
                  onChanged: _toggleBiometric,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_biometricEnabled) ...[
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Require After Background'),
                    subtitle: const Text(
                      'Re-authenticate when returning from background (5 min timeout)',
                    ),
                    value: _timeoutEnabled,
                    onChanged: _toggleTimeout,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.backup,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup & Restore',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Export and import instance configurations',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportInstances,
                        icon: const Icon(Icons.upload),
                        label: const Text('Export'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _importInstances,
                        icon: const Icon(Icons.download),
                        label: const Text('Import'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Password-protected encrypted backup of all your instances',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Security Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.check_circle_outline,
                  'Credentials are stored in secure platform storage',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.check_circle_outline,
                  'Biometric authentication adds an extra layer of security',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.check_circle_outline,
                  'Authentication required for sensitive operations',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
