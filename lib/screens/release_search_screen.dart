import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/radarr_service.dart';
import '../services/app_state_manager.dart';
import '../config/app_config.dart';
import '../utils/error_formatter.dart';

class ReleaseSearchScreen extends StatefulWidget {
  // Episode-specific (Sonarr)
  final int? episodeId;
  final int? episodeNumber;
  final String? episodeTitle;

  // Movie-specific (Radarr)
  final int? movieId;
  final String? movieTitle;

  // Common
  final List<dynamic>? releases;

  const ReleaseSearchScreen({
    super.key,
    this.episodeId,
    this.episodeNumber,
    this.episodeTitle,
    this.movieId,
    this.movieTitle,
    this.releases,
  });

  @override
  State<ReleaseSearchScreen> createState() => _ReleaseSearchScreenState();
}

class _ReleaseSearchScreenState extends State<ReleaseSearchScreen> {
  final SonarrService _sonarr = SonarrService();
  final RadarrService _radarr = RadarrService();

  List<dynamic>? _releases;
  bool _isLoading = false;
  String? _error;
  String? _instanceIdOnLoad;

  bool get _isMovie => widget.movieId != null;

  String _filterMode = 'all'; // 'all', 'no_issues'
  bool _showSeasonPacksOnly = false;
  String _sortBy = 'seeders'; // 'seeders', 'quality', 'size', 'cf_score'
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = _isMovie
        ? AppConfig.activeRadarrInstanceId
        : AppConfig.activeSonarrInstanceId;
    if (widget.releases != null) {
      _releases = widget.releases;
    } else {
      _loadReleases();
    }
    AppStateManager().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    // If instance changed, return to previous screen
    final currentInstanceId = _isMovie
        ? AppConfig.activeRadarrInstanceId
        : AppConfig.activeSonarrInstanceId;
    if (mounted && currentInstanceId != _instanceIdOnLoad) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instance changed - returning to previous screen'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadReleases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<dynamic> releases;
      if (_isMovie) {
        releases = await _radarr.searchMovieReleases(widget.movieId!);
      } else {
        // This shouldn't happen as episodes always pass releases
        releases = [];
      }

      setState(() {
        _releases = releases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorFormatter.format(e);
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredAndSortedReleases {
    if (_releases == null) return [];
    var releases = List<dynamic>.from(_releases!);

    // Apply filters
    if (_filterMode == 'no_issues') {
      releases = releases.where((r) {
        final rejections = r['rejections'] as List?;
        return rejections == null || rejections.isEmpty;
      }).toList();
    }

    // Apply season pack filter (only for episodes, not movies)
    if (_showSeasonPacksOnly && !_isMovie) {
      releases = releases.where((r) {
        final fullSeason = r['fullSeason'] ?? false;
        return fullSeason;
      }).toList();
    }

    // Apply sorting
    releases.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'seeders':
          final aSeeders = a['seeders'] ?? 0;
          final bSeeders = b['seeders'] ?? 0;
          comparison = aSeeders.compareTo(bSeeders);
          break;
        case 'quality':
          final aWeight = a['qualityWeight'] ?? 0;
          final bWeight = b['qualityWeight'] ?? 0;
          comparison = aWeight.compareTo(bWeight);
          break;
        case 'size':
          final aSize = a['size'] ?? 0;
          final bSize = b['size'] ?? 0;
          comparison = aSize.compareTo(bSize);
          break;
        case 'cf_score':
          final aScore = a['customFormatScore'] ?? 0;
          final bScore = b['customFormatScore'] ?? 0;
          comparison = aScore.compareTo(bScore);
          break;
      }

      return _sortDescending ? -comparison : comparison;
    });

    return releases;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isMovie
                ? widget.movieTitle!
                : 'E${widget.episodeNumber}: ${widget.episodeTitle}',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isMovie
                ? widget.movieTitle!
                : 'E${widget.episodeNumber}: ${widget.episodeTitle}',
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading releases'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadReleases,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredReleases = _filteredAndSortedReleases;
    final totalReleases = _releases?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isMovie
                  ? widget.movieTitle!
                  : 'E${widget.episodeNumber}: ${widget.episodeTitle}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Showing ${filteredReleases.length} of $totalReleases releases',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () {
              setState(() => _sortDescending = !_sortDescending);
            },
            tooltip: _sortDescending ? 'Sort descending' : 'Sort ascending',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSortOptions(),
          Expanded(
            child: filteredReleases.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredReleases.length,
                    itemBuilder: (context, index) {
                      return _buildReleaseCard(filteredReleases[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _filterMode == 'all',
            onSelected: (selected) {
              if (selected) setState(() => _filterMode = 'all');
            },
          ),
          FilterChip(
            label: const Text('No Issues'),
            selected: _filterMode == 'no_issues',
            onSelected: (selected) {
              if (selected) setState(() => _filterMode = 'no_issues');
            },
          ),
          // Season packs filter only for episodes
          if (!_isMovie)
            FilterChip(
              label: const Text('Season Packs Only'),
              selected: _showSeasonPacksOnly,
              onSelected: (selected) {
                setState(() => _showSeasonPacksOnly = selected);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSortOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Seeders', 'seeders'),
                  const SizedBox(width: 8),
                  _buildSortChip('Quality', 'quality'),
                  const SizedBox(width: 8),
                  _buildSortChip('Size', 'size'),
                  const SizedBox(width: 8),
                  _buildSortChip('CF Score', 'cf_score'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _sortBy == value,
      onSelected: (selected) {
        if (selected) setState(() => _sortBy = value);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No releases match filters',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() => _filterMode = 'all');
            },
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseCard(Map<String, dynamic> release) {
    final String title = release['title'] ?? 'Unknown';
    final int seeders = release['seeders'] ?? 0;
    final int leechers = release['leechers'] ?? 0;
    final String quality = release['quality']?['quality']?['name'] ?? 'Unknown';
    final int size = release['size'] ?? 0;
    final String sizeStr = _formatBytes(size);
    final String indexer = release['indexer'] ?? 'Unknown';
    final int cfScore = release['customFormatScore'] ?? 0;
    final List<dynamic>? rejections = release['rejections'];
    final bool isRejected = rejections != null && rejections.isNotEmpty;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool hasUnknownMatch = _hasUnknownMatch(release);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: isRejected
          ? (isDarkMode
                ? Colors.red.shade900.withValues(alpha: 0.3)
                : Colors.red.shade50)
          : null,
      child: InkWell(
        onTap: () => _showReleaseDetails(release),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUnknownMatch) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'May require manual import',
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  // Show warning for unknown matches
                  if (hasUnknownMatch)
                    _buildInfoChip(
                      Icons.warning_amber,
                      'Unknown Match',
                      Colors.orange,
                    ),
                  // Show season/episode info for series releases
                  if (!_isMovie) ...[
                    if (release['mappedEpisodeInfo'] != null &&
                        (release['mappedEpisodeInfo'] as List).isNotEmpty) ...[
                      for (var epInfo in release['mappedEpisodeInfo'])
                        _buildInfoChip(
                          Icons.live_tv,
                          'S${epInfo['seasonNumber']}E${epInfo['episodeNumber']}',
                          Colors.teal,
                        ),
                    ] else if (release['fullSeason'] == true)
                      _buildInfoChip(
                        Icons.tv,
                        'Season ${release['mappedSeasonNumber'] ?? release['seasonNumber'] ?? '?'}',
                        Colors.teal,
                      ),
                  ],
                  _buildInfoChip(Icons.high_quality, quality, Colors.blue),
                  _buildInfoChip(Icons.storage, sizeStr, Colors.grey),
                  _buildInfoChip(Icons.cloud_upload, '$seeders', Colors.green),
                  _buildInfoChip(
                    Icons.cloud_download,
                    '$leechers',
                    Colors.orange,
                  ),
                  _buildInfoChip(Icons.source, indexer, Colors.purple),
                  _buildInfoChip(Icons.star, 'CF: $cfScore', Colors.amber),
                ],
              ),
              if (isRejected) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: rejections.map((rejection) {
                    final String reason = rejection is Map
                        ? (rejection['reason'] ?? 'Rejected')
                        : rejection.toString();
                    return Chip(
                      label: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.red.shade200
                              : Colors.red.shade900,
                        ),
                      ),
                      backgroundColor: isDarkMode
                          ? Colors.red.shade900.withValues(alpha: 0.5)
                          : Colors.red.shade100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool _hasUnknownMatch(Map<String, dynamic> release) {
    if (_isMovie) {
      // For movies, check if mappedMovieId is missing or 0
      return release['mappedMovieId'] == null || release['mappedMovieId'] == 0;
    } else {
      // For series, check if mappedEpisodeInfo is missing or empty (excluding season packs)
      return (release['mappedEpisodeInfo'] == null ||
              (release['mappedEpisodeInfo'] as List).isEmpty) &&
          release['fullSeason'] != true;
    }
  }

  Future<void> _showReleaseDetails(Map<String, dynamic> release) async {
    final String title = release['title'] ?? 'Unknown';
    final String quality = release['quality']?['quality']?['name'] ?? 'Unknown';
    final int size = release['size'] ?? 0;
    final int seeders = release['seeders'] ?? 0;
    final int leechers = release['leechers'] ?? 0;
    final String indexer = release['indexer'] ?? 'Unknown';
    final int cfScore = release['customFormatScore'] ?? 0;
    final int age = release['age'] ?? 0;
    final List<dynamic>? rejections = release['rejections'];
    final bool isRejected = rejections != null && rejections.isNotEmpty;
    final String? releaseGroup = release['releaseGroup'];
    final String? protocol = release['protocol'];
    final String? edition = release['edition'];
    final String? publishDate = release['publishDate'];
    final List<dynamic>? languages = release['languages'];
    final List<dynamic>? customFormats = release['customFormats'];

    // Check if release has series/movie matching issues
    final bool hasUnknownSeries = !_isMovie && _hasUnknownMatch(release);
    final bool hasUnknownMovie = _isMovie && _hasUnknownMatch(release);
    final bool hasMatchingIssues =
        hasUnknownSeries ||
        hasUnknownMovie ||
        (rejections?.any((r) {
              final reason = r is Map ? (r['reason'] ?? '') : r.toString();
              return reason.toLowerCase().contains('unknown') ||
                  reason.toLowerCase().contains('series') ||
                  reason.toLowerCase().contains('movie');
            }) ??
            false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Release'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Warning for matching issues
              if (hasMatchingIssues) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange[800],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasUnknownSeries
                                  ? 'Unknown Series Match'
                                  : hasUnknownMovie
                                  ? 'Unknown Movie Match'
                                  : 'Matching Issues Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'This release may require manual import. After downloading, '
                              'check the Queue screen and use Manual Import if needed.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Common fields (both series and movies)
              _buildDetailRow('Quality', quality),
              if (releaseGroup != null && releaseGroup.isNotEmpty)
                _buildDetailRow('Release Group', releaseGroup),
              _buildDetailRow('Size', _formatBytes(size)),
              if (protocol != null)
                _buildDetailRow('Protocol', protocol.toUpperCase()),
              if (languages != null && languages.isNotEmpty)
                _buildDetailRow(
                  'Languages',
                  languages.map((l) => l['name'] ?? 'Unknown').join(', '),
                ),
              _buildDetailRow('Indexer', indexer),
              _buildDetailRow('Seeders', '$seeders'),
              _buildDetailRow('Leechers', '$leechers'),
              _buildDetailRow('Age', '$age days'),
              if (publishDate != null)
                _buildDetailRow('Published', _formatPublishDate(publishDate)),
              // Custom formats section (common)
              if (customFormats != null && customFormats.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Custom Formats:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var format in customFormats)
                      Chip(
                        label: Text(
                          format['name'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 11),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildDetailRow('CF Score', '$cfScore'),
              ] else
                _buildDetailRow('Custom Format Score', '$cfScore'),
              // Type-specific fields
              if (!_isMovie && release['mappedEpisodeInfo'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Episodes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (var epInfo in release['mappedEpisodeInfo'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• S${epInfo['seasonNumber']}E${epInfo['episodeNumber']}: ${epInfo['title'] ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
              ],
              if (!_isMovie && release['fullSeason'] == true)
                _buildDetailRow('Type', 'Full Season Pack'),
              if (_isMovie && edition != null && edition.isNotEmpty)
                _buildDetailRow('Edition', edition),
              if (isRejected) ...[
                const SizedBox(height: 12),
                const Text(
                  'Rejections:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                for (var rejection in rejections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${rejection is Map ? (rejection['reason'] ?? 'Rejected') : rejection.toString()}',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _downloadRelease(release);
    }
  }

  String _formatPublishDate(String publishDate) {
    try {
      final date = DateTime.parse(publishDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()}y ago';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inMinutes}m ago';
      }
    } catch (e) {
      return publishDate;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _downloadRelease(Map<String, dynamic> release) async {
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
              Text('Adding to download queue...'),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );

      if (_isMovie) {
        final downloadData = {
          'guid': release['guid'],
          'indexerId': release['indexerId'],
          'movieId': widget.movieId,
        };
        await _radarr.downloadRelease(downloadData);
      } else {
        final downloadData = {
          'guid': release['guid'],
          'indexerId': release['indexerId'],
          'episodeId': widget.episodeId,
        };
        await _sonarr.downloadRelease(downloadData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to download queue'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
