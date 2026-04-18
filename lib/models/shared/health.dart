import 'package:freezed_annotation/freezed_annotation.dart';

part 'health.freezed.dart';
part 'health.g.dart';

@freezed
abstract class HealthResource with _$HealthResource {
  const factory HealthResource({
    int? id,
    String? source,
    String? type,
    String? message,
    String? wikiUrl,
  }) = _HealthResource;

  factory HealthResource.fromJson(Map<String, dynamic> json) =>
      _$HealthResourceFromJson(json);
}
