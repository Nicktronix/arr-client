import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_format.freezed.dart';
part 'custom_format.g.dart';

@freezed
abstract class CustomFormatResource with _$CustomFormatResource {
  const factory CustomFormatResource({
    int? id,
    String? name,
    bool? includeCustomFormatWhenRenaming,
  }) = _CustomFormatResource;

  factory CustomFormatResource.fromJson(Map<String, dynamic> json) =>
      _$CustomFormatResourceFromJson(json);
}
