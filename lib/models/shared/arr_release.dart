import 'package:arr_client/models/shared/custom_format.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality.dart';

abstract interface class ArrRelease {
  String? get guid;
  String? get title;
  QualityModel? get quality;
  int? get qualityWeight;
  int? get age;
  double? get ageHours;
  double? get ageMinutes;
  int? get size;
  int? get indexerId;
  String? get indexer;
  String? get releaseGroup;
  int? get seeders;
  int? get leechers;
  bool? get approved;
  bool? get temporarilyRejected;
  bool? get rejected;
  List<String>? get rejections;
  String? get publishDate;
  String? get downloadUrl;
  String? get infoUrl;
  bool? get downloadAllowed;
  int? get releaseWeight;
  int? get customFormatScore;
  String? get magnetUrl;
  String? get infoHash;
  String? get protocol;
  int? get downloadClientId;
  String? get downloadClient;
  bool? get shouldOverride;
  List<Language>? get languages;
  List<CustomFormatResource>? get customFormats;
  // Present on both Sonarr and Radarr release responses
  int? get mappedMovieId;
}
