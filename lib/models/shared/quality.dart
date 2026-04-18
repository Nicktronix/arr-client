import 'package:freezed_annotation/freezed_annotation.dart';

part 'quality.freezed.dart';
part 'quality.g.dart';

@freezed
abstract class Quality with _$Quality {
  const factory Quality({
    int? id,
    String? name,
    String? source,
    int? resolution,
  }) = _Quality;

  factory Quality.fromJson(Map<String, dynamic> json) =>
      _$QualityFromJson(json);
}

@freezed
abstract class Revision with _$Revision {
  const factory Revision({
    int? version,
    int? real,
    bool? isRepack,
  }) = _Revision;

  factory Revision.fromJson(Map<String, dynamic> json) =>
      _$RevisionFromJson(json);
}

@freezed
abstract class QualityModel with _$QualityModel {
  const factory QualityModel({
    Quality? quality,
    Revision? revision,
  }) = _QualityModel;

  factory QualityModel.fromJson(Map<String, dynamic> json) =>
      _$QualityModelFromJson(json);
}
