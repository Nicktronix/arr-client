import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/arr_queue_item.dart';
import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/shared/tracked_download.dart';
import 'package:arr_client/models/radarr/movie.dart';

part 'queue_item.freezed.dart';
part 'queue_item.g.dart';

@freezed
abstract class RadarrQueueItem with _$RadarrQueueItem implements ArrQueueItem {
  const RadarrQueueItem._();

  // ignore: sort_unnamed_constructors_first, freezed requires private constructor before factory for custom getters
  const factory RadarrQueueItem({
    int? id,
    int? movieId,
    MovieResource? movie,
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
    double? sizeleft,
    String? timeleft,
    List<CustomFormatResource>? customFormats,
  }) = _RadarrQueueItem;

  factory RadarrQueueItem.fromJson(Map<String, dynamic> json) =>
      _$RadarrQueueItemFromJson(json);

  @override
  bool get isSonarr => false;
}
