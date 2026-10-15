import 'package:freezed_annotation/freezed_annotation.dart';

part 'root_folder.freezed.dart';
part 'root_folder.g.dart';

@freezed
abstract class RootFolderResource with _$RootFolderResource {
  const factory RootFolderResource({
    int? id,
    String? path,
    bool? accessible,
    int? freeSpace,
  }) = _RootFolderResource;

  factory RootFolderResource.fromJson(Map<String, dynamic> json) =>
      _$RootFolderResourceFromJson(json);
}
