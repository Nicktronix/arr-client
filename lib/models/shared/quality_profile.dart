import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';

part 'quality_profile.freezed.dart';
part 'quality_profile.g.dart';

@freezed
abstract class QualityProfileItem with _$QualityProfileItem {
  const factory QualityProfileItem({
    int? id,
    String? name,
    Quality? quality,
    List<QualityProfileItem>? items,
    bool? allowed,
  }) = _QualityProfileItem;

  factory QualityProfileItem.fromJson(Map<String, dynamic> json) =>
      _$QualityProfileItemFromJson(json);
}

@freezed
abstract class QualityProfileResource with _$QualityProfileResource {
  const factory QualityProfileResource({
    int? id,
    String? name,
    bool? upgradeAllowed,
    int? cutoff,
    List<QualityProfileItem>? items,
    int? minFormatScore,
    int? cutoffFormatScore,
    int? minUpgradeFormatScore,
    LanguageResource? language,
  }) = _QualityProfileResource;

  factory QualityProfileResource.fromJson(Map<String, dynamic> json) =>
      _$QualityProfileResourceFromJson(json);
}
