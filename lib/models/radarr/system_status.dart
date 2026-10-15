import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_status.freezed.dart';
part 'system_status.g.dart';

@freezed
abstract class RadarrSystemStatus with _$RadarrSystemStatus {
  const factory RadarrSystemStatus({
    String? appName,
    String? instanceName,
    String? version,
    String? buildTime,
    bool? isDebug,
    bool? isProduction,
    bool? isLinux,
    bool? isOsx,
    bool? isWindows,
    bool? isDocker,
    String? branch,
    String? authentication,
    String? urlBase,
    String? runtimeVersion,
    String? runtimeName,
    String? startTime,
    String? packageVersion,
    String? databaseVersion,
    String? databaseType,
  }) = _RadarrSystemStatus;

  factory RadarrSystemStatus.fromJson(Map<String, dynamic> json) =>
      _$RadarrSystemStatusFromJson(json);
}
