import 'package:freezed_annotation/freezed_annotation.dart';

part 'disk_space.freezed.dart';
part 'disk_space.g.dart';

@freezed
abstract class DiskSpaceResource with _$DiskSpaceResource {
  const factory DiskSpaceResource({
    int? id,
    String? path,
    String? label,
    int? freeSpace,
    int? totalSpace,
  }) = _DiskSpaceResource;

  factory DiskSpaceResource.fromJson(Map<String, dynamic> json) =>
      _$DiskSpaceResourceFromJson(json);
}
