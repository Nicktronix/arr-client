import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracked_download.freezed.dart';
part 'tracked_download.g.dart';

@freezed
abstract class TrackedDownloadStatusMessage
    with _$TrackedDownloadStatusMessage {
  const factory TrackedDownloadStatusMessage({
    String? title,
    List<String>? messages,
  }) = _TrackedDownloadStatusMessage;

  factory TrackedDownloadStatusMessage.fromJson(Map<String, dynamic> json) =>
      _$TrackedDownloadStatusMessageFromJson(json);
}
