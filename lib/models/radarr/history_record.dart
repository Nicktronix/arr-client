import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/arr_history_record.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/radarr/movie.dart';

part 'history_record.freezed.dart';
part 'history_record.g.dart';

@freezed
abstract class RadarrHistoryRecord
    with _$RadarrHistoryRecord
    implements ArrHistoryRecord {
  const factory RadarrHistoryRecord({
    int? id,
    int? movieId,
    String? sourceTitle,
    List<Language>? languages,
    QualityModel? quality,
    List<CustomFormatResource>? customFormats,
    int? customFormatScore,
    bool? qualityCutoffNotMet,
    String? date,
    String? downloadId,
    String? eventType,
    Map<String, dynamic>? data,
    MovieResource? movie,
  }) = _RadarrHistoryRecord;

  factory RadarrHistoryRecord.fromJson(Map<String, dynamic> json) =>
      _$RadarrHistoryRecordFromJson(json);
}
