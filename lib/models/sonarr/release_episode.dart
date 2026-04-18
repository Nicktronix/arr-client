import 'package:freezed_annotation/freezed_annotation.dart';

part 'release_episode.freezed.dart';
part 'release_episode.g.dart';

@freezed
abstract class ReleaseEpisodeResource with _$ReleaseEpisodeResource {
  const factory ReleaseEpisodeResource({
    int? id,
    int? seasonNumber,
    int? episodeNumber,
    int? absoluteEpisodeNumber,
    String? title,
  }) = _ReleaseEpisodeResource;

  factory ReleaseEpisodeResource.fromJson(Map<String, dynamic> json) =>
      _$ReleaseEpisodeResourceFromJson(json);
}
