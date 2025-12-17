import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../utils/cached_data_loader.dart';
import '../utils/error_formatter.dart';
import 'series_detail_screen.dart';

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen>
    with CachedDataLoader {
  final SonarrService _sonarr = SonarrService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _series = [];
  bool _isSearching = false;
  String _searchQuery = '';
  String _sortBy = 'title_asc'; // title_asc, title_desc, added, year
  bool _showMissingOnly = false;

  @override
  String get cacheKey => 'series_list';

  @override
  bool get isSonarrScreen => true;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onInstanceChanged);
    loadData();
  }

  @override
  void dispose() {
    appState.removeListener(_onInstanceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onInstanceChanged() {
    if (mounted) {
      setState(() {
        // Rebuild to update title with new instance name
      });
      loadData(forceRefresh: true);
    }
  }

  @override
  Future<dynamic> fetchData() async {
    try {
      return await _sonarr.getSeries();
    } catch (e) {
      throw ErrorFormatter.format(e);
    }
  }

  @override
  void onDataLoaded(dynamic data) {
    if (mounted) {
      setState(() {
        _series = data as List<dynamic>;
        _applySorting();
      });
    }
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'title_desc':
        _series.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleB.compareTo(titleA);
        });
        break;
      case 'added':
        _series.sort((a, b) {
          final dateA = DateTime.tryParse(a['added'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['added'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA); // Newest first
        });
        break;
      case 'year':
        _series.sort((a, b) {
          final yearA = a['year'] ?? 0;
          final yearB = b['year'] ?? 0;
          return yearB.compareTo(yearA); // Newest first
        });
        break;
      case 'title_asc':
      default:
        _series.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
    }
  }

  List<dynamic> get _filteredSeries {
    var filtered = _series;

    // Apply missing files filter
    if (_showMissingOnly) {
      filtered = filtered.where((series) {
        final stats = series['statistics'];
        if (stats == null) return false;
        final episodeFileCount = stats['episodeFileCount'] ?? 0;
        final episodeCount = stats['episodeCount'] ?? 0;
        return episodeFileCount < episodeCount; // Has missing episodes
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((series) {
        final title = (series['title'] ?? '').toLowerCase();
        final network = (series['network'] ?? '').toLowerCase();
        final year = series['year']?.toString() ?? '';

        return title.contains(query) ||
            network.contains(query) ||
            year.contains(query);
      }).toList();
    }

    return filtered;
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _showInstancePicker() {
    // Use fast metadata-only method - no secure storage access
    final instancesMetadata = appState.getSonarrInstancesMetadata();
    final currentInstanceId = appState.getActiveSonarrId();

    if (instancesMetadata.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Sonarr instances configured')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Switch Sonarr Instance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: currentInstanceId,
              onChanged: (value) async {
                if (value != null && value != currentInstanceId) {
                  Navigator.pop(context);
                  // Show loading immediately for instant feedback
                  setLoadingState();
                  // Switch instance (clears cache and notifies listeners)
                  await appState.switchSonarrInstance(value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: instancesMetadata
                    .map(
                      (instance) => RadioListTile<String>(
                        title: Text(instance['name'] as String),
                        subtitle: Text(instance['baseUrl'] as String),
                        value: instance['id'] as String,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort & Filter',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort By',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              RadioGroup<String>(
                groupValue: _sortBy,
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => _sortBy = value);
                    setState(() {
                      _sortBy = value;
                      _applySorting();
                    });
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: const Text('Title (A-Z)'),
                      value: 'title_asc',
                    ),
                    RadioListTile<String>(
                      title: const Text('Title (Z-A)'),
                      value: 'title_desc',
                    ),
                    RadioListTile<String>(
                      title: const Text('Recently Added'),
                      value: 'added',
                    ),
                    RadioListTile<String>(
                      title: const Text('Year'),
                      value: 'year',
                    ),
                  ],
                ),
              ),
              const Divider(),
              const Text(
                'Filter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SwitchListTile(
                title: const Text('Show Missing Episodes Only'),
                value: _showMissingOnly,
                onChanged: (value) {
                  setModalState(() => _showMissingOnly = value);
                  setState(() => _showMissingOnly = value);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String get _titleText {
    final instanceName = appState.getActiveSonarrName();
    if (instanceName == null) return 'TV Series';
    return 'TV Series - $instanceName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search series...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _onSearchChanged,
              )
            : GestureDetector(
                onTap: _showInstancePicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(_titleText, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Close search' : 'Search',
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterOptions,
              tooltip: 'Sort & Filter',
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => loadData(forceRefresh: true),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: buildBody(
        buildContent: () => _buildSeriesList(),
        isEmpty: _series.isEmpty,
        emptyStateWidget: buildEmptyState(
          icon: Icons.tv_off,
          title: 'No series found',
          message: 'Add some series in Sonarr to see them here',
        ),
      ),
    );
  }

  Widget _buildSeriesList() {
    final displaySeries = _filteredSeries;

    if (displaySeries.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No series match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => loadData(forceRefresh: true),
      child: ListView.builder(
        itemCount: displaySeries.length,
        itemBuilder: (context, index) {
          final series = displaySeries[index];
          return _buildSeriesCard(series);
        },
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> series) {
    final String title = series['title'] ?? 'Unknown Title';
    final int year = series['year'] ?? 0;
    final String status = series['status'] ?? 'unknown';
    final int seasonCount = (series['seasons'] as List?)?.length ?? 0;
    final String network = series['network'] ?? 'Unknown Network';
    final bool monitored = series['monitored'] ?? false;
    final String? overview = series['overview'];

    // Get poster image if available
    final List<dynamic>? images = series['images'];
    String? posterUrl;
    if (images != null) {
      for (var image in images) {
        if (image['coverType'] == 'poster') {
          posterUrl = image['remoteUrl'];
          break;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreen(
                seriesId: series['id'],
                seriesTitle: title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: posterUrl != null
                    ? Image.network(
                        posterUrl,
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        cacheWidth: 160, // Cache at 2x for sharp display
                        cacheHeight: 240,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.tv, size: 40),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey[300],
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.tv, size: 40),
                      ),
              ),
              const SizedBox(width: 12),
              // Series Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          monitored ? Icons.visibility : Icons.visibility_off,
                          color: monitored ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$year • $network',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$seasonCount ${seasonCount == 1 ? 'season' : 'seasons'} • ${_formatStatus(status)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (overview != null && overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'continuing':
        return 'Continuing';
      case 'ended':
        return 'Ended';
      default:
        return status.substring(0, 1).toUpperCase() +
            status.substring(1).toLowerCase();
    }
  }
}
