import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/sonarr/series.dart';

part 'manual_import.freezed.dart';
part 'manual_import.g.dart';

@freezed
abstract class ImportRejection with _$ImportRejection {
  const factory ImportRejection({
    String? reason,
    String? type,
  }) = _ImportRejection;

  factory ImportRejection.fromJson(Map<String, dynamic> json) =>
      _$ImportRejectionFromJson(json);
}

@freezed
abstract class SonarrManualImport with _$SonarrManualImport {
  const factory SonarrManualImport({
    int? id,
    String? path,
    String? relativePath,
    String? folderName,
    String? name,
    int? size,
    SeriesResource? series,
    int? seasonNumber,
    List<EpisodeResource>? episodes,
    int? episodeFileId,
    String? releaseGroup,
    QualityModel? quality,
    List<Language>? languages,
    int? qualityWeight,
    String? downloadId,
    int? customFormatScore,
    List<ImportRejection>? rejections,
    List<CustomFormatResource>? customFormats,
  }) = _SonarrManualImport;

  factory SonarrManualImport.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportFromJson(json);
}
