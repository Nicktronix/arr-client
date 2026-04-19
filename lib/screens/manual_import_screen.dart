import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/shared/quality_profile.dart';
import 'package:arr_client/models/sonarr/manual_import.dart';
import 'package:arr_client/models/sonarr/series.dart';
import 'package:arr_client/models/radarr/manual_import.dart';
import 'package:arr_client/models/radarr/movie.dart';
import 'package:arr_client/services/sonarr_service.dart';
import 'package:arr_client/services/radarr_service.dart';
import 'package:arr_client/utils/error_formatter.dart';
import 'package:arr_client/di/injection.dart';

// ---------------------------------------------------------------------------
// Sealed candidate union — typed throughout, no toJson at load time.
// Only toJson() calls appear in _performImport when building API request body.
// ---------------------------------------------------------------------------

sealed class _ImportCandidate {
  String? get path;
  String? get relativePath;
  int? get size;
  QualityModel? get quality;
  List<Language>? get languages;
  int? get customFormatScore;
  List<CustomFormatResource>? get customFormats;
  List<ImportRejection>? get rejections;
  String? get releaseGroup;
}

final class _SonarrCandidate extends _ImportCandidate {
  final SonarrManualImport data;
  _SonarrCandidate(this.data);

  @override
  String? get path => data.path;
  @override
  String? get relativePath => data.relativePath;
  @override
  int? get size => data.size;
  @override
  QualityModel? get quality => data.quality;
  @override
  List<Language>? get languages => data.languages;
  @override
  int? get customFormatScore => data.customFormatScore;
  @override
  List<CustomFormatResource>? get customFormats => data.customFormats;
  @override
  List<ImportRejection>? get rejections => data.rejections;
  @override
  String? get releaseGroup => data.releaseGroup;
}

final class _RadarrCandidate extends _ImportCandidate {
  final RadarrManualImport data;
  _RadarrCandidate(this.data);

  @override
  String? get path => data.path;
  @override
  String? get relativePath => data.relativePath;
  @override
  int? get size => data.size;
  @override
  QualityModel? get quality => data.quality;
  @override
  List<Language>? get languages => data.languages;
  @override
  int? get customFormatScore => data.customFormatScore;
  @override
  List<CustomFormatResource>? get customFormats => data.customFormats;
  @override
  List<ImportRejection>? get rejections => data.rejections;
  @override
  String? get releaseGroup => data.releaseGroup;
}

// ---------------------------------------------------------------------------

class ManualImportScreen extends StatefulWidget {
  final String source; // 'sonarr' or 'radarr'
  final String downloadId;
  final String title;

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
  final SonarrService _sonarr = getIt<SonarrService>();
  final RadarrService _radarr = getIt<RadarrService>();

  bool _isLoading = true;
  String? _error;
  List<_ImportCandidate> _importCandidates = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadImportCandidates());
  }

  Future<void> _loadImportCandidates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<_ImportCandidate> candidates;
      if (widget.source == 'sonarr') {
        final typed = await _sonarr.getManualImport(
          downloadId: widget.downloadId,
          filterExistingFiles: false,
        );
        candidates = typed.map<_ImportCandidate>(_SonarrCandidate.new).toList();
      } else {
        final typed = await _radarr.getManualImport(
          downloadId: widget.downloadId,
          filterExistingFiles: false,
        );
        candidates = typed.map<_ImportCandidate>(_RadarrCandidate.new).toList();
      }

      candidates.sort((a, b) {
        final pathA = (a.relativePath ?? '').toLowerCase();
        final pathB = (b.relativePath ?? '').toLowerCase();
        return pathA.compareTo(pathB);
      });

      if (!mounted) return;
      setState(() {
        _importCandidates = candidates;
        _isLoading = false;
        _selectedIndices.clear();
        for (var i = 0; i < candidates.length; i++) {
          _selectedIndices.add(i);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorFormatter.format(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _performImport() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No files selected')));
      return;
    }

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
      final sonarrImports = <Map<String, dynamic>>[];
      final radarrImports = <Map<String, dynamic>>[];

      for (final index in _selectedIndices) {
        final candidate = _importCandidates[index];
        switch (candidate) {
          case _SonarrCandidate(:final data):
            final episodeIds = (data.episodes ?? [])
                .where((ep) => ep.id != null)
                .map((ep) => ep.id!)
                .toList();
            sonarrImports.add({
              'path': data.path,
              'seriesId': data.series?.id,
              'episodeIds': episodeIds,
              'quality': data.quality?.toJson(),
              'languages':
                  data.languages?.map((l) => l.toJson()).toList() ?? [],
              'releaseGroup': data.releaseGroup ?? '',
              'downloadId': widget.downloadId,
              'indexerFlags': 0,
              'releaseType': 'unknown',
            });
          case _RadarrCandidate(:final data):
            radarrImports.add({
              'path': data.path,
              'movieId': data.movie?.id,
              'quality': data.quality?.toJson(),
              'languages':
                  data.languages?.map((l) => l.toJson()).toList() ?? [],
              'releaseGroup': data.releaseGroup ?? '',
              'downloadId': widget.downloadId,
              'indexerFlags': 0,
            });
        }
      }

      if (sonarrImports.isNotEmpty) {
        await _sonarr.performManualImport(sonarrImports);
      }
      if (radarrImports.isNotEmpty) {
        await _radarr.performManualImport(radarrImports);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import started successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
      bottomNavigationBar:
          _isLoading || _error != null || _importCandidates.isEmpty
          ? null
          : _buildBottomBar(),
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
            Text('Loading files...'),
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

    return Column(
      children: [
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
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                      _selectedIndices.clear();
                    } else {
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
    _ImportCandidate candidate,
    int index,
    bool isSelected,
  ) {
    final relativePath = candidate.relativePath ?? 'Unknown';
    final size = candidate.size ?? 0;
    final quality = candidate.quality?.quality?.name ?? 'Unknown Quality';
    final languages = candidate.languages;
    final cfScore = candidate.customFormatScore ?? 0;
    final customFormats = candidate.customFormats;
    final rejections = candidate.rejections;
    final hasRejections = rejections != null && rejections.isNotEmpty;

    String? matchTitle;
    String? episodeInfo;
    switch (candidate) {
      case _SonarrCandidate(:final data):
        matchTitle = data.series?.title;
        final episodes = data.episodes;
        if (episodes != null && episodes.isNotEmpty) {
          final seasonNum = data.seasonNumber;
          final episodeNums = episodes
              .map((e) => e.episodeNumber?.toString() ?? '?')
              .join(', ');
          episodeInfo = 'S$seasonNum E$episodeNums';
        }
      case _RadarrCandidate(:final data):
        matchTitle = data.movie?.title;
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
                  if (matchTitle != null) ...[
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
                            '$matchTitle${episodeInfo != null ? ' - $episodeInfo' : ''}',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
                          languages.map((l) => l.name ?? 'Unknown').join(', '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      Text(
                        'CF: $cfScore',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  if (customFormats != null && customFormats.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final format in customFormats)
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
                              format.name ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
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
                                      r.reason ?? 'Rejected',
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
            if (matchTitle == null || hasRejections)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                        matchTitle == null
                            ? 'Tap to select ${widget.source == 'sonarr' ? 'series and episodes' : 'movie'}'
                            : 'Tap to override match or quality',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(_ImportCandidate candidate, int index) async {
    final result = await showDialog<_ImportCandidate>(
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

// ---------------------------------------------------------------------------
// Edit dialog — typed form state, returns updated _ImportCandidate via copyWith
// ---------------------------------------------------------------------------

class _EditImportDialog extends StatefulWidget {
  final _ImportCandidate candidate;
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
  bool _isLoadingQualities = true;
  List<Quality> _availableQualities = [];
  List<SeriesResource> _seriesLibrary = [];
  List<MovieResource> _movieLibrary = [];
  List<SeriesResource> _seriesResults = [];
  List<MovieResource> _movieResults = [];
  SeriesResource? _selectedSeries;
  MovieResource? _selectedMovie;
  int? _selectedSeasonNumber;
  Set<int> _selectedEpisodeIds = {};
  List<EpisodeResource> _availableEpisodes = [];
  bool _isLoadingEpisodes = false;
  Quality? _selectedQuality;
  List<LanguageResource> _availableLanguages = [];
  List<int> _selectedLanguageIds = [];
  String _releaseGroup = '';
  late TextEditingController _releaseGroupController;

  @override
  void initState() {
    super.initState();
    _initializeValues();
    _releaseGroupController = TextEditingController(text: _releaseGroup);
    unawaited(_loadQualities());
    unawaited(_loadLanguages());
    unawaited(_loadLibraryItems());

    if (widget.source == 'sonarr' &&
        _selectedSeries != null &&
        _selectedSeasonNumber != null) {
      unawaited(_loadEpisodesForSeason(_selectedSeasonNumber!));
    }
  }

  @override
  void dispose() {
    _releaseGroupController.dispose();
    super.dispose();
  }

  void _initializeValues() {
    switch (widget.candidate) {
      case _SonarrCandidate(:final data):
        _selectedSeries = data.series;
        _selectedSeasonNumber = data.seasonNumber;
        if (data.episodes != null) {
          _selectedEpisodeIds = data.episodes!
              .where((e) => e.id != null)
              .map((e) => e.id!)
              .toSet();
        }
        _selectedQuality = data.quality?.quality;
        if (data.languages != null) {
          _selectedLanguageIds = data.languages!
              .where((l) => l.id != null)
              .map((l) => l.id!)
              .toList();
        }
        _releaseGroup = data.releaseGroup ?? '';
      case _RadarrCandidate(:final data):
        _selectedMovie = data.movie;
        _selectedQuality = data.quality?.quality;
        if (data.languages != null) {
          _selectedLanguageIds = data.languages!
              .where((l) => l.id != null)
              .map((l) => l.id!)
              .toList();
        }
        _releaseGroup = data.releaseGroup ?? '';
    }
  }

  Future<void> _loadQualities() async {
    try {
      final profiles = widget.source == 'sonarr'
          ? await widget.sonarrService.getQualityProfiles()
          : await widget.radarrService.getQualityProfiles();

      final qualities = <Quality>[];
      final seenIds = <int>{};

      for (final profile in profiles) {
        for (final item in profile.items ?? <QualityProfileItem>[]) {
          if (item.quality != null) {
            final id = item.quality!.id;
            if (id != null && !seenIds.contains(id)) {
              qualities.add(item.quality!);
              seenIds.add(id);
            }
          }
          for (final nested in item.items ?? <QualityProfileItem>[]) {
            if (nested.quality != null) {
              final id = nested.quality!.id;
              if (id != null && !seenIds.contains(id)) {
                qualities.add(nested.quality!);
                seenIds.add(id);
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableQualities = qualities;
          _isLoadingQualities = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingQualities = false);
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = widget.source == 'sonarr'
          ? await widget.sonarrService.getLanguages()
          : await widget.radarrService.getLanguages();
      if (mounted) {
        setState(() => _availableLanguages = langs);
      }
    } catch (e) {
      // Silently fail — language selection just won't show options
    }
  }

  Future<void> _loadLibraryItems() async {
    try {
      if (widget.source == 'sonarr') {
        final series = await widget.sonarrService.getSeries();
        if (mounted) setState(() => _seriesLibrary = series);
      } else {
        final movies = await widget.radarrService.getMovies();
        if (mounted) setState(() => _movieLibrary = movies);
      }
    } catch (e) {
      // Silently fail — search results just won't appear
    }
  }

  Future<void> _loadEpisodesForSeason(int seasonNumber) async {
    if (_selectedSeries == null) return;
    setState(() => _isLoadingEpisodes = true);

    try {
      final allEpisodes = await widget.sonarrService.getEpisodesBySeriesId(
        _selectedSeries!.id!,
      );
      final seasonEpisodes =
          allEpisodes.where((ep) => ep.seasonNumber == seasonNumber).toList()
            ..sort(
              (a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0),
            );

      if (mounted) {
        setState(() {
          _availableEpisodes = seasonEpisodes;
          _isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  void _searchItems(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _seriesResults = [];
        _movieResults = [];
      });
      return;
    }
    final lower = query.toLowerCase();
    if (widget.source == 'sonarr') {
      setState(() {
        _seriesResults = _seriesLibrary
            .where((s) => (s.title ?? '').toLowerCase().contains(lower))
            .take(20)
            .toList();
      });
    } else {
      setState(() {
        _movieResults = _movieLibrary
            .where((m) => (m.title ?? '').toLowerCase().contains(lower))
            .take(20)
            .toList();
      });
    }
  }

  void _selectSeriesItem(SeriesResource series) {
    setState(() {
      _seriesResults = [];
      _selectedSeries = series;
      _selectedSeasonNumber = null;
      _selectedEpisodeIds.clear();
      _availableEpisodes = [];
    });
  }

  void _selectMovieItem(MovieResource movie) {
    setState(() {
      _movieResults = [];
      _selectedMovie = movie;
    });
  }

  void _applyChanges() {
    final selectedLanguages = _availableLanguages
        .where((l) => l.id != null && _selectedLanguageIds.contains(l.id))
        .map((l) => Language(id: l.id, name: l.name))
        .toList();

    final updatedQuality = _selectedQuality != null
        ? QualityModel(quality: _selectedQuality)
        : widget.candidate.quality;

    switch (widget.candidate) {
      case _SonarrCandidate(:final data):
        final selectedEpisodes = _availableEpisodes
            .where((ep) => ep.id != null && _selectedEpisodeIds.contains(ep.id))
            .toList();
        final updated = data.copyWith(
          series: _selectedSeries,
          seasonNumber: _selectedSeasonNumber,
          episodes: selectedEpisodes,
          quality: updatedQuality,
          languages: selectedLanguages,
          releaseGroup: _releaseGroup,
        );
        Navigator.pop(context, _SonarrCandidate(updated));
      case _RadarrCandidate(:final data):
        final updated = data.copyWith(
          movie: _selectedMovie,
          quality: updatedQuality,
          languages: selectedLanguages,
          releaseGroup: _releaseGroup,
        );
        Navigator.pop(context, _RadarrCandidate(updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItemTitle = widget.source == 'sonarr'
        ? _selectedSeries?.title
        : _selectedMovie?.title;

    return AlertDialog(
      title: const Text('Edit Import Match'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.candidate.relativePath ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
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
                  hintText:
                      'Search ${widget.source == 'sonarr' ? 'series' : 'movie'}...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _searchItems,
              ),

              if ((widget.source == 'sonarr' ? _seriesResults : _movieResults)
                  .isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.source == 'sonarr'
                        ? _seriesResults.length
                        : _movieResults.length,
                    itemBuilder: (context, index) {
                      if (widget.source == 'sonarr') {
                        final s = _seriesResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            s.title ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: s.year != null
                              ? Text(
                                  '${s.year}',
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () => _selectSeriesItem(s),
                        );
                      } else {
                        final m = _movieResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            m.title ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: m.year != null
                              ? Text(
                                  '${m.year}',
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () => _selectMovieItem(m),
                        );
                      }
                    },
                  ),
                ),

              if (selectedItemTitle != null) ...[
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
                          selectedItemTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Season selector (Sonarr only)
              if (widget.source == 'sonarr' && _selectedSeries != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Season',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: _selectedSeasonNumber,
                  hint: const Text('Select season'),
                  items: (_selectedSeries!.seasons ?? [])
                      .where(
                        (s) => s.seasonNumber != null && s.seasonNumber != 0,
                      )
                      .map(
                        (season) => DropdownMenuItem<int>(
                          value: season.seasonNumber,
                          child: Text('Season ${season.seasonNumber}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSeasonNumber = value;
                      _selectedEpisodeIds.clear();
                      _availableEpisodes = [];
                    });
                    if (value != null) {
                      unawaited(_loadEpisodesForSeason(value));
                    }
                  },
                ),
              ],

              // Episode selector (Sonarr only)
              if (widget.source == 'sonarr' &&
                  _selectedSeries != null &&
                  _selectedSeasonNumber != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Episodes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                              final episodeId = episode.id!;
                              final episodeNumber = episode.episodeNumber;
                              final title = episode.title ?? 'TBA';

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
              const Text(
                'Quality',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoadingQualities)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  initialValue: _selectedQuality?.id,
                  hint: const Text('Select quality'),
                  items: _availableQualities
                      .map(
                        (q) => DropdownMenuItem<int>(
                          value: q.id,
                          child: Text(q.name ?? 'Unknown'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedQuality = _availableQualities.firstWhere(
                        (q) => q.id == value,
                        orElse: () => const Quality(),
                      );
                    });
                  },
                ),

              // Release group
              const SizedBox(height: 16),
              const Text(
                'Release Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Enter release group',
                ),
                controller: _releaseGroupController,
                onChanged: (value) => _releaseGroup = value,
              ),

              // Languages
              const SizedBox(height: 16),
              const Text(
                'Languages',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_availableLanguages.isEmpty)
                Text(
                  'Loading languages...',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _availableLanguages.map((lang) {
                    final id = lang.id!;
                    return FilterChip(
                      label: Text(lang.name ?? 'Unknown'),
                      selected: _selectedLanguageIds.contains(id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedLanguageIds.add(id);
                          } else {
                            _selectedLanguageIds.remove(id);
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
        FilledButton(onPressed: _applyChanges, child: const Text('Apply')),
      ],
    );
  }
}
