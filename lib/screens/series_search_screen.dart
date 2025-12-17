import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/app_state_manager.dart';
import '../config/app_config.dart';
import '../utils/error_formatter.dart';

class SeriesSearchScreen extends StatefulWidget {
  const SeriesSearchScreen({super.key});

  @override
  State<SeriesSearchScreen> createState() => _SeriesSearchScreenState();
}

class _SeriesSearchScreenState extends State<SeriesSearchScreen> {
  final SonarrService _sonarr = SonarrService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _searchResults = [];
  List<dynamic> _existingSeries = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeSonarrInstanceId;
    _loadExistingSeries();
    AppStateManager().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    AppStateManager().removeListener(_onInstanceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onInstanceChanged() {
    // If instance changed, return to previous screen
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

  Future<void> _loadExistingSeries() async {
    try {
      final series = await _sonarr.getSeries();
      setState(() {
        _existingSeries = series;
      });
    } catch (e) {
      // Non-critical error, just won't show "already added" status
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      final results = await _sonarr.searchSeries(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorFormatter.format(e);
        _isSearching = false;
      });
    }
  }

  bool _isSeriesInLibrary(Map<String, dynamic> series) {
    final tvdbId = series['tvdbId'];
    if (tvdbId == null) return false;

    return _existingSeries.any((s) => s['tvdbId'] == tvdbId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Series')),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for TV series...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: _performSearch,
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
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
                'Search Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _performSearch(_searchController.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for TV Series',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a series name to search',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildSearchResultCard(_searchResults[index]);
      },
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> series) {
    final String title = series['title'] ?? 'Unknown Title';
    final int year = series['year'] ?? 0;
    final String? network = series['network'];
    final String? overview = series['overview'];
    final bool inLibrary = _isSeriesInLibrary(series);
    final String status = series['status'] ?? 'unknown';

    // Get poster image
    final List<dynamic>? images = series['images'];
    String? posterUrl;
    if (images != null) {
      for (var image in images) {
        if (image['coverType'] == 'poster') {
          posterUrl = image['remoteUrl'];
          break;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (inLibrary) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This series is already in your library'),
              ),
            );
          } else {
            _showAddSeriesDialog(series);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: posterUrl != null
                    ? Image.network(
                        posterUrl,
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.tv, size: 40),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.tv, size: 40),
                      ),
              ),
              const SizedBox(width: 12),
              // Series Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (year > 0) ...[
                      Text(
                        network != null ? '$year • $network' : '$year',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      _formatStatus(status),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                    if (inLibrary) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'In Library',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!inLibrary)
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSeriesDialog(Map<String, dynamic> series) async {
    // Get quality profiles, root folders, and tags
    List<dynamic>? qualityProfiles;
    List<dynamic>? rootFolders;
    List<dynamic>? tags;

    try {
      final results = await Future.wait([
        _sonarr.getQualityProfiles(),
        _sonarr.getRootFolders(),
        _sonarr.getTags(),
      ]);
      qualityProfiles = results[0];
      rootFolders = results[1];
      tags = results[2];
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

    if (qualityProfiles.isEmpty || rootFolders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please configure quality profiles and root folders in Sonarr',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    int selectedQualityProfile = qualityProfiles.first['id'];
    String selectedRootFolder = rootFolders.first['path'];
    List<int> selectedTags = [];
    String selectedSeriesType = 'standard';
    bool searchForMissingEpisodes = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add ${series['title']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quality Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: selectedQualityProfile,
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
                    setDialogState(() => selectedQualityProfile = value!);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Root Folder',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRootFolder,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: rootFolders!.map((folder) {
                    return DropdownMenuItem<String>(
                      value: folder['path'],
                      child: Text(folder['path']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedRootFolder = value!);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Series Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedSeriesType,
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
                    setDialogState(() => selectedSeriesType = value!);
                  },
                ),
                const SizedBox(height: 16),
                if (tags != null && tags.isNotEmpty) ...[
                  const Text(
                    'Tags',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) {
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
                  const SizedBox(height: 8),
                ],
                CheckboxListTile(
                  value: searchForMissingEpisodes,
                  onChanged: (value) {
                    setDialogState(
                      () => searchForMissingEpisodes = value ?? false,
                    );
                  },
                  title: const Text('Search for Missing Episodes'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _addSeriesToLibrary(
                  series,
                  selectedQualityProfile,
                  selectedRootFolder,
                  selectedTags,
                  selectedSeriesType,
                  searchForMissingEpisodes,
                );
              },
              child: const Text('Add Series'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSeriesToLibrary(
    Map<String, dynamic> series,
    int qualityProfileId,
    String rootFolderPath,
    List<int> tags,
    String seriesType,
    bool searchForMissingEpisodes,
  ) async {
    try {
      // Show loading indicator
      if (mounted) {
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
                Text('Adding series...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final seriesData = {
        'title': series['title'],
        'tvdbId': series['tvdbId'],
        'qualityProfileId': qualityProfileId,
        'rootFolderPath': rootFolderPath,
        'monitored': true,
        'seasonFolder': true,
        'seriesType': seriesType,
        'tags': tags,
        'addOptions': {
          'monitor': 'all',
          'searchForMissingEpisodes': searchForMissingEpisodes,
          'searchForCutoffUnmetEpisodes': false,
        },
        // Copy over other necessary fields from search result
        'titleSlug': series['titleSlug'],
        'images': series['images'],
        'seasons': series['seasons'],
      };

      await _sonarr.addSeries(seriesData);

      // Reload existing series
      await _loadExistingSeries();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${series['title']} added successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Update UI to show series is now in library
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding series: ${ErrorFormatter.format(e)}'),
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
      case 'upcoming':
        return 'Upcoming';
      default:
        return status.substring(0, 1).toUpperCase() +
            status.substring(1).toLowerCase();
    }
  }
}
