import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sonarr_service.dart';
import '../services/radarr_service.dart';
import '../services/app_state_manager.dart';
import '../utils/error_formatter.dart';
import '../config/app_config.dart';
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final SonarrService _sonarr = SonarrService();
  final RadarrService _radarr = RadarrService();
  final AppStateManager _appState = AppStateManager();

  late TabController _tabController;
  List<dynamic> _sonarrCalendar = [];
  List<dynamic> _radarrCalendar = [];
  Map<int, String> _seriesTitles = {}; // seriesId -> title
  Map<int, String> _movieTitles = {}; // movieId -> title
  int _selectedDays = 7;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _appState.addListener(_onInstanceChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _appState.removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _onInstanceChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final end = now.add(Duration(days: _selectedDays));

      if (_tabController.index == 0) {
        if (AppConfig.activeSonarrInstanceId == null) {
          if (mounted) {
            setState(() {
              _sonarrCalendar = [];
              _seriesTitles = {};
              _isLoading = false;
            });
          }
          return;
        }

        // Fetch series list first to get titles
        final seriesList = await _sonarr.getSeries();
        final titlesMap = <int, String>{};
        for (var series in seriesList) {
          if (series['id'] != null && series['title'] != null) {
            titlesMap[series['id'] as int] = series['title'] as String;
          }
        }

        final data = await _sonarr.getCalendar(start: start, end: end);
        if (mounted) {
          setState(() {
            _sonarrCalendar = data;
            _seriesTitles = titlesMap;
            _isLoading = false;
          });
        }
      } else {
        if (AppConfig.activeRadarrInstanceId == null) {
          if (mounted) {
            setState(() {
              _radarrCalendar = [];
              _movieTitles = {};
              _isLoading = false;
            });
          }
          return;
        }

        // Fetch movies list first to get titles
        final moviesList = await _radarr.getMovies();
        final titlesMap = <int, String>{};
        for (var movie in moviesList) {
          if (movie['id'] != null && movie['title'] != null) {
            titlesMap[movie['id'] as int] = movie['title'] as String;
          }
        }

        final data = await _radarr.getCalendar(start: start, end: end);
        if (mounted) {
          setState(() {
            _radarrCalendar = data;
            _movieTitles = titlesMap;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorFormatter.format(e);
          _isLoading = false;
        });
      }
    }
  }

  void _changeDaysFilter(int days) {
    setState(() {
      _selectedDays = days;
    });
    _loadData();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading calendar...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error loading calendar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildSuccessBody();
  }

  Widget _buildSuccessBody() {
    final calendar = _tabController.index == 0
        ? _sonarrCalendar
        : _radarrCalendar;

    if (calendar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _tabController.index == 0
                  ? Icons.tv_off
                  : Icons.movie_creation_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No upcoming ${_tabController.index == 0 ? 'episodes' : 'movies'}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing scheduled for the next $_selectedDays days',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<dynamic>>{};
    for (var item in calendar) {
      final dateStr = _tabController.index == 0
          ? item['airDateUtc'] as String?
          : item['physicalRelease'] as String? ??
                item['digitalRelease'] as String? ??
                item['inCinemas'] as String?;

      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);
      final dateKey = DateFormat('yyyy-MM-dd').format(date.toLocal());

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(item);
    }

    final sortedDates = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final items = grouped[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              ...items.map((item) => _buildCalendarItem(item)),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  Widget _buildCalendarItem(dynamic item) {
    return _tabController.index == 0
        ? _buildEpisodeItem(item)
        : _buildMovieItem(item);
  }

  Widget _buildEpisodeItem(Map<String, dynamic> episode) {
    final seriesId = episode['seriesId'] as int?;
    final seriesTitle = seriesId != null
        ? (_seriesTitles[seriesId] ?? 'Series #$seriesId')
        : 'Unknown Series';
    final seasonNum = episode['seasonNumber'] ?? 0;
    final episodeNum = episode['episodeNumber'] ?? 0;
    final episodeTitle = episode['title'] ?? 'TBA';
    final airDateUtc = episode['airDateUtc'] as String?;
    final hasFile = episode['hasFile'] as bool? ?? false;

    String timeStr = '';
    if (airDateUtc != null) {
      final airDate = DateTime.parse(airDateUtc).toLocal();
      timeStr = DateFormat('h:mm a').format(airDate);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasFile ? Colors.green : Colors.orange,
          child: Icon(
            hasFile ? Icons.check : Icons.download,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(seriesTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'S${seasonNum.toString().padLeft(2, '0')}E${episodeNum.toString().padLeft(2, '0')} - $episodeTitle',
            ),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (seriesId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeriesDetailScreen(
                  seriesId: seriesId,
                  seriesTitle: seriesTitle,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMovieItem(Map<String, dynamic> movie) {
    final movieId = movie['id'] as int?;
    final title = movieId != null
        ? (_movieTitles[movieId] ?? movie['title'] ?? 'Movie #$movieId')
        : (movie['title'] ?? 'Unknown Movie');
    final year = movie['year'] ?? '';
    final hasFile = movie['hasFile'] as bool? ?? false;
    final status = movie['status'] as String? ?? '';

    // Determine release date and type
    String releaseInfo = '';
    String timeStr = '';

    if (movie['physicalRelease'] != null) {
      final date = DateTime.parse(movie['physicalRelease']).toLocal();
      releaseInfo = 'Physical Release';
      timeStr = DateFormat('MMM d, h:mm a').format(date);
    } else if (movie['digitalRelease'] != null) {
      final date = DateTime.parse(movie['digitalRelease']).toLocal();
      releaseInfo = 'Digital Release';
      timeStr = DateFormat('MMM d, h:mm a').format(date);
    } else if (movie['inCinemas'] != null) {
      final date = DateTime.parse(movie['inCinemas']).toLocal();
      releaseInfo = 'In Cinemas';
      timeStr = DateFormat('MMM d, h:mm a').format(date);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasFile ? Colors.green : Colors.orange,
          child: Icon(
            hasFile ? Icons.check : Icons.download,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text('$title${year != '' ? ' ($year)' : ''}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (releaseInfo.isNotEmpty) Text(releaseInfo),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (status.isNotEmpty)
              Text(
                status,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (movieId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailScreen(movieId: movieId, movieTitle: title),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sonarrInstance = _appState.activeSonarrInstance;
    final radarrInstance = _appState.activeRadarrInstance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by days',
            onSelected: _changeDaysFilter,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 7,
                child: Row(
                  children: [
                    if (_selectedDays == 7) const Icon(Icons.check, size: 20),
                    if (_selectedDays != 7) const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Next 7 days'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 14,
                child: Row(
                  children: [
                    if (_selectedDays == 14) const Icon(Icons.check, size: 20),
                    if (_selectedDays != 14) const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Next 14 days'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 30,
                child: Row(
                  children: [
                    if (_selectedDays == 30) const Icon(Icons.check, size: 20),
                    if (_selectedDays != 30) const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    const Text('Next 30 days'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.tv),
              text: sonarrInstance?.name ?? 'Sonarr',
            ),
            Tab(
              icon: const Icon(Icons.movie),
              text: radarrInstance?.name ?? 'Radarr',
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
