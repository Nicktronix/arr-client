import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_child.freezed.dart';
part 'rating_child.g.dart';

@freezed
abstract class RatingChild with _$RatingChild {
  const factory RatingChild({
    int? votes,
    double? value,
    String? type,
  }) = _RatingChild;

  factory RatingChild.fromJson(Map<String, dynamic> json) =>
      _$RatingChildFromJson(json);
}
