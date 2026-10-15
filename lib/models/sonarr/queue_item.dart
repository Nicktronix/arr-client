import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/arr_queue_item.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/shared/tracked_download.dart';
import 'package:arr_client/models/sonarr/series.dart';

part 'queue_item.freezed.dart';
part 'queue_item.g.dart';

@freezed
abstract class SonarrQueueItem with _$SonarrQueueItem implements ArrQueueItem {
  const SonarrQueueItem._();

  // ignore: sort_unnamed_constructors_first, freezed requires private constructor before factory for custom getters
  const factory SonarrQueueItem({
    int? id,
    int? seriesId,
    int? episodeId,
    int? seasonNumber,
    SeriesResource? series,
    EpisodeResource? episode,
    List<Language>? languages,
    QualityModel? quality,
    int? customFormatScore,
    double? size,
    String? title,
    String? estimatedCompletionTime,
    String? added,
    String? status,
    String? trackedDownloadStatus,
    String? trackedDownloadState,
    List<TrackedDownloadStatusMessage>? statusMessages,
    String? errorMessage,
    String? downloadId,
    String? protocol,
    String? downloadClient,
    String? indexer,
    String? outputPath,
    bool? episodeHasFile,
    double? sizeleft,
    String? timeleft,
    List<CustomFormatResource>? customFormats,
  }) = _SonarrQueueItem;

  factory SonarrQueueItem.fromJson(Map<String, dynamic> json) =>
      _$SonarrQueueItemFromJson(json);

  @override
  bool get isSonarr => true;
}
