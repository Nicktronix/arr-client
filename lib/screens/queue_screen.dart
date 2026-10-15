import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arr_client/models/shared/arr_queue_item.dart';
import 'package:arr_client/models/sonarr/queue_item.dart';
import 'package:arr_client/services/sonarr_service.dart';
import 'package:arr_client/services/radarr_service.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/utils/cached_data_loader.dart';
import 'package:arr_client/utils/error_formatter.dart';
import 'package:arr_client/di/injection.dart';
import 'package:arr_client/screens/manual_import_screen.dart';

class QueueScreen extends StatefulWidget {
  final VoidCallback? onSettingsPressed;

  const QueueScreen({super.key, this.onSettingsPressed});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with CachedDataLoader {
  final SonarrService _sonarr = getIt<SonarrService>();
  final RadarrService _radarr = getIt<RadarrService>();
  final AppStateManager _appState = getIt<AppStateManager>();

  List<ArrQueueItem> _queueItems = [];

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
      setState(() {});
      _loadDataIfConfigured();
    }
  }

  void _loadDataIfConfigured() {
    if (_appState.activeSonarrInstance != null ||
        _appState.activeRadarrInstance != null) {
      unawaited(loadData());
    }
  }

  @override
  String get cacheKey => 'queue_combined';

  @override
  bool get isSonarrScreen => true;

  @override
  Future<dynamic> fetchData() async {
    final hasSonarr = _appState.getActiveSonarrId() != null;
    final hasRadarr = _appState.getActiveRadarrId() != null;

    if (!hasSonarr && !hasRadarr) return <ArrQueueItem>[];

    final futures = <Future<List<ArrQueueItem>>>[];

    if (hasSonarr) futures.add(_sonarr.getQueue());
    if (hasRadarr) futures.add(_radarr.getQueue());

    final results = await Future.wait(futures);
    final items = results.expand((list) => list).toList();

    items.sort((a, b) {
      final statusA = a.status ?? '';
      final statusB = b.status ?? '';
      if (statusA == 'downloading' && statusB != 'downloading') return -1;
      if (statusA != 'downloading' && statusB == 'downloading') return 1;
      return 0;
    });

    return items;
  }

  @override
  void onDataLoaded(dynamic data) {
    setState(() {
      _queueItems = (data as List).cast<ArrQueueItem>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyInstance =
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
    final hasAnyInstance =
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

  Widget _buildQueueItemCard(ArrQueueItem item) {
    final title = item.title ?? 'Unknown';
    final status = item.status ?? 'unknown';
    final trackedDownloadStatus = item.trackedDownloadStatus;
    final statusMessages = item.statusMessages;
    final errorMessage = item.errorMessage;
    final size = item.size ?? 0.0;
    final sizeleft = item.sizeleft ?? 0.0;
    final timeLeft = item.timeleft;
    final protocol = item.protocol ?? 'unknown';
    final downloadClient = item.downloadClient;
    final indexer = item.indexer;
    final customFormats = item.customFormats;
    final cfScore = item.customFormatScore ?? 0;
    final languages = item.languages;
    final addedDate = item.added;
    final quality = item.quality?.quality?.name ?? 'Unknown Quality';

    int? ageInDays;
    if (addedDate != null) {
      try {
        final added = DateTime.parse(addedDate);
        ageInDays = DateTime.now().difference(added).inDays;
      } catch (e) {
        // Ignore parse errors
      }
    }

    final progress = size > 0 ? ((size - sizeleft) / size) : 0.0;
    final downloaded = size - sizeleft;

    final canManualImport =
        status == 'completed' ||
        trackedDownloadStatus == 'warning' ||
        trackedDownloadStatus == 'error';

    // Episode info for TV shows
    String? episodeInfo;
    if (item.isSonarr) {
      final sonarrItem = item as SonarrQueueItem;
      if (sonarrItem.episode != null) {
        final ep = sonarrItem.episode!;
        final seasonNum = ep.seasonNumber;
        final episodeNum = ep.episodeNumber;
        episodeInfo =
            'S${seasonNum.toString().padLeft(2, '0')}E${episodeNum.toString().padLeft(2, '0')}';
      } else if (sonarrItem.seasonNumber != null) {
        episodeInfo = 'Season ${sonarrItem.seasonNumber}';
      }
    }

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
                  Icon(
                    item.isSonarr ? Icons.tv : Icons.movie,
                    size: 20,
                    color: item.isSonarr ? Colors.blue : Colors.red,
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
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmRemoveQueueItem(item),
                    tooltip: 'Remove from queue',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
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
                            if (statusMessages != null &&
                                statusMessages.isNotEmpty)
                              for (final msg in statusMessages)
                                ...(msg.messages ?? []).map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      m,
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
                    '${_formatBytes(downloaded.toInt())} / ${_formatBytes(size.toInt())}',
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
                          languages.map((l) => l.name ?? 'Unknown').join(', '),
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
                      const Icon(Icons.star, size: 14, color: Colors.amber),
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
              if (customFormats != null && customFormats.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final format in customFormats)
                      Chip(
                        label: Text(
                          format.name ?? 'Unknown',
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

    if (trackedDownloadStatus == 'warning') {
      backgroundColor = Colors.amber;
      displayText = 'Warning';
    } else {
      switch (status.toLowerCase()) {
        case 'downloading':
          backgroundColor = Colors.blue;
          displayText = 'Downloading';
        case 'queued':
          backgroundColor = Colors.orange;
          displayText = 'Queued';
        case 'paused':
          backgroundColor = Colors.grey;
          displayText = 'Paused';
        case 'completed':
          backgroundColor = Colors.green;
          displayText = 'Completed';
        case 'failed':
          backgroundColor = Colors.red;
          displayText = 'Failed';
        case 'warning':
          backgroundColor = Colors.amber;
          displayText = 'Warning';
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
    final parts = timeLeft.split(':');
    if (parts.length != 3) return timeLeft;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = int.tryParse(parts[2]) ?? 0;

    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _showManualImportDialog(ArrQueueItem item) async {
    final source = item.isSonarr ? 'sonarr' : 'radarr';
    final downloadId = item.downloadId;
    final title = item.title ?? 'Unknown';

    if (downloadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No download ID available')));
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

    if (result == true && mounted) {
      unawaited(loadData(forceRefresh: true));
    }
  }

  Future<void> _confirmRemoveQueueItem(ArrQueueItem item) async {
    final title = item.title ?? 'Unknown';
    final itemId = item.id;

    if (itemId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid queue item')));
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Removing from queue...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      if (item.isSonarr) {
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
        unawaited(loadData(forceRefresh: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
