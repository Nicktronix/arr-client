import 'package:flutter/material.dart';
import 'series_list_screen.dart';
import 'series_search_screen.dart';
import 'movie_list_screen.dart';
import 'movie_search_screen.dart';
import 'queue_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'system_status_screen.dart';
import '../services/app_state_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AppStateManager _appState = AppStateManager();

  // Cache screen widgets to preserve state between tab switches
  late List<Widget> _cachedScreens;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onInstanceChanged);
    _initializeScreens();
  }

  @override
  void dispose() {
    _appState.removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    // Rebuild screens when instances change
    if (mounted) {
      setState(() {
        _initializeScreens();
      });
    }
  }

  void _initializeScreens() {
    _cachedScreens = [
      SonarrTab(
        key: ValueKey('sonarr_tab_${_appState.getActiveSonarrId()}'),
        hasInstance: _appState.getActiveSonarrId() != null,
        onSettingsPressed: _openSettings,
      ),
      RadarrTab(
        key: ValueKey('radarr_tab_${_appState.getActiveRadarrId()}'),
        hasInstance: _appState.getActiveRadarrId() != null,
        onSettingsPressed: _openSettings,
      ),
      QueueScreen(
        key: ValueKey(
          'queue_${_appState.getActiveSonarrId()}_${_appState.getActiveRadarrId()}',
        ),
        onSettingsPressed: _openSettings,
      ),
      HistoryScreen(
        key: ValueKey(
          'history_${_appState.getActiveSonarrId()}_${_appState.getActiveRadarrId()}',
        ),
        onSettingsPressed: _openSettings,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    // Instance changes are handled by listener
  }

  String _getAppBarTitle() {
    if (_selectedIndex == 0) {
      final name = _appState.getActiveSonarrName();
      return name != null ? 'Sonarr: $name' : 'Sonarr';
    } else if (_selectedIndex == 1) {
      final name = _appState.getActiveRadarrName();
      return name != null ? 'Radarr: $name' : 'Radarr';
    } else if (_selectedIndex == 2) {
      return 'Queue';
    }
    return 'History';
  }

  @override
  Widget build(BuildContext context) {
    if (!_appState.isInitialized) {
      return Scaffold(
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.apps,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Arr Client',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalendarScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('System Status'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SystemStatusScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _openSettings();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _cachedScreens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tv), label: 'Sonarr'),
          NavigationDestination(icon: Icon(Icons.movie), label: 'Radarr'),
          NavigationDestination(icon: Icon(Icons.download), label: 'Queue'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

// Sonarr Tab - TV Shows
class SonarrTab extends StatelessWidget {
  final bool hasInstance;
  final VoidCallback onSettingsPressed;

  const SonarrTab({
    super.key,
    required this.hasInstance,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasInstance) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tv_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Sonarr Instance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a Sonarr instance in Settings to manage your TV series',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onSettingsPressed,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tv, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Sonarr - TV Shows',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Manage your TV series here'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SeriesListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.list),
            label: const Text('View Series'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SeriesSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search),
            label: const Text('Search Series'),
          ),
        ],
      ),
    );
  }
}

// Radarr Tab - Movies
class RadarrTab extends StatelessWidget {
  final bool hasInstance;
  final VoidCallback onSettingsPressed;

  const RadarrTab({
    super.key,
    required this.hasInstance,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasInstance) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.movie_creation_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Radarr Instance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a Radarr instance in Settings to manage your movies',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onSettingsPressed,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Radarr - Movies',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Manage your movies here'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MovieListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.list),
            label: const Text('View Movies'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MovieSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search),
            label: const Text('Search Movies'),
          ),
        ],
      ),
    );
  }
}
