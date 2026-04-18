import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/media_cover.dart';
import 'package:arr_client/models/shared/media_info.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/sonarr/ratings.dart';

part 'series.freezed.dart';
part 'series.g.dart';

@freezed
abstract class SeasonStatistics with _$SeasonStatistics {
  const factory SeasonStatistics({
    String? nextAiring,
    String? previousAiring,
    int? episodeFileCount,
    int? episodeCount,
    int? totalEpisodeCount,
    int? sizeOnDisk,
    double? releaseGroups,
    double? percentOfEpisodes,
  }) = _SeasonStatistics;

  factory SeasonStatistics.fromJson(Map<String, dynamic> json) =>
      _$SeasonStatisticsFromJson(json);
}

@freezed
abstract class SeasonResource with _$SeasonResource {
  const factory SeasonResource({
    int? seasonNumber,
    bool? monitored,
    SeasonStatistics? statistics,
    String? images,
  }) = _SeasonResource;

  factory SeasonResource.fromJson(Map<String, dynamic> json) =>
      _$SeasonResourceFromJson(json);
}

@freezed
abstract class SeriesStatisticsResource with _$SeriesStatisticsResource {
  const factory SeriesStatisticsResource({
    int? seasonCount,
    int? episodeFileCount,
    int? episodeCount,
    int? totalEpisodeCount,
    int? sizeOnDisk,
    List<String>? releaseGroups,
    double? percentOfEpisodes,
  }) = _SeriesStatisticsResource;

  factory SeriesStatisticsResource.fromJson(Map<String, dynamic> json) =>
      _$SeriesStatisticsResourceFromJson(json);
}

@freezed
abstract class SeriesResource with _$SeriesResource {
  const factory SeriesResource({
    int? id,
    String? title,
    String? sortTitle,
    String? status,
    bool? ended,
    String? overview,
    String? network,
    String? airTime,
    List<MediaCover>? images,
    Language? originalLanguage,
    String? remotePoster,
    List<SeasonResource>? seasons,
    int? year,
    String? path,
    int? qualityProfileId,
    bool? seasonFolder,
    bool? monitored,
    String? monitorNewItems,
    bool? useSceneNumbering,
    int? runtime,
    int? tvdbId,
    int? tvRageId,
    int? tvMazeId,
    int? tmdbId,
    String? firstAired,
    String? lastAired,
    String? seriesType,
    String? cleanTitle,
    String? imdbId,
    String? titleSlug,
    String? rootFolderPath,
    String? certification,
    List<String>? genres,
    List<int>? tags,
    String? added,
    SeriesStatisticsResource? statistics,
    SonarrRatings? ratings,
  }) = _SeriesResource;

  factory SeriesResource.fromJson(Map<String, dynamic> json) =>
      _$SeriesResourceFromJson(json);
}

@freezed
abstract class EpisodeFileResource with _$EpisodeFileResource {
  const factory EpisodeFileResource({
    int? id,
    int? seriesId,
    int? seasonNumber,
    String? relativePath,
    String? path,
    int? size,
    String? dateAdded,
    String? sceneName,
    String? releaseGroup,
    List<Language>? languages,
    QualityModel? quality,
    int? customFormatScore,
    bool? qualityCutoffNotMet,
    List<CustomFormatResource>? customFormats,
    MediaInfoResource? mediaInfo,
  }) = _EpisodeFileResource;

  factory EpisodeFileResource.fromJson(Map<String, dynamic> json) =>
      _$EpisodeFileResourceFromJson(json);
}

@freezed
abstract class EpisodeResource with _$EpisodeResource {
  const factory EpisodeResource({
    int? id,
    int? seriesId,
    int? tvdbId,
    int? episodeFileId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    String? airDate,
    String? airDateUtc,
    int? runtime,
    String? overview,
    EpisodeFileResource? episodeFile,
    bool? hasFile,
    bool? monitored,
    int? absoluteEpisodeNumber,
    SeriesResource? series,
    List<MediaCover>? images,
  }) = _EpisodeResource;

  factory EpisodeResource.fromJson(Map<String, dynamic> json) =>
      _$EpisodeResourceFromJson(json);
}
