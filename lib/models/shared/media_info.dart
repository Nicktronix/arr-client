import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_info.freezed.dart';
part 'media_info.g.dart';

@freezed
abstract class MediaInfoResource with _$MediaInfoResource {
  const factory MediaInfoResource({
    int? id,
    int? audioBitrate,
    double? audioChannels,
    String? audioCodec,
    String? audioLanguages,
    int? audioStreamCount,
    int? videoBitDepth,
    int? videoBitrate,
    String? videoCodec,
    double? videoFps,
    String? videoDynamicRange,
    String? videoDynamicRangeType,
    String? resolution,
    String? runTime,
    String? scanType,
    String? subtitles,
  }) = _MediaInfoResource;

  factory MediaInfoResource.fromJson(Map<String, dynamic> json) =>
      _$MediaInfoResourceFromJson(json);
}
