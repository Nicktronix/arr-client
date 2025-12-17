import 'package:flutter/material.dart';
import '../services/radarr_service.dart';
import '../services/app_state_manager.dart';
import '../config/app_config.dart';
import 'release_search_screen.dart';
import '../utils/error_formatter.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final String movieTitle;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final RadarrService _radarr = RadarrService();
  Map<String, dynamic>? _movie;
  bool _isLoading = true;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeRadarrInstanceId;
    _loadMovieDetails();
    AppStateManager().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    // If instance changed, show warning and return to previous screen
    if (mounted && AppConfig.activeRadarrInstanceId != _instanceIdOnLoad) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instance changed - returning to list'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadMovieDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final movie = await _radarr.getMovieById(widget.movieId);
      setState(() {
        _movie = movie;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorFormatter.format(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMovie() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search for Movie'),
        content: Text(
          'This will search all indexers for "${widget.movieTitle}".\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _radarr.searchMovieCommand(widget.movieId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movie search started'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start search: ${ErrorFormatter.format(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openInteractiveSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReleaseSearchScreen(
          movieId: widget.movieId,
          movieTitle: widget.movieTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading movie details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadMovieDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_movie == null) {
      return const Center(child: Text('No data'));
    }

    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildOverview(),
              _buildFileInfo(),
              _buildActions(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    // Get banner/fanart image
    final List<dynamic>? images = _movie!['images'];
    String? fanartUrl;
    if (images != null) {
      for (var image in images) {
        if (image['coverType'] == 'fanart') {
          fanartUrl = image['remoteUrl'];
          break;
        }
      }
    }

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _searchMovie,
          tooltip: 'Search for movie',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.movieTitle,
          style: const TextStyle(
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 8.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        background: fanartUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    fanartUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(color: Theme.of(context).colorScheme.primaryContainer),
      ),
    );
  }

  Widget _buildHeader() {
    final String title = _movie!['title'] ?? 'Unknown';
    final int year = _movie!['year'] ?? 0;
    final String status = _movie!['status'] ?? 'unknown';
    final bool monitored = _movie!['monitored'] ?? false;
    final int runtime = _movie!['runtime'] ?? 0;
    final List<String> genres =
        (_movie!['genres'] as List?)?.cast<String>() ?? [];
    final double rating = (_movie!['ratings']?['tmdb']?['value'] ?? 0.0)
        .toDouble();
    final bool hasFile = _movie!['hasFile'] ?? false;

    // Get poster
    final List<dynamic>? images = _movie!['images'];
    String? posterUrl;
    if (images != null) {
      for (var image in images) {
        if (image['coverType'] == 'poster') {
          posterUrl = image['remoteUrl'];
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: posterUrl != null
                ? Image.network(
                    posterUrl,
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.movie, size: 60),
                      );
                    },
                  )
                : Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(Icons.movie, size: 60),
                  ),
          ),
          const SizedBox(width: 16),
          // Info
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
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rating > 0) ...[
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (year > 0)
                  Text(
                    year.toString(),
                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatStatus(status),
                  style: TextStyle(
                    fontSize: 14,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (runtime > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$runtime min',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      monitored ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                      color: monitored ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      monitored ? 'Monitored' : 'Not Monitored',
                      style: TextStyle(
                        fontSize: 14,
                        color: monitored ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (hasFile) ...[
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Downloaded',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ],
                ),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: genres.take(3).map((genre) {
                      return Chip(
                        label: Text(
                          genre,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                _buildTagsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    final List<int> tagIds = (_movie!['tags'] as List?)?.cast<int>() ?? [];

    return Row(
      children: [
        Icon(Icons.label, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        if (tagIds.isEmpty)
          Text(
            'No tags',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          )
        else
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _radarr.getTags(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    '${tagIds.length} tag${tagIds.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  );
                }

                final allTags = snapshot.data!;
                final movieTags = allTags
                    .where((t) => tagIds.contains(t['id']))
                    .toList();

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: movieTags.map((tag) {
                    return Chip(
                      label: Text(
                        tag['label'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: _showEditMovieDialog,
          tooltip: 'Edit movie',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildOverview() {
    final String? overview = _movie!['overview'];
    if (overview == null || overview.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            overview,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    final bool hasFile = _movie!['hasFile'] ?? false;
    if (!hasFile) return const SizedBox.shrink();

    final movieFile = _movie!['movieFile'];
    if (movieFile == null) return const SizedBox.shrink();

    final String quality =
        movieFile['quality']?['quality']?['name'] ?? 'Unknown';
    final int size = movieFile['size'] ?? 0;
    final String sizeStr = _formatBytes(size);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'File Info',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.high_quality, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Quality: $quality',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.storage, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Size: $sizeStr',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openInteractiveSearch,
              icon: const Icon(Icons.person),
              label: const Text('Interactive Search'),
            ),
          ),
        ],
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'released':
        return Colors.green;
      case 'incinemas':
        return Colors.blue;
      case 'announced':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _showEditMovieDialog() async {
    // Load quality profiles, root folders, and tags
    List<dynamic>? qualityProfiles;
    List<dynamic>? rootFolders;
    List<dynamic>? allTags;

    try {
      final results = await Future.wait([
        _radarr.getQualityProfiles(),
        _radarr.getRootFolders(),
        _radarr.getTags(),
      ]);
      qualityProfiles = results[0];
      rootFolders = results[1];
      allTags = results[2];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading settings: ${ErrorFormatter.format(e)}',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Current movie values
    bool monitored = _movie!['monitored'] ?? true;
    int qualityProfileId = _movie!['qualityProfileId'];
    String minimumAvailability = _movie!['minimumAvailability'] ?? 'released';
    String path = _movie!['path'];
    final selectedTags = List<int>.from(_movie!['tags'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Movie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: monitored,
                  onChanged: (value) {
                    setDialogState(() => monitored = value ?? true);
                  },
                  title: const Text('Monitored'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quality Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: qualityProfileId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: qualityProfiles!.map((profile) {
                    return DropdownMenuItem<int>(
                      value: profile['id'],
                      child: Text(profile['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => qualityProfileId = value!);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Minimum Availability',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: minimumAvailability,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'announced',
                      child: Text('Announced'),
                    ),
                    DropdownMenuItem(
                      value: 'inCinemas',
                      child: Text('In Cinemas'),
                    ),
                    DropdownMenuItem(
                      value: 'released',
                      child: Text('Released'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => minimumAvailability = value!);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Root Folder',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: () {
                    // Find which root folder the current path is under
                    for (var folder in rootFolders!) {
                      final rootPath = folder['path'] as String;
                      if (path.startsWith(rootPath)) {
                        return rootPath;
                      }
                    }
                    // If no match, return first root folder
                    return rootFolders.first['path'] as String;
                  }(),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: rootFolders!.map((folder) {
                    final folderPath = folder['path'] as String;
                    return DropdownMenuItem<String>(
                      value: folderPath,
                      child: Text(
                        folderPath,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (newRootFolder) {
                    if (newRootFolder != null) {
                      // Update path to use new root folder
                      final movieTitle = _movie!['title'];
                      final year = _movie!['year'];
                      setDialogState(
                        () => path = '$newRootFolder/$movieTitle ($year)',
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (allTags!.isNotEmpty) ...[
                  const Text(
                    'Tags',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag['id']);
                      return FilterChip(
                        label: Text(tag['label']),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedTags.add(tag['id']);
                            } else {
                              selectedTags.remove(tag['id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
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
                Navigator.pop(context);
                _updateMovie(
                  monitored: monitored,
                  qualityProfileId: qualityProfileId,
                  minimumAvailability: minimumAvailability,
                  path: path,
                  tags: selectedTags,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMovie({
    required bool monitored,
    required int qualityProfileId,
    required String minimumAvailability,
    required String path,
    required List<int> tags,
  }) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Updating movie...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      // Update all fields on the movie object
      final updatedMovie = Map<String, dynamic>.from(_movie!);
      updatedMovie['monitored'] = monitored;
      updatedMovie['qualityProfileId'] = qualityProfileId;
      updatedMovie['minimumAvailability'] = minimumAvailability;
      updatedMovie['path'] = path;
      updatedMovie['tags'] = tags;

      await _radarr.updateMovie(updatedMovie);

      // Reload movie details
      await _loadMovieDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movie updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating movie: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
