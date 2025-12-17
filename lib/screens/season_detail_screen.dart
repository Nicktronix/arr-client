import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/app_state_manager.dart';
import '../config/app_config.dart';
import 'release_search_screen.dart';
import '../utils/error_formatter.dart';

class SeasonDetailScreen extends StatefulWidget {
  final int seriesId;
  final int seasonNumber;
  final String seriesTitle;

  const SeasonDetailScreen({
    super.key,
    required this.seriesId,
    required this.seasonNumber,
    required this.seriesTitle,
  });

  @override
  State<SeasonDetailScreen> createState() => _SeasonDetailScreenState();
}

class _SeasonDetailScreenState extends State<SeasonDetailScreen> {
  final SonarrService _sonarr = SonarrService();
  List<dynamic> _episodes = [];
  bool _isLoading = true;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeSonarrInstanceId;
    _loadSeasonData();
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

  Future<void> _loadSeasonData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get episodes for this series
      final allEpisodes = await _sonarr.getEpisodesBySeriesId(widget.seriesId);

      // Filter episodes for this season
      final seasonEpisodes = allEpisodes
          .where((ep) => ep['seasonNumber'] == widget.seasonNumber)
          .toList();

      // Sort by episode number
      seasonEpisodes.sort(
        (a, b) =>
            (a['episodeNumber'] as int).compareTo(b['episodeNumber'] as int),
      );

      setState(() {
        _episodes = seasonEpisodes;
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.seriesTitle, style: const TextStyle(fontSize: 16)),
            Text(
              'Season ${widget.seasonNumber}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
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
            Text('Loading episodes...'),
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
                'Error loading season',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadSeasonData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_episodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No episodes found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Season ${widget.seasonNumber} has no episodes yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _episodes.length,
      itemBuilder: (context, index) {
        return _buildEpisodeCard(_episodes[index]);
      },
    );
  }

  Widget _buildEpisodeCard(Map<String, dynamic> episode) {
    final int episodeNumber = episode['episodeNumber'] ?? 0;
    final String title = episode['title'] ?? 'TBA';
    final String? overview = episode['overview'];
    final String? airDateUtc = episode['airDateUtc'];
    final bool hasFile = episode['hasFile'] ?? false;
    final bool monitored = episode['monitored'] ?? false;

    DateTime? airDate;
    if (airDateUtc != null) {
      try {
        airDate = DateTime.parse(airDateUtc);
      } catch (e) {
        // Invalid date
      }
    }

    final bool hasAired = airDate != null && airDate.isBefore(DateTime.now());
    final bool isUpcoming = airDate != null && airDate.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Episode number badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasFile
                        ? Colors.green
                        : hasAired
                        ? Colors.red
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'E$episodeNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (airDate != null) ...[
                            Icon(
                              isUpcoming
                                  ? Icons.schedule
                                  : Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(airDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else ...[
                            Text(
                              'TBA',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Icon(
                            hasFile ? Icons.check_circle : Icons.download,
                            size: 14,
                            color: hasFile ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasFile ? 'Downloaded' : 'Missing',
                            style: TextStyle(
                              fontSize: 13,
                              color: hasFile ? Colors.green : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      monitored ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                      color: monitored ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.person, size: 20),
                      onPressed: () => _showInteractiveSearch(episode),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Search for releases',
                    ),
                  ],
                ),
              ],
            ),
            if (overview != null && overview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                overview,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showInteractiveSearch(Map<String, dynamic> episode) async {
    final episodeId = episode['id'];
    final episodeTitle = episode['title'] ?? 'Unknown';
    final episodeNumber = episode['episodeNumber'] ?? 0;

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
      final releases = await _sonarr.searchEpisodeReleases(episodeId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (releases.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No releases found')));
        return;
      }

      // Navigate to release search screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReleaseSearchScreen(
            episodeId: episodeId,
            episodeNumber: episodeNumber,
            episodeTitle: episodeTitle,
            releases: releases,
          ),
        ),
      );

      // Reload season data if a download was initiated
      if (result == true && mounted) {
        _loadSeasonData();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: ${ErrorFormatter.format(e)}')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final episodeDate = DateTime(date.year, date.month, date.day);

    if (episodeDate == today) {
      return 'Today';
    } else if (episodeDate == yesterday) {
      return 'Yesterday';
    } else if (episodeDate == tomorrow) {
      return 'Tomorrow';
    } else if (date.isAfter(now)) {
      final difference = date.difference(now).inDays;
      if (difference < 7) {
        return 'In $difference days';
      }
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
