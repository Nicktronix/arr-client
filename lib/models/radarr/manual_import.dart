import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/sonarr/manual_import.dart' show ImportRejection;
import 'package:arr_client/models/radarr/movie.dart';

part 'manual_import.freezed.dart';
part 'manual_import.g.dart';

@freezed
abstract class RadarrManualImport with _$RadarrManualImport {
  const factory RadarrManualImport({
    int? id,
    String? path,
    String? relativePath,
    String? folderName,
    String? name,
    int? size,
    MovieResource? movie,
    int? movieFileId,
    String? releaseGroup,
    QualityModel? quality,
    List<Language>? languages,
    int? qualityWeight,
    String? downloadId,
    int? customFormatScore,
    List<ImportRejection>? rejections,
    List<CustomFormatResource>? customFormats,
  }) = _RadarrManualImport;

  factory RadarrManualImport.fromJson(Map<String, dynamic> json) =>
      _$RadarrManualImportFromJson(json);
}
