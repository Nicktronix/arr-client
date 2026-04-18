import 'package:freezed_annotation/freezed_annotation.dart';

part 'ratings.freezed.dart';
part 'ratings.g.dart';

@freezed
abstract class SonarrRatings with _$SonarrRatings {
  const factory SonarrRatings({
    int? votes,
    double? value,
  }) = _SonarrRatings;

  factory SonarrRatings.fromJson(Map<String, dynamic> json) =>
      _$SonarrRatingsFromJson(json);
}
