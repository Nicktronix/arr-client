import 'package:freezed_annotation/freezed_annotation.dart';

part 'language.freezed.dart';
part 'language.g.dart';

@freezed
abstract class Language with _$Language {
  const factory Language({
    int? id,
    String? name,
  }) = _Language;

  factory Language.fromJson(Map<String, dynamic> json) =>
      _$LanguageFromJson(json);
}

@freezed
abstract class LanguageResource with _$LanguageResource {
  const factory LanguageResource({
    int? id,
    String? name,
    String? nameLower,
  }) = _LanguageResource;

  factory LanguageResource.fromJson(Map<String, dynamic> json) =>
      _$LanguageResourceFromJson(json);
}
