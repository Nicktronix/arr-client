import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';
import 'package:arr_client/models/shared/tracked_download.dart';

abstract interface class ArrQueueItem {
  int? get id;
  String? get title;
  String? get status;
  String? get trackedDownloadStatus;
  String? get trackedDownloadState;
  List<TrackedDownloadStatusMessage>? get statusMessages;
  String? get errorMessage;
  String? get downloadId;
  String? get protocol;
  String? get downloadClient;
  String? get indexer;
  double? get size;
  double? get sizeleft;
  String? get timeleft;
  QualityModel? get quality;
  List<Language>? get languages;
  List<CustomFormatResource>? get customFormats;
  int? get customFormatScore;
  String? get added;
  bool get isSonarr;
}
