import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';

abstract interface class ArrHistoryRecord {
  int? get id;
  String? get sourceTitle;
  List<Language>? get languages;
  QualityModel? get quality;
  int? get customFormatScore;
  bool? get qualityCutoffNotMet;
  String? get date;
  String? get downloadId;
  String? get eventType;
  Map<String, dynamic>? get data;
}
