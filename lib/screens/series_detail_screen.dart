import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/app_state_manager.dart';
import '../config/app_config.dart';
import 'season_detail_screen.dart';
import '../utils/error_formatter.dart';

class SeriesDetailScreen extends StatefulWidget {
  final int seriesId;
  final String seriesTitle;

  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.seriesTitle,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final SonarrService _sonarr = SonarrService();
  Map<String, dynamic>? _series;
  bool _isLoading = true;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeSonarrInstanceId;
    _loadSeriesDetails();
    AppStateManager().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    // If instance changed, show warning and return to previous screen
    if (mounted && AppConfig.activeSonarrInstanceId != _instanceIdOnLoad) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instance changed - returning to list'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadSeriesDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final series = await _sonarr.getSeriesById(widget.seriesId);
      setState(() {
        _series = series;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorFormatter.format(e);
        _isLoading = false;
      });
    }
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
                'Error loading series details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadSeriesDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_series == null) {
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
              _buildSeasons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    // Get banner/fanart image
    final List<dynamic>? images = _series!['images'];
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
          onPressed: _searchMonitoredEpisodes,
          tooltip: 'Search monitored episodes',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.seriesTitle,
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
    final String title = _series!['title'] ?? 'Unknown';
    final int year = _series!['year'] ?? 0;
    final String status = _series!['status'] ?? 'unknown';
    final String network = _series!['network'] ?? 'Unknown';
    final bool monitored = _series!['monitored'] ?? false;
    final int runtime = _series!['runtime'] ?? 0;
    final List<String> genres =
        (_series!['genres'] as List?)?.cast<String>() ?? [];
    final double rating = (_series!['ratings']?['value'] ?? 0.0).toDouble();

    // Get poster
    final List<dynamic>? images = _series!['images'];
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
                        child: const Icon(Icons.tv, size: 60),
                      );
                    },
                  )
                : Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(Icons.tv, size: 60),
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
                Text(
                  '$year • $network',
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
                    '$runtime min/episode',
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
                        color: monitored ? Colors.green : Colors.grey[600],
                      ),
                    ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildOverview() {
    final String? overview = _series!['overview'];

    if (overview == null || overview.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasons() {
    final List<dynamic>? seasons = _series!['seasons'];

    if (seasons == null || seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out specials and sort by season number
    final regularSeasons = seasons.where((s) => s['seasonNumber'] != 0).toList()
      ..sort(
        (a, b) =>
            (a['seasonNumber'] as int).compareTo(b['seasonNumber'] as int),
      );

    if (regularSeasons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seasons',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...regularSeasons.map((season) => _buildSeasonItem(season)),
        ],
      ),
    );
  }

  Widget _buildSeasonItem(Map<String, dynamic> season) {
    final int seasonNumber = season['seasonNumber'] ?? 0;
    final bool monitored = season['monitored'] ?? false;
    final Map<String, dynamic>? statistics = season['statistics'];

    int totalEpisodes = 0;
    int episodeFileCount = 0;

    if (statistics != null) {
      totalEpisodes = statistics['totalEpisodeCount'] ?? 0;
      episodeFileCount = statistics['episodeFileCount'] ?? 0;
    }

    final double progress = totalEpisodes > 0
        ? episodeFileCount / totalEpisodes
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: totalEpisodes > 0
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeasonDetailScreen(
                      seriesId: _series!['id'],
                      seasonNumber: seasonNumber,
                      seriesTitle: _series!['title'] ?? 'Unknown',
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Season $seasonNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    monitored ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: monitored ? Colors.green : Colors.grey,
                  ),
                  if (totalEpisodes > 0) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$episodeFileCount of $totalEpisodes episodes',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    final List<int> tagIds = (_series!['tags'] as List?)?.cast<int>() ?? [];

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
              future: _sonarr.getTags(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    '${tagIds.length} tag${tagIds.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  );
                }

                final allTags = snapshot.data!;
                final seriesTags = allTags
                    .where((t) => tagIds.contains(t['id']))
                    .toList();

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: seriesTags.map((tag) {
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
          onPressed: _showEditSeriesDialog,
          tooltip: 'Edit series',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Future<void> _showEditSeriesDialog() async {
    // Load quality profiles, root folders, and tags
    List<dynamic>? qualityProfiles;
    List<dynamic>? rootFolders;
    List<dynamic>? allTags;

    try {
      final results = await Future.wait([
        _sonarr.getQualityProfiles(),
        _sonarr.getRootFolders(),
        _sonarr.getTags(),
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

    // Current series values
    bool monitored = _series!['monitored'] ?? true;
    bool useSeasonFolder = _series!['seasonFolder'] ?? true;
    int qualityProfileId = _series!['qualityProfileId'];
    String seriesType = _series!['seriesType'] ?? 'standard';
    String path = _series!['path'];
    final selectedTags = List<int>.from(_series!['tags'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Series'),
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
                CheckboxListTile(
                  value: useSeasonFolder,
                  onChanged: (value) {
                    setDialogState(() => useSeasonFolder = value ?? true);
                  },
                  title: const Text('Use Season Folders'),
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
                  'Series Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: seriesType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'standard',
                      child: Text('Standard'),
                    ),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'anime', child: Text('Anime')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => seriesType = value!);
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
                      final seriesTitle = _series!['title'];
                      setDialogState(
                        () => path = '$newRootFolder/$seriesTitle',
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
                _updateSeries(
                  monitored: monitored,
                  useSeasonFolder: useSeasonFolder,
                  qualityProfileId: qualityProfileId,
                  seriesType: seriesType,
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

  Future<void> _updateSeries({
    required bool monitored,
    required bool useSeasonFolder,
    required int qualityProfileId,
    required String seriesType,
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
              Text('Updating series...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      // Update all fields on the series object
      final updatedSeries = Map<String, dynamic>.from(_series!);
      updatedSeries['monitored'] = monitored;
      updatedSeries['seasonFolder'] = useSeasonFolder;
      updatedSeries['qualityProfileId'] = qualityProfileId;
      updatedSeries['seriesType'] = seriesType;
      updatedSeries['path'] = path;
      updatedSeries['tags'] = tags;

      await _sonarr.updateSeries(updatedSeries);

      // Reload series details
      await _loadSeriesDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Series updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating series: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchMonitoredEpisodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Monitored Episodes'),
        content: Text(
          'This will search for all monitored episodes in "${widget.seriesTitle}".\n\n'
          'Sonarr will search all configured indexers for missing episodes that are set to be monitored.',
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

    if (confirmed != true) return;

    try {
      if (!mounted) return;
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
              Text('Searching for monitored episodes...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      await _sonarr.searchSeriesCommand(widget.seriesId);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search command sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'continuing':
        return Colors.green;
      case 'ended':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
