import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arr_client/models/radarr/movie.dart';
import 'package:arr_client/models/shared/media_cover.dart';
import 'package:arr_client/models/shared/quality_profile.dart';
import 'package:arr_client/models/shared/root_folder.dart';
import 'package:arr_client/models/shared/tag.dart';
import 'package:arr_client/services/radarr_service.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/config/app_config.dart';
import 'package:arr_client/utils/error_formatter.dart';
import 'package:arr_client/di/injection.dart';

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key});

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final RadarrService _radarr = getIt<RadarrService>();
  final TextEditingController _searchController = TextEditingController();

  List<MovieResource> _searchResults = [];
  List<MovieResource> _existingMovies = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;
  String? _instanceIdOnLoad;

  @override
  void initState() {
    super.initState();
    _instanceIdOnLoad = AppConfig.activeRadarrInstanceId;
    unawaited(_loadExistingMovies());
    getIt<AppStateManager>().addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    getIt<AppStateManager>().removeListener(_onInstanceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onInstanceChanged() {
    if (mounted && AppConfig.activeRadarrInstanceId != _instanceIdOnLoad) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instance changed - returning to list'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadExistingMovies() async {
    try {
      final movies = await _radarr.getMovies();
      setState(() {
        _existingMovies = movies;
      });
    } catch (e) {
      // Non-critical — just won't show "already added" status
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
      final results = await _radarr.searchMovies(query);
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

  bool _isMovieInLibrary(MovieResource movie) {
    final tmdbId = movie.tmdbId;
    if (tmdbId == null) return false;
    return _existingMovies.any((m) => m.tmdbId == tmdbId);
  }

  String? _posterUrl(List<MediaCover>? images) {
    if (images == null) return null;
    for (final image in images) {
      if (image.coverType == 'poster') return image.remoteUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Movies')),
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
          hintText: 'Search for movies...',
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
              'Search for Movies',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a movie name to search',
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
            Icon(Icons.movie_outlined, size: 80, color: Colors.grey[400]),
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

  Widget _buildSearchResultCard(MovieResource movie) {
    final title = movie.title ?? 'Unknown Title';
    final year = movie.year ?? 0;
    final overview = movie.overview;
    final inLibrary = _isMovieInLibrary(movie);
    final status = movie.status ?? 'unknown';
    final runtime = movie.runtime ?? 0;
    final posterUrl = _posterUrl(movie.images);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (inLibrary) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This movie is already in your library'),
              ),
            );
          } else {
            unawaited(_showAddMovieDialog(movie));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            child: const Icon(Icons.movie, size: 40),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.movie, size: 40),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (year > 0) ...[
                      Text(
                        runtime > 0 ? '$year • ${runtime}min' : '$year',
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
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
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

  Future<void> _showAddMovieDialog(MovieResource movie) async {
    List<QualityProfileResource>? qualityProfiles;
    List<RootFolderResource>? rootFolders;
    List<TagResource>? tags;

    try {
      final results = await Future.wait([
        _radarr.getQualityProfiles(),
        _radarr.getRootFolders(),
        _radarr.getTags(),
      ]);
      qualityProfiles = results[0] as List<QualityProfileResource>;
      rootFolders = results[1] as List<RootFolderResource>;
      tags = results[2] as List<TagResource>;
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
              'Please configure quality profiles and root folders in Radarr',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    var selectedQualityProfile = qualityProfiles.first.id!;
    var selectedRootFolder = rootFolders.first.path!;
    final selectedTags = <int>[];
    var selectedMinimumAvailability = 'released';
    var searchForMovie = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add ${movie.title}'),
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
                      value: profile.id,
                      child: Text(profile.name ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedQualityProfile = value);
                    }
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
                      value: folder.path,
                      child: Text(folder.path ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRootFolder = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Minimum Availability',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedMinimumAvailability,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'announced',
                      child: Text('Announced'),
                    ),
                    DropdownMenuItem(
                      value: 'inCinemas',
                      child: Text('In Cinemas'),
                    ),
                    DropdownMenuItem(
                      value: 'released',
                      child: Text('Released'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedMinimumAvailability = value);
                    }
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
                      final isSelected = selectedTags.contains(tag.id);
                      return FilterChip(
                        label: Text(tag.label ?? ''),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected && tag.id != null) {
                              selectedTags.add(tag.id!);
                            } else {
                              selectedTags.remove(tag.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                CheckboxListTile(
                  value: searchForMovie,
                  onChanged: (value) {
                    setDialogState(() => searchForMovie = value ?? false);
                  },
                  title: const Text('Search for Movie'),
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
                await _addMovieToLibrary(
                  movie,
                  selectedQualityProfile,
                  selectedRootFolder,
                  selectedTags,
                  selectedMinimumAvailability,
                  searchForMovie,
                );
              },
              child: const Text('Add Movie'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMovieToLibrary(
    MovieResource movie,
    int qualityProfileId,
    String rootFolderPath,
    List<int> tags,
    String minimumAvailability,
    bool searchForMovie,
  ) async {
    try {
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
                Text('Adding movie...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final movieData = <String, dynamic>{
        'title': movie.title,
        'tmdbId': movie.tmdbId,
        'qualityProfileId': qualityProfileId,
        'rootFolderPath': rootFolderPath,
        'monitored': true,
        'minimumAvailability': minimumAvailability,
        'tags': tags,
        'addOptions': {'searchForMovie': searchForMovie},
        'titleSlug': movie.titleSlug,
        'images': movie.images?.map((i) => i.toJson()).toList() ?? [],
        'year': movie.year,
      };

      await _radarr.addMovie(movieData);
      await _loadExistingMovies();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${movie.title} added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding movie: ${ErrorFormatter.format(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'released':
        return 'Released';
      case 'incinemas':
        return 'In Cinemas';
      case 'announced':
        return 'Announced';
      default:
        return status.substring(0, 1).toUpperCase() +
            status.substring(1).toLowerCase();
    }
  }
}
