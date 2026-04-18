import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag.freezed.dart';
part 'tag.g.dart';

@freezed
abstract class TagResource with _$TagResource {
  const factory TagResource({
    int? id,
    String? label,
  }) = _TagResource;

  factory TagResource.fromJson(Map<String, dynamic> json) =>
      _$TagResourceFromJson(json);
}
