import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/radarr_service.dart';
import '../services/app_state_manager.dart';
import '../utils/error_formatter.dart';
import '../config/app_config.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  final SonarrService _sonarr = SonarrService();
  final RadarrService _radarr = RadarrService();
  final AppStateManager _appState = AppStateManager();

  bool _isLoadingSonarr = false;
  bool _isLoadingRadarr = false;
  String? _sonarrError;
  String? _radarrError;

  List<dynamic> _sonarrHealth = [];
  List<dynamic> _radarrHealth = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _appState.addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    _loadSonarrStatus();
    _loadRadarrStatus();
  }

  Future<void> _loadSonarrStatus() async {
    if (AppConfig.activeSonarrInstanceId == null) {
      setState(() {
        _sonarrHealth = [];
        _sonarrError = null;
        _isLoadingSonarr = false;
      });
      return;
    }

    setState(() {
      _isLoadingSonarr = true;
      _sonarrError = null;
    });

    try {
      final health = await _sonarr.getHealth();

      if (mounted) {
        setState(() {
          _sonarrHealth = health;
          _isLoadingSonarr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sonarrError = ErrorFormatter.format(e);
          _isLoadingSonarr = false;
        });
      }
    }
  }

  Future<void> _loadRadarrStatus() async {
    if (AppConfig.activeRadarrInstanceId == null) {
      setState(() {
        _radarrHealth = [];
        _radarrError = null;
        _isLoadingRadarr = false;
      });
      return;
    }

    setState(() {
      _isLoadingRadarr = true;
      _radarrError = null;
    });

    try {
      final health = await _radarr.getHealth();

      if (mounted) {
        setState(() {
          _radarrHealth = health;
          _isLoadingRadarr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _radarrError = ErrorFormatter.format(e);
          _isLoadingRadarr = false;
        });
      }
    }
  }

  Future<void> _testIndexers(String service) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test All Indexers'),
        content: Text(
          'Test all $service indexers? This will verify connectivity and configuration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Test'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Capture context for safe usage
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing indexers...'),
          ],
        ),
      ),
    );

    try {
      if (service == 'Sonarr') {
        await _sonarr.testAllIndexers();
      } else {
        await _radarr.testAllIndexers();
      }

      if (!mounted) return;
      navigator.pop(); // Close loading dialog

      // Refresh health status to show updated results
      if (service == 'Sonarr') {
        await _loadSonarrStatus();
      } else {
        await _loadRadarrStatus();
      }

      // Show success message
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Indexer tests completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // Close loading dialog

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Test Failed'),
            content: Text(ErrorFormatter.format(e)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sonarrInstance = _appState.activeSonarrInstance;
    final radarrInstance = _appState.activeRadarrInstance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sonarr Status Section
            if (sonarrInstance != null) ...[
              _buildSectionHeader(
                context,
                Icons.tv,
                'Sonarr: ${sonarrInstance.name}',
              ),
              const SizedBox(height: 12),
              if (_isLoadingSonarr)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_sonarrError != null)
                _buildErrorCard(_sonarrError!, _loadSonarrStatus)
              else
                _buildHealthCard('Sonarr', _sonarrHealth),
              const SizedBox(height: 24),
            ],

            // Radarr Status Section
            if (radarrInstance != null) ...[
              _buildSectionHeader(
                context,
                Icons.movie,
                'Radarr: ${radarrInstance.name}',
              ),
              const SizedBox(height: 12),
              if (_isLoadingRadarr)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_radarrError != null)
                _buildErrorCard(_radarrError!, _loadRadarrStatus)
              else
                _buildHealthCard('Radarr', _radarrHealth),
            ],

            // No instances configured
            if (sonarrInstance == null && radarrInstance == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Instances Configured',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Sonarr or Radarr instances to view system status',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String error, VoidCallback onRetry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(String service, List<dynamic> healthItems) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Health Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.science, size: 20),
                  tooltip: 'Test All Indexers',
                  onPressed: () => _testIndexers(service),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (healthItems.isEmpty)
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'All systems operational',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              )
            else
              ...healthItems.map((item) {
                final type =
                    (item['type'] as String?)?.toLowerCase() ?? 'unknown';
                final message = item['message'] ?? 'No details';

                Color color;
                IconData icon;

                if (type == 'error') {
                  color = Colors.red;
                  icon = Icons.error;
                } else if (type == 'warning') {
                  color = Colors.orange;
                  icon = Icons.warning;
                } else {
                  color = Colors.blue;
                  icon = Icons.info;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message, style: TextStyle(color: color)),
                            if (item['wikiUrl'] != null)
                              Text(
                                'More info available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
