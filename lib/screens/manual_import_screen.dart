import 'package:flutter/material.dart';
import '../services/sonarr_service.dart';
import '../services/radarr_service.dart';
import '../utils/error_formatter.dart';

class ManualImportScreen extends StatefulWidget {
  final String source; // 'sonarr' or 'radarr'
  final String downloadId;
  final String title; // Queue item title for context

  const ManualImportScreen({
    super.key,
    required this.source,
    required this.downloadId,
    required this.title,
  });

  @override
  State<ManualImportScreen> createState() => _ManualImportScreenState();
}

class _ManualImportScreenState extends State<ManualImportScreen> {
  final SonarrService _sonarr = SonarrService();
  final RadarrService _radarr = RadarrService();

  bool _isLoading = true;
  String? _error;
  List<dynamic> _importCandidates = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadImportCandidates();
  }

  Future<void> _loadImportCandidates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final candidates = widget.source == 'sonarr'
          ? await _sonarr.getManualImport(
              downloadId: widget.downloadId,
              filterExistingFiles: false,
            )
          : await _radarr.getManualImport(
              downloadId: widget.downloadId,
              filterExistingFiles: false,
            );

      // Sort candidates alphabetically by relative path
      candidates.sort((a, b) {
        final pathA = (a['relativePath'] ?? '').toString().toLowerCase();
        final pathB = (b['relativePath'] ?? '').toString().toLowerCase();
        return pathA.compareTo(pathB);
      });

      setState(() {
        _importCandidates = candidates;
        _isLoading = false;

        // Pre-select all items - user can deselect if needed
        // In manual import, we trust the user to decide what to import
        _selectedIndices.clear();
        for (var i = 0; i < candidates.length; i++) {
          _selectedIndices.add(i);
        }
      });
    } catch (e) {
      setState(() {
        _error = ErrorFormatter.format(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _performImport() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected')),
      );
      return;
    }

    // Show progress
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
            Text('Importing files...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final imports = _selectedIndices
          .map((i) => _importCandidates[i] as Map<String, dynamic>)
          .toList();

      // Ensure required fields are present for each import
      for (var import in imports) {
        // Convert episodes array to episodeIds array if needed
        if (import['episodes'] != null && import['episodeIds'] == null) {
          final episodes = import['episodes'] as List;
          import['episodeIds'] = episodes.map((ep) => ep['id']).toList();
        }
        
        // Ensure seriesId is present (from series object)
        if (import['seriesId'] == null && import['series'] != null) {
          import['seriesId'] = import['series']['id'];
        }
        
        // Ensure movieId is present (from movie object)
        if (widget.source == 'radarr' && 
            import['movieId'] == null && 
            import['movie'] != null) {
          import['movieId'] = import['movie']['id'];
        }
      }

      if (widget.source == 'sonarr') {
        await _sonarr.performManualImport(imports);
      } else {
        await _radarr.performManualImport(imports);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import started successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger queue refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Import'),
        actions: [
          if (!_isLoading && _error == null && _importCandidates.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadImportCandidates,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _error != null || _importCandidates.isEmpty
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    // State 1: Loading
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading files...'),
          ],
        ),
      );
    }

    // State 2: Error
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
                'Failed to load import candidates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadImportCandidates,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // State 3: Empty
    if (_importCandidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No files found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No importable files found for this download',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // State 4: Success - Show files
    return Column(
      children: [
        // Context banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.source == 'sonarr' ? Icons.tv : Icons.movie,
                size: 20,
                color: widget.source == 'sonarr' ? Colors.blue : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Select files to import - warnings can be overridden',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_selectedIndices.length}/${_importCandidates.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        // File list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _importCandidates.length,
            itemBuilder: (context, index) {
              final candidate = _importCandidates[index];
              final isSelected = _selectedIndices.contains(index);
              return _buildImportCandidate(candidate, index, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final allSelected = _selectedIndices.length == _importCandidates.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                value: allSelected,
                tristate: true,
                onChanged: (value) {
                  setState(() {
                    if (allSelected) {
                      // Currently all selected -> deselect all
                      _selectedIndices.clear();
                    } else {
                      // Some or none selected -> select all
                      _selectedIndices.clear();
                      for (var i = 0; i < _importCandidates.length; i++) {
                        _selectedIndices.add(i);
                      }
                    }
                  });
                },
                title: Text(
                  allSelected ? 'All Selected' : 'Select All',
                  style: const TextStyle(fontSize: 14),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _selectedIndices.isEmpty ? null : _performImport,
                icon: const Icon(Icons.file_download),
                label: Text('Import ${_selectedIndices.length} file(s)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCandidate(
    Map<String, dynamic> candidate,
    int index,
    bool isSelected,
  ) {
    final relativePath = candidate['relativePath'] ?? 'Unknown';
    final size = candidate['size'] ?? 0;
    final quality =
        candidate['quality']?['quality']?['name'] ?? 'Unknown Quality';
    final languages = candidate['languages'] as List?;
    final cfScore = candidate['customFormatScore'] ?? 0;
    final customFormats = candidate['customFormats'] as List?;
    final rejections = candidate['rejections'] as List?;
    final hasRejections = rejections != null && rejections.isNotEmpty;

    // Episode info for series
    String? episodeInfo;
    String? seriesTitle;
    if (widget.source == 'sonarr') {
      seriesTitle = candidate['series']?['title'];
      final episodes = candidate['episodes'] as List?;
      if (episodes != null && episodes.isNotEmpty) {
        final seasonNum = candidate['seasonNumber'];
        final episodeNums =
            episodes.map((e) => e['episodeNumber'].toString()).join(', ');
        episodeInfo = 'S$seasonNum E$episodeNums';
      }
    } else {
      seriesTitle = candidate['movie']?['title'];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasRejections
          ? Colors.amber.withValues(alpha: 0.1)
          : isSelected
              ? Colors.blue.withValues(alpha: 0.05)
              : null,
      child: InkWell(
        onTap: () => _showEditDialog(candidate, index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIndices.add(index);
                  } else {
                    _selectedIndices.remove(index);
                  }
                });
              },
              title: Text(
              relativePath,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Match info
                if (seriesTitle != null) ...[
                  Row(
                    children: [
                      Icon(
                        widget.source == 'sonarr' ? Icons.tv : Icons.movie,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$seriesTitle${episodeInfo != null ? ' - $episodeInfo' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ] else ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'No match found - will need manual selection',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // File metadata
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      quality,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    Text(
                      _formatBytes(size),
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    if (languages != null && languages.isNotEmpty)
                      Text(
                        languages.map((l) => l['name']).join(', '),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    Text(
                      'CF: $cfScore',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
                // Custom formats
                if (customFormats != null && customFormats.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      for (var format in customFormats)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            format['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                // Rejections
                if (hasRejections) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: Colors.amber[900],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Import warnings (can be overridden):',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ...rejections.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\u2022 ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber[900],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    r['reason'] ?? 'Rejected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          // Edit button for overriding matches
          if (seriesTitle == null || hasRejections)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      seriesTitle == null
                          ? 'Tap to select ${widget.source == 'sonarr' ? 'series and episodes' : 'movie'}'
                          : 'Tap to override match or quality',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: Colors.blue[700]),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> candidate, int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditImportDialog(
        candidate: candidate,
        source: widget.source,
        sonarrService: _sonarr,
        radarrService: _radarr,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _importCandidates[index] = result;
      });
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
}

// Edit dialog for modifying import matches
class _EditImportDialog extends StatefulWidget {
  final Map<String, dynamic> candidate;
  final String source;
  final SonarrService sonarrService;
  final RadarrService radarrService;

  const _EditImportDialog({
    required this.candidate,
    required this.source,
    required this.sonarrService,
    required this.radarrService,
  });

  @override
  State<_EditImportDialog> createState() => _EditImportDialogState();
}

class _EditImportDialogState extends State<_EditImportDialog> {
  late Map<String, dynamic> _editedCandidate;
  bool _isLoadingQualities = true;
  List<Map<String, dynamic>> _availableQualities = [];
  
  // Search state
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  
  // Selected values
  Map<String, dynamic>? _selectedItem; // series or movie
  int? _selectedSeasonNumber;
  Set<int> _selectedEpisodeIds = {};
  List<dynamic> _availableEpisodes = [];
  bool _isLoadingEpisodes = false;
  Map<String, dynamic>? _selectedQuality;
  List<String> _selectedLanguages = [];
  String _releaseGroup = '';

  @override
  void initState() {
    super.initState();
    _editedCandidate = Map<String, dynamic>.from(widget.candidate);
    _initializeValues();
    _loadQualities();
    
    // If series and season are already selected, load episodes
    if (widget.source == 'sonarr' && 
        _selectedItem != null && 
        _selectedSeasonNumber != null) {
      _loadEpisodesForSeason(_selectedSeasonNumber!);
    }
  }

  void _initializeValues() {
    // Initialize from existing candidate
    _selectedItem = widget.source == 'sonarr'
        ? _editedCandidate['series']
        : _editedCandidate['movie'];
    
    _selectedSeasonNumber = _editedCandidate['seasonNumber'];
    
    final episodes = _editedCandidate['episodes'] as List?;
    if (episodes != null) {
      _selectedEpisodeIds = episodes.map((e) => e['id'] as int).toSet();
    }
    
    _selectedQuality = _editedCandidate['quality']?['quality'];
    
    final languages = _editedCandidate['languages'] as List?;
    if (languages != null) {
      _selectedLanguages = languages.map((l) => l['name'].toString()).toList();
    }
    
    _releaseGroup = _editedCandidate['releaseGroup'] ?? '';
  }

  Future<void> _loadQualities() async {
    try {
      final schema = widget.source == 'sonarr'
          ? await widget.sonarrService.getQualityProfileSchema()
          : await widget.radarrService.getQualityProfileSchema();
      
      final items = schema['items'] as List?;
      if (items != null) {
        final qualities = <Map<String, dynamic>>[];
        final seenIds = <int>{};
        
        for (var item in items) {
          if (item['quality'] != null) {
            final quality = item['quality'] as Map<String, dynamic>;
            final id = quality['id'] as int?;
            if (id != null && !seenIds.contains(id)) {
              qualities.add(quality);
              seenIds.add(id);
            }
          }
          // Also check nested items (grouped qualities)
          final nestedItems = item['items'] as List?;
          if (nestedItems != null) {
            for (var nested in nestedItems) {
              if (nested['quality'] != null) {
                final quality = nested['quality'] as Map<String, dynamic>;
                final id = quality['id'] as int?;
                if (id != null && !seenIds.contains(id)) {
                  qualities.add(quality);
                  seenIds.add(id);
                }
              }
            }
          }
        }
        setState(() {
          _availableQualities = qualities;
          _isLoadingQualities = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingQualities = false);
    }
  }

  Future<void> _loadEpisodesForSeason(int seasonNumber) async {
    if (_selectedItem == null) return;

    setState(() => _isLoadingEpisodes = true);

    try {
      final seriesId = _selectedItem!['id'] as int;
      final allEpisodes = await widget.sonarrService.getEpisodesBySeriesId(seriesId);
      
      final seasonEpisodes = allEpisodes
          .where((ep) => ep['seasonNumber'] == seasonNumber)
          .toList();
      
      setState(() {
        _availableEpisodes = seasonEpisodes;
        _isLoadingEpisodes = false;
      });
    } catch (e) {
      setState(() => _isLoadingEpisodes = false);
    }
  }

  Future<void> _searchItems(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = widget.source == 'sonarr'
          ? await widget.sonarrService.searchSeries(query)
          : await widget.radarrService.searchMovies(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _selectItem(Map<String, dynamic> item) {
    setState(() {
      _selectedItem = item;
      _searchResults = [];
      
      // Reset season/episode selection when changing series
      if (widget.source == 'sonarr') {
        _selectedSeasonNumber = null;
        _selectedEpisodeIds.clear();
      }
    });
  }

  void _applyChanges() {
    _editedCandidate[widget.source == 'sonarr' ? 'series' : 'movie'] =
        _selectedItem;
    
    if (widget.source == 'sonarr') {
      _editedCandidate['seasonNumber'] = _selectedSeasonNumber;
      
      // Build episodes list from selected IDs
      _editedCandidate['episodes'] = _availableEpisodes
          .where((e) => _selectedEpisodeIds.contains(e['id']))
          .toList();
    }
    
    if (_selectedQuality != null) {
      _editedCandidate['quality'] = {
        'quality': _selectedQuality,
      };
    }
    
    _editedCandidate['releaseGroup'] = _releaseGroup;
    
    _editedCandidate['languages'] = _selectedLanguages
        .map((name) => {'name': name})
        .toList();
    
    Navigator.pop(context, _editedCandidate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Import Match'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File name
              Text(
                _editedCandidate['relativePath'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              
              // Series/Movie search
              Text(
                widget.source == 'sonarr' ? 'Series' : 'Movie',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${widget.source == 'sonarr' ? 'series' : 'movie'}...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  _searchItems(value);
                },
              ),
              
              // Search results
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      final title = item['title'] ?? 'Unknown';
                      final year = item['year']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        title: Text(title, style: const TextStyle(fontSize: 13)),
                        subtitle: year.isNotEmpty ? Text(year, style: const TextStyle(fontSize: 11)) : null,
                        onTap: () => _selectItem(item),
                      );
                    },
                  ),
                ),
              
              // Selected series/movie
              if (_selectedItem != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.source == 'sonarr' ? Icons.tv : Icons.movie,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedItem!['title'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Season selector (TV only)
              if (widget.source == 'sonarr' && _selectedItem != null) ...[
                const SizedBox(height: 16),
                const Text('Season', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: _selectedSeasonNumber,
                  hint: const Text('Select season'),
                  items: (_selectedItem!['seasons'] as List?)
                      ?.map((season) => DropdownMenuItem<int>(
                            value: season['seasonNumber'] as int,
                            child: Text('Season ${season['seasonNumber']}'),
                          ))
                      .toList() ??
                      [],
                  onChanged: (value) {
                    setState(() {
                      _selectedSeasonNumber = value;
                      _selectedEpisodeIds.clear();
                      _availableEpisodes = [];
                    });
                    if (value != null) {
                      _loadEpisodesForSeason(value);
                    }
                  },
                ),
              ],
              
              // Episode selector (TV only)
              if (widget.source == 'sonarr' &&
                  _selectedItem != null &&
                  _selectedSeasonNumber != null) ...[
                const SizedBox(height: 16),
                const Text('Episodes', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_isLoadingEpisodes)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _availableEpisodes.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No episodes available'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableEpisodes.length,
                            itemBuilder: (context, index) {
                              final episode = _availableEpisodes[index];
                              final episodeId = episode['id'] as int;
                              final episodeNumber = episode['episodeNumber'];
                              final title = episode['title'] ?? 'TBA';

                              return CheckboxListTile(
                                dense: true,
                                title: Text(
                                  'E$episodeNumber: $title',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                value: _selectedEpisodeIds.contains(episodeId),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedEpisodeIds.add(episodeId);
                                    } else {
                                      _selectedEpisodeIds.remove(episodeId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
              ],
              
              // Quality selector
              const SizedBox(height: 16),
              const Text('Quality', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_isLoadingQualities)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: _selectedQuality?['id'] as int?,
                  hint: const Text('Select quality'),
                  items: _availableQualities
                      .map((quality) => DropdownMenuItem<int>(
                            value: quality['id'] as int,
                            child: Text(quality['name'] ?? 'Unknown'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedQuality = _availableQualities.firstWhere(
                        (q) => q['id'] == value,
                        orElse: () => {},
                      );
                    });
                  },
                ),
              
              // Release group
              const SizedBox(height: 16),
              const Text('Release Group', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Enter release group',
                ),
                controller: TextEditingController(text: _releaseGroup)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: _releaseGroup.length),
                  ),
                onChanged: (value) => _releaseGroup = value,
              ),
              
              // Languages
              const SizedBox(height: 16),
              const Text('Languages', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['English', 'Japanese', 'Other'].map((lang) {
                  return FilterChip(
                    label: Text(lang),
                    selected: _selectedLanguages.contains(lang),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLanguages.add(lang);
                        } else {
                          _selectedLanguages.remove(lang);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _applyChanges,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
