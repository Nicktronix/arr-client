import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/arr_release.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/sonarr/release_episode.dart';

part 'release.freezed.dart';
part 'release.g.dart';

@freezed
abstract class SonarrRelease with _$SonarrRelease implements ArrRelease {
  const factory SonarrRelease({
    int? id,
    String? guid,
    QualityModel? quality,
    int? qualityWeight,
    int? age,
    double? ageHours,
    double? ageMinutes,
    int? size,
    int? indexerId,
    String? indexer,
    String? releaseGroup,
    String? title,
    bool? fullSeason,
    int? seasonNumber,
    List<Language>? languages,
    String? airDate,
    String? seriesTitle,
    List<int>? episodeNumbers,
    int? mappedSeasonNumber,
    List<int>? mappedEpisodeNumbers,
    int? mappedSeriesId,
    bool? approved,
    bool? temporarilyRejected,
    bool? rejected,
    int? tvdbId,
    List<String>? rejections,
    String? publishDate,
    String? downloadUrl,
    String? infoUrl,
    bool? episodeRequested,
    bool? downloadAllowed,
    int? releaseWeight,
    int? customFormatScore,
    String? magnetUrl,
    String? infoHash,
    int? seeders,
    int? leechers,
    String? protocol,
    bool? isDaily,
    bool? isAbsoluteNumbering,
    bool? special,
    int? seriesId,
    int? episodeId,
    List<int>? episodeIds,
    int? downloadClientId,
    String? downloadClient,
    bool? shouldOverride,
    int? mappedMovieId,
    List<ReleaseEpisodeResource>? mappedEpisodeInfo,
    List<CustomFormatResource>? customFormats,
  }) = _SonarrRelease;

  factory SonarrRelease.fromJson(Map<String, dynamic> json) =>
      _$SonarrReleaseFromJson(json);
}
