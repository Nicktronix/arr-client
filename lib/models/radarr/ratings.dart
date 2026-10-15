import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/rating_child.dart';

part 'ratings.freezed.dart';
part 'ratings.g.dart';

@freezed
abstract class RadarrRatings with _$RadarrRatings {
  const factory RadarrRatings({
    RatingChild? imdb,
    RatingChild? tmdb,
    RatingChild? metacritic,
    RatingChild? rottenTomatoes,
    RatingChild? trakt,
  }) = _RadarrRatings;

  factory RadarrRatings.fromJson(Map<String, dynamic> json) =>
      _$RadarrRatingsFromJson(json);
}
