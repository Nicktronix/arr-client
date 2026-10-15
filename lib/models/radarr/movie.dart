import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/radarr/ratings.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/media_cover.dart';
import 'package:arr_client/models/shared/media_info.dart';
import 'package:arr_client/models/shared/quality.dart';

part 'movie.freezed.dart';
part 'movie.g.dart';

@freezed
abstract class MovieStatisticsResource with _$MovieStatisticsResource {
  const factory MovieStatisticsResource({
    int? movieFileCount,
    int? sizeOnDisk,
    List<String>? releaseGroups,
  }) = _MovieStatisticsResource;

  factory MovieStatisticsResource.fromJson(Map<String, dynamic> json) =>
      _$MovieStatisticsResourceFromJson(json);
}

@freezed
abstract class MovieFileResource with _$MovieFileResource {
  const factory MovieFileResource({
    int? id,
    int? movieId,
    String? relativePath,
    String? path,
    int? size,
    String? dateAdded,
    String? sceneName,
    String? releaseGroup,
    String? edition,
    List<Language>? languages,
    QualityModel? quality,
    int? customFormatScore,
    bool? qualityCutoffNotMet,
    List<CustomFormatResource>? customFormats,
    MediaInfoResource? mediaInfo,
  }) = _MovieFileResource;

  factory MovieFileResource.fromJson(Map<String, dynamic> json) =>
      _$MovieFileResourceFromJson(json);
}

@freezed
abstract class MovieResource with _$MovieResource {
  const factory MovieResource({
    int? id,
    String? title,
    String? originalTitle,
    Language? originalLanguage,
    String? sortTitle,
    int? sizeOnDisk,
    String? status,
    String? overview,
    String? inCinemas,
    String? physicalRelease,
    String? digitalRelease,
    List<MediaCover>? images,
    String? website,
    String? remotePoster,
    int? year,
    String? studio,
    String? path,
    int? qualityProfileId,
    bool? hasFile,
    int? movieFileId,
    bool? monitored,
    String? minimumAvailability,
    bool? isAvailable,
    String? folderName,
    int? runtime,
    String? cleanTitle,
    String? imdbId,
    int? tmdbId,
    String? titleSlug,
    String? rootFolderPath,
    String? certification,
    List<String>? genres,
    List<int>? tags,
    String? added,
    double? popularity,
    String? lastSearchTime,
    MovieFileResource? movieFile,
    MovieStatisticsResource? statistics,
    RadarrRatings? ratings,
  }) = _MovieResource;

  factory MovieResource.fromJson(Map<String, dynamic> json) =>
      _$MovieResourceFromJson(json);
}
