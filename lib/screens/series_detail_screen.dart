import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arr_client/models/sonarr/series.dart';
import 'package:arr_client/models/shared/media_cover.dart';
import 'package:arr_client/models/shared/quality_profile.dart';
import 'package:arr_client/models/shared/root_folder.dart';
import 'package:arr_client/models/shared/tag.dart';
import 'package:arr_client/services/sonarr_service.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/config/app_config.dart';
import 'package:arr_client/di/injection.dart';
import 'package:arr_client/screens/season_detail_screen.dart';
import 'package:arr_client/utils/error_formatter.dart';

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
  final SonarrService _sonarr = getIt<SonarrService>();
  SeriesResource? _series;
  bool _isLoading = true;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeSonarrInstanceId;
    unawaited(_loadSeriesDetails());
    getIt<AppStateManager>().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    getIt<AppStateManager>().removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
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
    String? fanartUrl;
    for (final image in _series!.images ?? <MediaCover>[]) {
      if (image.coverType == 'fanart') {
        fanartUrl = image.remoteUrl;
        break;
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
    final title = _series!.title ?? 'Unknown';
    final year = _series!.year ?? 0;
    final status = _series!.status ?? 'unknown';
    final network = _series!.network ?? 'Unknown';
    final monitored = _series!.monitored ?? false;
    final runtime = _series!.runtime ?? 0;
    final genres = _series!.genres ?? [];
    final rating = _series!.ratings?.value ?? 0.0;

    String? posterUrl;
    for (final image in _series!.images ?? <MediaCover>[]) {
      if (image.coverType == 'poster') {
        posterUrl = image.remoteUrl;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    final overview = _series!.overview;

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
    final seasons = _series!.seasons;

    if (seasons == null || seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    final regularSeasons = seasons.where((s) => s.seasonNumber != 0).toList()
      ..sort((a, b) => (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0));

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
          ...regularSeasons.map(_buildSeasonItem),
        ],
      ),
    );
  }

  Widget _buildSeasonItem(SeasonResource season) {
    final seasonNumber = season.seasonNumber ?? 0;
    final monitored = season.monitored ?? false;
    final totalEpisodes = season.statistics?.totalEpisodeCount ?? 0;
    final episodeFileCount = season.statistics?.episodeFileCount ?? 0;

    final progress = totalEpisodes > 0 ? episodeFileCount / totalEpisodes : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: totalEpisodes > 0
            ? () {
                unawaited(
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeasonDetailScreen(
                        seriesId: _series!.id!,
                        seasonNumber: seasonNumber,
                        seriesTitle: _series!.title ?? 'Unknown',
                      ),
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
    final tagIds = _series!.tags ?? [];

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
            child: FutureBuilder<List<TagResource>>(
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
                    .where((t) => t.id != null && tagIds.contains(t.id))
                    .toList();

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: seriesTags.map((tag) {
                    return Chip(
                      label: Text(
                        tag.label ?? '',
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
    List<QualityProfileResource>? qualityProfiles;
    List<RootFolderResource>? rootFolders;
    List<TagResource>? allTags;

    try {
      final futureProfiles = _sonarr.getQualityProfiles();
      final futureFolders = _sonarr.getRootFolders();
      final futureTags = _sonarr.getTags();
      qualityProfiles = await futureProfiles;
      rootFolders = await futureFolders;
      allTags = await futureTags;
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

    var monitored = _series!.monitored ?? true;
    var useSeasonFolder = _series!.seasonFolder ?? true;
    var qualityProfileId = _series!.qualityProfileId ?? 0;
    var seriesType = _series!.seriesType ?? 'standard';
    var path = _series!.path ?? '';
    final selectedTags = List<int>.from(_series!.tags ?? []);

    await showDialog<void>(
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
                      value: profile.id,
                      child: Text(profile.name ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => qualityProfileId = value);
                    }
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
                    if (value != null) {
                      setDialogState(() => seriesType = value);
                    }
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
                    for (final folder in rootFolders!) {
                      final rootPath = folder.path ?? '';
                      if (path.startsWith(rootPath)) return rootPath;
                    }
                    return rootFolders.first.path ?? '';
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
                    final folderPath = folder.path ?? '';
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
                      setDialogState(
                        () => path = '$newRootFolder/${_series!.title ?? ''}',
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
                      final isSelected =
                          tag.id != null && selectedTags.contains(tag.id);
                      return FilterChip(
                        label: Text(tag.label ?? ''),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (tag.id == null) return;
                          setDialogState(() {
                            if (selected) {
                              selectedTags.add(tag.id!);
                            } else {
                              selectedTags.remove(tag.id);
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
                unawaited(
                  _updateSeries(
                    monitored: monitored,
                    useSeasonFolder: useSeasonFolder,
                    qualityProfileId: qualityProfileId,
                    seriesType: seriesType,
                    path: path,
                    tags: selectedTags,
                  ),
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

      final updated = _series!.copyWith(
        monitored: monitored,
        seasonFolder: useSeasonFolder,
        qualityProfileId: qualityProfileId,
        seriesType: seriesType,
        path: path,
        tags: tags,
      );
      await _sonarr.updateSeries(updated);

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
            content: Text(
              'Error updating series: ${ErrorFormatter.format(e)}',
            ),
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
