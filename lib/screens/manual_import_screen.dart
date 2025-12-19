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
    // TODO: Implement full edit dialog
    // For now, show a placeholder dialog
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Import Match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate['relativePath'] ?? 'Unknown',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit functionality coming soon:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.source == 'sonarr'
                  ? '\u2022 Select series\n'
                      '\u2022 Select season and episodes\n'
                      '\u2022 Override quality\n'
                      '\u2022 Set release group\n'
                      '\u2022 Select languages'
                  : '\u2022 Select movie\n'
                      '\u2022 Override quality\n'
                      '\u2022 Set release group\n'
                      '\u2022 Select languages',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'For now, you can still import files as-is by selecting them. The API will use the current matches.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
}
