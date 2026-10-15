import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_instance.freezed.dart';
part 'service_instance.g.dart';

@freezed
abstract class ServiceInstance with _$ServiceInstance {
  const factory ServiceInstance({
    required String id,
    required String name,
    required String baseUrl,
    required String apiKey,
    String? basicAuthUsername,
    String? basicAuthPassword,
  }) = _ServiceInstance;

  factory ServiceInstance.fromJson(Map<String, dynamic> json) =>
      _$ServiceInstanceFromJson(json);
}
