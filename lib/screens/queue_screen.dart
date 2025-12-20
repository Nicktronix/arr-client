import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/radarr_service.dart';
import '../services/app_state_manager.dart';
import '../utils/cached_data_loader.dart';
import 'manual_import_screen.dart';

class QueueScreen extends StatefulWidget {
  final VoidCallback? onSettingsPressed;

  const QueueScreen({super.key, this.onSettingsPressed});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with CachedDataLoader {
  final SonarrService _sonarr = SonarrService();
  final RadarrService _radarr = RadarrService();
  final AppStateManager _appState = AppStateManager();

  List<Map<String, dynamic>> _queueItems = [];

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onInstanceChanged);
    _loadDataIfConfigured();
  }

  @override
  void dispose() {
    _appState.removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    if (mounted) {
      setState(() {
        // Rebuild with new instance state
      });
      _loadDataIfConfigured();
    }
  }

  void _loadDataIfConfigured() {
    // Only load data if at least one instance is configured
    if (_appState.activeSonarrInstance != null ||
        _appState.activeRadarrInstance != null) {
      loadData();
    }
  }

  @override
  String get cacheKey => 'queue_combined';

  @override
  bool get isSonarrScreen => true; // Use Sonarr cache bucket for combined queue

  @override
  Future<dynamic> fetchData() async {
    final List<Future<Map<String, dynamic>>> futures = [];
    final bool hasSonarr = _appState.getActiveSonarrId() != null;
    final bool hasRadarr = _appState.getActiveRadarrId() != null;

    if (hasSonarr) {
      futures.add(_sonarr.getQueue());
    }

    if (hasRadarr) {
      futures.add(_radarr.getQueue());
    }

    if (futures.isEmpty) {
      return [];
    }

    final results = await Future.wait(futures);
    final List<Map<String, dynamic>> items = [];

    int resultIndex = 0;

    // Add Sonarr queue items if instance exists
    if (hasSonarr && resultIndex < results.length) {
      final sonarrQueue = results[resultIndex++];
      if (sonarrQueue['records'] != null) {
        for (var item in sonarrQueue['records']) {
          items.add({...item, 'source': 'sonarr'});
        }
      }
    }

    // Add Radarr queue items if instance exists
    if (hasRadarr && resultIndex < results.length) {
      final radarrQueue = results[resultIndex++];
      if (radarrQueue['records'] != null) {
        for (var item in radarrQueue['records']) {
          items.add({...item, 'source': 'radarr'});
        }
      }
    }

    // Sort by download progress (downloading first)
    items.sort((a, b) {
      final statusA = a['status'] ?? '';
      final statusB = b['status'] ?? '';
      if (statusA == 'downloading' && statusB != 'downloading') return -1;
      if (statusA != 'downloading' && statusB == 'downloading') return 1;
      return 0;
    });

    return items;
  }

  @override
  void onDataLoaded(dynamic data) {
    setState(() {
      _queueItems = data as List<Map<String, dynamic>>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAnyInstance =
        _appState.getActiveSonarrId() != null ||
        _appState.getActiveRadarrId() != null;

    return Scaffold(
      appBar: hasAnyInstance
          ? AppBar(
              title: const Text('Download Queue'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => loadData(forceRefresh: true),
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: !hasAnyInstance
          ? _buildEmptyState()
          : buildBody(
              buildContent: buildSuccessBody,
              isEmpty: _queueItems.isEmpty,
              emptyStateWidget: _buildEmptyState(),
            ),
    );
  }

  Widget _buildEmptyState() {
    final bool hasAnyInstance =
        _appState.activeSonarrInstance != null ||
        _appState.activeRadarrInstance != null;

    if (!hasAnyInstance) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_outlined, size: 80, color: Colors.grey[400]),
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
                'Add Sonarr or Radarr instances in Settings to view downloads',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onSettingsPressed,
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
          Icon(Icons.download_done, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Queue is Empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No active downloads',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget buildSuccessBody() {
    return RefreshIndicator(
      onRefresh: () => loadData(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _queueItems.length,
        itemBuilder: (context, index) {
          return _buildQueueItemCard(_queueItems[index]);
        },
      ),
    );
  }

  Widget _buildQueueItemCard(Map<String, dynamic> item) {
    final String source = item['source'];
    final String title = item['title'] ?? 'Unknown';
    final String status = item['status'] ?? 'unknown';
    final String? trackedDownloadStatus = item['trackedDownloadStatus'];
    final List<dynamic>? statusMessages = item['statusMessages'];
    final String? errorMessage = item['errorMessage'];
    final double size = (item['size'] ?? 0).toDouble();
    final double sizeleft = (item['sizeleft'] ?? 0).toDouble();
    final String? timeLeft = item['timeleft'];
    final String protocol = item['protocol'] ?? 'unknown';
    final String? downloadClient = item['downloadClient'];
    final String? indexer = item['indexer'];
    final List<dynamic>? customFormats = item['customFormats'];
    final int cfScore = item['customFormatScore'] ?? 0;
    final List<dynamic>? languages = item['languages'];
    final String? addedDate = item['added'];

    // Calculate age
    int? ageInDays;
    if (addedDate != null) {
      try {
        final added = DateTime.parse(addedDate);
        ageInDays = DateTime.now().difference(added).inDays;
      } catch (e) {
        // Ignore parse errors
      }
    }

    // Calculate progress
    final double progress = size > 0 ? ((size - sizeleft) / size) : 0.0;
    final double downloadedMB = (size - sizeleft) / 1024 / 1024;
    final double totalMB = size / 1024 / 1024;

    // Check if this item can be manually imported
    // Manual import available when there are import issues (warning/error status)
    final bool canManualImport =
        trackedDownloadStatus == 'warning' || trackedDownloadStatus == 'error';

    // Get episode info for TV shows
    String? episodeInfo;
    if (source == 'sonarr' && item['episode'] != null) {
      final episode = item['episode'];
      final seasonNum = episode['seasonNumber'];
      final episodeNum = episode['episodeNumber'];
      episodeInfo =
          'S${seasonNum.toString().padLeft(2, '0')}E${episodeNum.toString().padLeft(2, '0')}';
    } else if (source == 'sonarr' && item['seasonNumber'] != null) {
      // Fallback to top-level season/episode if episode object not present
      final seasonNum = item['seasonNumber'];
      episodeInfo = 'Season $seasonNum';
    }

    // Get quality info
    final quality = item['quality']?['quality']?['name'] ?? 'Unknown Quality';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: InkWell(
        onTap: canManualImport ? () => _showManualImportDialog(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Source indicator
                  Icon(
                    source == 'sonarr' ? Icons.tv : Icons.movie,
                    size: 20,
                    color: source == 'sonarr' ? Colors.blue : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (episodeInfo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            episodeInfo,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusChip(status, trackedDownloadStatus),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmRemoveQueueItem(item),
                    tooltip: 'Remove from queue',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              // Warning/error messages banner
              // Show when either:
              // 1. trackedDownloadStatus is warning with statusMessages
              // 2. status is warning with errorMessage (even if trackedDownloadStatus is ok)
              if ((trackedDownloadStatus == 'warning' &&
                      statusMessages != null &&
                      statusMessages.isNotEmpty) ||
                  (status == 'warning' &&
                      errorMessage != null &&
                      errorMessage.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.amber[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show errorMessage if present
                            if (errorMessage != null && errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ),
                            // Show statusMessages if present
                            if (statusMessages != null && statusMessages.isNotEmpty)
                              for (var msg in statusMessages)
                                ...((msg['messages'] as List?) ?? []).map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      m.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      if (canManualImport) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.touch_app,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(status),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${downloadedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        timeLeft != null && timeLeft != '00:00:00'
                            ? _formatTimeLeft(timeLeft)
                            : 'Completed',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        protocol.toLowerCase() == 'torrent'
                            ? Icons.cloud_download
                            : Icons.rss_feed,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        protocol.toUpperCase(),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.high_quality,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        quality,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (languages != null && languages.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          languages
                              .map((l) => l['name'] ?? 'Unknown')
                              .join(', '),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  if (downloadClient != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          downloadClient,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  if (indexer != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.source, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          indexer,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'CF: $cfScore',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (ageInDays != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$ageInDays ${ageInDays == 1 ? 'day' : 'days'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Custom formats
              if (customFormats != null && customFormats.isNotEmpty) ...[
                const SizedBox(height: 8),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String? trackedDownloadStatus) {
    Color backgroundColor;
    String displayText;

    // Priority: trackedDownloadStatus (warning) > status
    if (trackedDownloadStatus == 'warning') {
      backgroundColor = Colors.amber;
      displayText = 'Warning';
    } else {
      switch (status.toLowerCase()) {
        case 'downloading':
          backgroundColor = Colors.blue;
          displayText = 'Downloading';
          break;
        case 'queued':
          backgroundColor = Colors.orange;
          displayText = 'Queued';
          break;
        case 'paused':
          backgroundColor = Colors.grey;
          displayText = 'Paused';
          break;
        case 'completed':
          backgroundColor = Colors.green;
          displayText = 'Completed';
          break;
        case 'failed':
          backgroundColor = Colors.red;
          displayText = 'Failed';
          break;
        case 'warning':
          backgroundColor = Colors.amber;
          displayText = 'Warning';
          break;
        default:
          backgroundColor = Colors.grey;
          displayText = status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getProgressColor(String status) {
    switch (status.toLowerCase()) {
      case 'downloading':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'warning':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  String _formatTimeLeft(String timeLeft) {
    // timeLeft is in format like "00:15:30" (HH:MM:SS)
    final parts = timeLeft.split(':');
    if (parts.length != 3) return timeLeft;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = int.tryParse(parts[2]) ?? 0;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _showManualImportDialog(Map<String, dynamic> item) async {
    final String source = item['source'];
    final String? downloadId = item['downloadId'];
    final String title = item['title'] ?? 'Unknown';

    if (downloadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download ID available')),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ManualImportScreen(
          source: source,
          downloadId: downloadId,
          title: title,
        ),
      ),
    );

    // Refresh queue if import was successful
    if (result == true && mounted) {
      loadData(forceRefresh: true);
    }
  }

  Future<void> _confirmRemoveQueueItem(Map<String, dynamic> item) async {
    final String title = item['title'] ?? 'Unknown';
    final String source = item['source'];
    final int? itemId = item['id'];

    if (itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid queue item')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Queue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove "$title" from the queue?'),
            const SizedBox(height: 16),
            const Text(
              'This will remove the download from your download client.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                const Text('Removing from queue...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Remove from appropriate service
      if (source == 'sonarr') {
        await _sonarr.removeQueueItem(itemId);
      } else {
        await _radarr.removeQueueItem(itemId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from queue'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the queue
        loadData(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
