import 'package:flutter/material.dart';
import '../services/radarr_service.dart';
import '../utils/cached_data_loader.dart';
import '../utils/error_formatter.dart';
import 'movie_detail_screen.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen>
    with CachedDataLoader {
  final RadarrService _radarr = RadarrService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _movies = [];
  bool _isSearching = false;
  String _searchQuery = '';
  String _sortBy = 'title_asc'; // title_asc, title_desc, added, year
  bool _showMissingOnly = false;

  @override
  String get cacheKey => 'movie_list';

  @override
  bool get isSonarrScreen => false;

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
      return await _radarr.getMovies();
    } catch (e) {
      throw ErrorFormatter.format(e);
    }
  }

  @override
  void onDataLoaded(dynamic data) {
    if (mounted) {
      setState(() {
        _movies = data as List<dynamic>;
        _applySorting();
      });
    }
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'title_desc':
        _movies.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleB.compareTo(titleA);
        });
        break;
      case 'added':
        _movies.sort((a, b) {
          final dateA = DateTime.tryParse(a['added'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['added'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA); // Newest first
        });
        break;
      case 'year':
        _movies.sort((a, b) {
          final yearA = a['year'] ?? 0;
          final yearB = b['year'] ?? 0;
          return yearB.compareTo(yearA); // Newest first
        });
        break;
      case 'title_asc':
      default:
        _movies.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
    }
  }

  List<dynamic> get _filteredMovies {
    var filtered = _movies;

    // Apply missing files filter
    if (_showMissingOnly) {
      filtered = filtered.where((movie) {
        final hasFile = movie['hasFile'] ?? false;
        return !hasFile; // Show only movies without files
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((movie) {
        final title = (movie['title'] ?? '').toLowerCase();
        final year = movie['year']?.toString() ?? '';
        final status = (movie['status'] ?? '').toLowerCase();

        return title.contains(query) ||
            year.contains(query) ||
            status.contains(query);
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
    final instancesMetadata = appState.getRadarrInstancesMetadata();
    final currentInstanceId = appState.getActiveRadarrId();

    if (instancesMetadata.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Radarr instances configured')),
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
              'Switch Radarr Instance',
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
                  await appState.switchRadarrInstance(value);
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
                title: const Text('Show Missing Files Only'),
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
    final instanceName = appState.getActiveRadarrName();
    if (instanceName == null) return 'Movies';
    return 'Movies - $instanceName';
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
                  hintText: 'Search movies...',
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
        buildContent: () => _buildMovieList(),
        isEmpty: _movies.isEmpty,
        emptyStateWidget: buildEmptyState(
          icon: Icons.movie_outlined,
          title: 'No movies found',
          message: 'Add some movies in Radarr to see them here',
        ),
      ),
    );
  }

  Widget _buildMovieList() {
    final displayMovies = _filteredMovies;

    if (displayMovies.isEmpty && _searchQuery.isNotEmpty) {
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
              'No movies match "$_searchQuery"',
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
        itemCount: displayMovies.length,
        itemBuilder: (context, index) {
          final movie = displayMovies[index];
          return _buildMovieCard(movie);
        },
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    final String title = movie['title'] ?? 'Unknown Title';
    final int year = movie['year'] ?? 0;
    final String status = movie['status'] ?? 'unknown';
    final bool monitored = movie['monitored'] ?? false;
    final String? overview = movie['overview'];
    final bool hasFile = movie['hasFile'] ?? false;

    // Get poster image if available
    final List<dynamic>? images = movie['images'];
    String? posterUrl;
    if (images != null) {
      for (var image in images) {
        if (image['coverType'] == 'poster') {
          posterUrl = image['remoteUrl'];
          break;
        }
      }
    }

    // Get runtime
    final int runtime = movie['runtime'] ?? 0;
    final String runtimeStr = runtime > 0 ? '${runtime}min' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MovieDetailScreen(movieId: movie['id'], movieTitle: title),
            ),
          ).then((_) => loadData(forceRefresh: true)); // Reload when returning
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
                            child: const Icon(Icons.movie, size: 40),
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
                        child: const Icon(Icons.movie, size: 40),
                      ),
              ),
              const SizedBox(width: 12),
              // Movie Info
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
                      year > 0
                          ? '$year${runtimeStr.isNotEmpty ? ' • $runtimeStr' : ''}'
                          : runtimeStr,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatStatus(status),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (hasFile) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Downloaded',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ],
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
      case 'released':
        return 'Released';
      case 'incinemas':
        return 'In Cinemas';
      case 'announced':
        return 'Announced';
      default:
        return status.substring(0, 1).toUpperCase() +
            status.substring(1).toLowerCase();
    }
  }
}
