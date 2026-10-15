import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_cover.freezed.dart';
part 'media_cover.g.dart';

@freezed
abstract class MediaCover with _$MediaCover {
  const factory MediaCover({
    String? coverType,
    String? url,
    String? remoteUrl,
  }) = _MediaCover;

  factory MediaCover.fromJson(Map<String, dynamic> json) =>
      _$MediaCoverFromJson(json);
}
