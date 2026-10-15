import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/arr_release.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';

part 'release.freezed.dart';
part 'release.g.dart';

@freezed
abstract class RadarrRelease with _$RadarrRelease implements ArrRelease {
  const factory RadarrRelease({
    int? id,
    String? guid,
    QualityModel? quality,
    int? customFormatScore,
    int? qualityWeight,
    int? age,
    double? ageHours,
    double? ageMinutes,
    int? size,
    int? indexerId,
    String? indexer,
    String? releaseGroup,
    String? title,
    List<String>? movieTitles,
    List<Language>? languages,
    int? mappedMovieId,
    bool? approved,
    bool? temporarilyRejected,
    bool? rejected,
    int? tmdbId,
    int? imdbId,
    List<String>? rejections,
    String? publishDate,
    String? downloadUrl,
    String? infoUrl,
    bool? movieRequested,
    bool? downloadAllowed,
    int? releaseWeight,
    String? edition,
    String? magnetUrl,
    String? infoHash,
    int? seeders,
    int? leechers,
    String? protocol,
    int? movieId,
    int? downloadClientId,
    String? downloadClient,
    bool? shouldOverride,
    List<CustomFormatResource>? customFormats,
  }) = _RadarrRelease;

  factory RadarrRelease.fromJson(Map<String, dynamic> json) =>
      _$RadarrReleaseFromJson(json);
}
