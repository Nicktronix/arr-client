import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/arr_history_record.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/sonarr/series.dart';

part 'history_record.freezed.dart';
part 'history_record.g.dart';

@freezed
abstract class SonarrHistoryRecord
    with _$SonarrHistoryRecord
    implements ArrHistoryRecord {
  const factory SonarrHistoryRecord({
    int? id,
    int? episodeId,
    int? seriesId,
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
    EpisodeResource? episode,
    SeriesResource? series,
  }) = _SonarrHistoryRecord;

  factory SonarrHistoryRecord.fromJson(Map<String, dynamic> json) =>
      _$SonarrHistoryRecordFromJson(json);
}
