import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/app_state_manager.dart';
import '../config/app_config.dart';
import '../utils/error_formatter.dart';
import 'release_search_screen.dart';

class EpisodeDetailScreen extends StatefulWidget {
  final int seriesId;
  final int episodeId;
  final String seriesTitle;
  final int seasonNumber;
  final int episodeNumber;

  const EpisodeDetailScreen({
    super.key,
    required this.seriesId,
    required this.episodeId,
    required this.seriesTitle,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  final SonarrService _sonarr = SonarrService();
  Map<String, dynamic>? _episode;
  Map<String, dynamic>? _episodeFile;
  bool _isLoading = true;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeSonarrInstanceId;
    _loadEpisodeDetails();
    AppStateManager().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onInstanceChanged);
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

  Future<void> _loadEpisodeDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all episodes for the series
      final allEpisodes = await _sonarr.getEpisodesBySeriesId(widget.seriesId);

      // Find this specific episode
      final episode = allEpisodes.firstWhere(
        (ep) => ep['id'] == widget.episodeId,
        orElse: () => throw Exception('Episode not found'),
      );

      Map<String, dynamic>? episodeFile;

      // If episode has a file, fetch file details
      if (episode['hasFile'] == true && episode['episodeFileId'] != null) {
        try {
          final allFiles = await _sonarr.getEpisodeFilesBySeriesId(
            widget.seriesId,
          );
          episodeFile = allFiles.firstWhere(
            (file) => file['id'] == episode['episodeFileId'],
            orElse: () => <String, dynamic>{},
          );
        } catch (e) {
          // File fetch failed, continue without file details
          debugPrint('Failed to fetch episode file: $e');
        }
      }

      if (mounted) {
        setState(() {
          _episode = episode;
          _episodeFile = episodeFile;
          _isLoading = false;
        });
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

  Future<void> _toggleMonitoring() async {
    if (_episode == null) return;

    final currentMonitored = _episode!['monitored'] ?? false;

    try {
      // Optimistically update UI
      setState(() {
        _episode!['monitored'] = !currentMonitored;
      });

      // Update via API (Sonarr v3 requires seriesId to fetch full episode first)
      await _sonarr.updateEpisode(widget.episodeId, {
        'seriesId': widget.seriesId,
        'monitored': !currentMonitored,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentMonitored
                  ? 'Episode monitoring enabled'
                  : 'Episode monitoring disabled',
            ),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _episode!['monitored'] = currentMonitored;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchForEpisode() async {
    try {
      await _sonarr.searchEpisode(widget.episodeId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Episode search started')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile() async {
    if (_episodeFile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Episode File'),
        content: const Text(
          'Are you sure you want to delete this episode file? This cannot be undone.',
        ),
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
      await _sonarr.deleteEpisodeFile(_episodeFile!['id']);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Episode file deleted')));
        // Reload episode details
        _loadEpisodeDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openInteractiveSearch() async {
    // Show loading dialog
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
                Text('Searching for releases...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final releases = await _sonarr.searchEpisodeReleases(widget.episodeId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (releases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No releases found')),
        );
        return;
      }

      // Navigate to release search screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReleaseSearchScreen(
            episodeId: widget.episodeId,
            episodeNumber: widget.episodeNumber,
            episodeTitle:
                'S${widget.seasonNumber}E${widget.episodeNumber} - ${_episode?['title'] ?? 'Unknown'}',
            releases: releases,
          ),
        ),
      );

      // Reload episode details if a download was initiated
      if (result == true && mounted) {
        _loadEpisodeDetails();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: ${ErrorFormatter.format(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.seriesTitle, style: const TextStyle(fontSize: 14)),
            Text(
              'S${widget.seasonNumber}E${widget.episodeNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_episode != null)
            IconButton(
              icon: Icon(
                _episode!['monitored'] == true
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: _toggleMonitoring,
              tooltip: _episode!['monitored'] == true
                  ? 'Disable monitoring'
                  : 'Enable monitoring',
            ),
          if (_episode != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'search':
                    _searchForEpisode();
                    break;
                  case 'interactive_search':
                    _openInteractiveSearch();
                    break;
                  case 'delete':
                    _deleteFile();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (_episode!['hasFile'] != true)
                  const PopupMenuItem(
                    value: 'search',
                    child: Row(
                      children: [
                        Icon(Icons.search),
                        SizedBox(width: 8),
                        Text('Automatic Search'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'interactive_search',
                  child: Row(
                    children: [
                      Icon(Icons.manage_search),
                      SizedBox(width: 8),
                      Text('Interactive Search'),
                    ],
                  ),
                ),
                if (_episode!['hasFile'] == true)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Delete File',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading episode details...'),
          ],
        ),
      );
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
                'Error loading episode',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadEpisodeDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_episode == null) {
      return const Center(child: Text('Episode not found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEpisodeInfo(),
          if (_episodeFile != null) ...[
            const SizedBox(height: 24),
            _buildFileInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildEpisodeInfo() {
    final String title = _episode!['title'] ?? 'TBA';
    final String? overview = _episode!['overview'];
    final String? airDateUtc = _episode!['airDateUtc'];
    final int? runtime = _episode!['runtime'];
    final bool monitored = _episode!['monitored'] ?? false;
    final int? absoluteEpisodeNumber = _episode!['absoluteEpisodeNumber'];
    final bool qualityCutoffNotMet = _episodeFile?['qualityCutoffNotMet'] ?? false;

    DateTime? airDate;
    if (airDateUtc != null) {
      try {
        airDate = DateTime.parse(airDateUtc);
      } catch (e) {
        // Invalid date
      }
    }

    final bool hasAired = airDate != null && airDate.isBefore(DateTime.now());
    final bool hasFile = _episode!['hasFile'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tv, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Episode Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            // Title
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Status badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(
                  hasFile
                      ? 'Downloaded'
                      : hasAired
                      ? 'Missing'
                      : 'Upcoming',
                  hasFile
                      ? Colors.green
                      : hasAired
                      ? Colors.red
                      : Colors.grey,
                ),
                _buildStatusChip(
                  monitored ? 'Monitored' : 'Unmonitored',
                  monitored ? Colors.blue : Colors.grey,
                ),
                if (hasFile && qualityCutoffNotMet)
                  _buildStatusChip(
                    'Quality Cutoff Not Met',
                    Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Air date and runtime
            if (airDate != null) ...[
              _buildInfoRow(
                Icons.calendar_today,
                'Air Date',
                _formatAirDate(airDate),
              ),
              const SizedBox(height: 8),
            ],
            if (runtime != null) ...[
              _buildInfoRow(Icons.access_time, 'Runtime', '$runtime minutes'),
              const SizedBox(height: 8),
            ],
            if (absoluteEpisodeNumber != null) ...[
              _buildInfoRow(
                Icons.numbers,
                'Absolute Number',
                '$absoluteEpisodeNumber',
              ),
              const SizedBox(height: 8),
            ],
            // Overview
            if (overview != null && overview.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Overview',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                overview,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo() {
    final String quality =
        _episodeFile!['quality']?['quality']?['name'] ?? 'Unknown';
    final int size = _episodeFile!['size'] ?? 0;
    final String? dateAdded = _episodeFile!['dateAdded'];
    final String? releaseGroup = _episodeFile!['releaseGroup'];
    final List<dynamic>? languages = _episodeFile!['languages'];
    final List<dynamic>? customFormats = _episodeFile!['customFormats'];
    final int customFormatScore = _episodeFile!['customFormatScore'] ?? 0;
    final Map<String, dynamic>? mediaInfo = _episodeFile!['mediaInfo'];
    final String? relativePath = _episodeFile!['relativePath'];

    DateTime? addedDate;
    if (dateAdded != null) {
      try {
        addedDate = DateTime.parse(dateAdded);
      } catch (e) {
        // Invalid date
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_present, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'File Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            // Quality
            _buildInfoRow(Icons.high_quality, 'Quality', quality),
            const SizedBox(height: 8),
            // Size and Date
            _buildInfoRow(Icons.storage, 'Size', _formatBytes(size)),
            if (addedDate != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.access_time,
                'Added',
                _formatAirDate(addedDate),
              ),
            ],
            // Release Group
            if (releaseGroup != null && releaseGroup.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.group, 'Release Group', releaseGroup),
            ],
            // Languages
            if (languages != null && languages.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.language,
                'Languages',
                languages.map((l) => l['name'] ?? 'Unknown').join(', '),
              ),
            ],
            // Custom Formats
            if (customFormats != null && customFormats.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Custom Formats',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var format in customFormats)
                    Chip(
                      label: Text(
                        format['name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 11),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.star,
                'CF Score',
                '$customFormatScore',
                valueColor: customFormatScore >= 0 ? Colors.green : Colors.red,
              ),
            ],
            // Media Info
            if (mediaInfo != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Media Information',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildMediaInfoGrid(mediaInfo),
            ],
            // File Path
            if (relativePath != null && relativePath.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'File Path',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Text(
                  relativePath,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaInfoGrid(Map<String, dynamic> mediaInfo) {
    final items = <MapEntry<String, String>>[];

    // Video info
    if (mediaInfo['videoCodec'] != null) {
      items.add(MapEntry('Video Codec', mediaInfo['videoCodec']));
    }
    if (mediaInfo['resolution'] != null) {
      items.add(MapEntry('Resolution', mediaInfo['resolution']));
    }
    if (mediaInfo['videoBitDepth'] != null) {
      items.add(MapEntry('Bit Depth', '${mediaInfo['videoBitDepth']}-bit'));
    }
    if (mediaInfo['videoFps'] != null) {
      items.add(MapEntry('Frame Rate', '${mediaInfo['videoFps']} fps'));
    }
    if (mediaInfo['scanType'] != null) {
      items.add(MapEntry('Scan Type', mediaInfo['scanType']));
    }

    // Audio info
    if (mediaInfo['audioCodec'] != null) {
      items.add(MapEntry('Audio Codec', mediaInfo['audioCodec']));
    }
    if (mediaInfo['audioChannels'] != null) {
      items.add(MapEntry('Audio Channels', '${mediaInfo['audioChannels']}.0'));
    }
    if (mediaInfo['audioLanguages'] != null) {
      items.add(MapEntry('Audio Lang', mediaInfo['audioLanguages']));
    }

    // Other
    if (mediaInfo['runTime'] != null) {
      items.add(MapEntry('Duration', mediaInfo['runTime']));
    }
    if (mediaInfo['subtitles'] != null) {
      items.add(MapEntry('Subtitles', mediaInfo['subtitles']));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items
          .map(
            (item) => SizedBox(
              width: (MediaQuery.of(context).size.width - 64) / 2,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.key}: ${item.value}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$label:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatAirDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.isNegative) {
      // Future date
      final absDiff = date.difference(now);
      if (absDiff.inDays == 0) return 'Today';
      if (absDiff.inDays == 1) return 'Tomorrow';
      if (absDiff.inDays < 7) return 'In ${absDiff.inDays} days';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    // Past date
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
