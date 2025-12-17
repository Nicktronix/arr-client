import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sonarr_service.dart';
import '../services/radarr_service.dart';
import '../services/app_state_manager.dart';
import '../utils/cached_data_loader.dart';
import '../utils/error_formatter.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onSettingsPressed;

  const HistoryScreen({super.key, this.onSettingsPressed});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with CachedDataLoader {
  final SonarrService _sonarr = SonarrService();
  final RadarrService _radarr = RadarrService();
  final AppStateManager _appState = AppStateManager();

  List<dynamic> _historyRecords = [];
  String _selectedService = 'sonarr'; // 'sonarr' or 'radarr'

  @override
  String get cacheKey => 'history_$_selectedService';

  @override
  bool get isSonarrScreen => _selectedService == 'sonarr';

  @override
  void initState() {
    super.initState();
    appState.addListener(_onInstanceChanged);
    loadData();
  }

  @override
  void dispose() {
    appState.removeListener(_onInstanceChanged);
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
      if (_selectedService == 'sonarr') {
        final instanceId = _appState.getActiveSonarrId();
        if (instanceId == null) {
          throw Exception('No active Sonarr instance');
        }
        final response = await _sonarr.getHistory(page: 1, pageSize: 50);
        return response['records'] ?? [];
      } else {
        final instanceId = _appState.getActiveRadarrId();
        if (instanceId == null) {
          throw Exception('No active Radarr instance');
        }
        final response = await _radarr.getHistory(page: 1, pageSize: 50);
        return response['records'] ?? [];
      }
    } catch (e) {
      throw ErrorFormatter.format(e);
    }
  }

  @override
  void onDataLoaded(dynamic data) {
    if (mounted) {
      setState(() {
        _historyRecords = data as List<dynamic>;
      });
    }
  }

  void _switchService(String service) {
    if (_selectedService != service) {
      setState(() {
        _selectedService = service;
        _historyRecords = [];
      });
      loadData(forceRefresh: true);
    }
  }

  String _formatEventType(String eventType) {
    switch (eventType) {
      case 'grabbed':
        return 'Grabbed';
      case 'downloadFailed':
        return 'Download Failed';
      case 'downloadFolderImported':
        return 'Imported';
      case 'downloadImported':
        return 'Imported';
      case 'episodeFileDeleted':
      case 'movieFileDeleted':
        return 'Deleted';
      case 'episodeFileRenamed':
      case 'movieFileRenamed':
        return 'Renamed';
      default:
        return eventType;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'grabbed':
        return Icons.download;
      case 'downloadFailed':
        return Icons.error_outline;
      case 'downloadFolderImported':
      case 'downloadImported':
        return Icons.check_circle_outline;
      case 'episodeFileDeleted':
      case 'movieFileDeleted':
        return Icons.delete_outline;
      case 'episodeFileRenamed':
      case 'movieFileRenamed':
        return Icons.drive_file_rename_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'grabbed':
        return Colors.blue;
      case 'downloadFailed':
        return Colors.red;
      case 'downloadFolderImported':
      case 'downloadImported':
        return Colors.green;
      case 'episodeFileDeleted':
      case 'movieFileDeleted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d, y').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  String _getItemTitle(Map<String, dynamic> record) {
    final sourceTitle = record['sourceTitle'] as String? ?? 'Unknown';

    // Parse series/episode info from sourceTitle for better formatting
    // Example: "Series.Name.S01E02.Title.1080p.WEB-DL"
    if (_selectedService == 'sonarr') {
      final match = RegExp(
        r'(.*?)[\. ]S(\d{1,2})E(\d{1,2})',
        caseSensitive: false,
      ).firstMatch(sourceTitle);
      if (match != null) {
        final seriesName = match.group(1)?.replaceAll('.', ' ') ?? '';
        final season = match.group(2) ?? '';
        final episode = match.group(3) ?? '';
        return '$seriesName - S${season.padLeft(2, '0')}E${episode.padLeft(2, '0')}';
      }
    }

    // Fall back to source title (remove common suffixes)
    return sourceTitle
        .replaceAll(
          RegExp(r'\.(1080p|720p|2160p|480p).*', caseSensitive: false),
          '',
        )
        .replaceAll('.', ' ')
        .trim();
  }

  String _getItemSubtitle(Map<String, dynamic> record) {
    final quality = record['quality'] as Map<String, dynamic>?;
    final qualityName = quality?['quality']?['name'] ?? 'Unknown';

    // Add custom format score if available
    final cfScore = record['customFormatScore'];
    if (cfScore != null && cfScore != 0) {
      return '$qualityName • CF Score: $cfScore';
    }

    return qualityName;
  }

  Widget buildSuccessBody() {
    return RefreshIndicator(
      onRefresh: () => loadData(forceRefresh: true),
      child: ListView.builder(
        itemCount: _historyRecords.length,
        itemBuilder: (context, index) {
          final record = _historyRecords[index] as Map<String, dynamic>;
          final eventType = record['eventType'] as String? ?? 'unknown';
          final sourceTitle = record['sourceTitle'] ?? 'Unknown Source';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getEventColor(eventType).withValues(alpha: 0.2),
              child: Icon(
                _getEventIcon(eventType),
                color: _getEventColor(eventType),
                size: 20,
              ),
            ),
            title: Text(
              _getItemTitle(record),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getItemSubtitle(record),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatEventType(eventType),
                      style: TextStyle(
                        color: _getEventColor(eventType),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' • ${_formatDate(record['date'] as String?)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              // Show detailed info dialog
              final data = record['data'] as Map<String, dynamic>?;
              final failureMessage = data?['message'] as String?;

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(_formatEventType(eventType)),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getItemTitle(record),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Source: $sourceTitle'),
                        const SizedBox(height: 4),
                        Text(
                          'Quality: ${record['quality']?['quality']?['name'] ?? 'Unknown'}',
                        ),
                        if (record['customFormatScore'] != null) ...[
                          const SizedBox(height: 4),
                          Text('CF Score: ${record['customFormatScore']}'),
                        ],
                        if (data?['downloadClient'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Client: ${data!['downloadClient']}'),
                        ],
                        if (failureMessage != null &&
                            eventType == 'downloadFailed') ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 4),
                          Text(
                            'Failure Reason:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            failureMessage,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${DateFormat('MMM d, y h:mm a').format(DateTime.parse(record['date']))}',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sonarrName = _appState.getActiveSonarrName();
    final radarrName = _appState.getActiveRadarrName();
    final hasSonarr = _appState.getActiveSonarrId() != null;
    final hasRadarr = _appState.getActiveRadarrId() != null;
    final hasAnyInstance = hasSonarr || hasRadarr;

    // Auto-switch to available service if current one is unavailable
    if (_selectedService == 'sonarr' && !hasSonarr && hasRadarr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchService('radarr');
      });
    } else if (_selectedService == 'radarr' && !hasRadarr && hasSonarr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchService('sonarr');
      });
    }

    return Scaffold(
      appBar: hasAnyInstance
          ? AppBar(
              title: Text(
                _selectedService == 'sonarr'
                    ? 'History${sonarrName != null ? " - $sonarrName" : ""}'
                    : 'History${radarrName != null ? " - $radarrName" : ""}',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => loadData(forceRefresh: true),
                ),
              ],
              bottom: (hasSonarr && hasRadarr)
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _switchService('sonarr'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedService == 'sonarr'
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Sonarr',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: _selectedService == 'sonarr'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _switchService('radarr'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedService == 'radarr'
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Radarr',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: _selectedService == 'radarr'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            )
          : null,
      body: !hasAnyInstance
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey[400]),
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
                      'Add Sonarr or Radarr instances in Settings to view history',
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
            )
          : buildBody(
              buildContent: buildSuccessBody,
              isEmpty: _historyRecords.isEmpty,
              emptyStateWidget: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'History will appear here as downloads complete',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
