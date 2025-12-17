class ServiceInstance {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String? basicAuthUsername;
  final String? basicAuthPassword;

  ServiceInstance({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    this.basicAuthUsername,
    this.basicAuthPassword,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'basicAuthUsername': basicAuthUsername,
    'basicAuthPassword': basicAuthPassword,
  };

  factory ServiceInstance.fromJson(Map<String, dynamic> json) {
    return ServiceInstance(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      basicAuthUsername: json['basicAuthUsername'] as String?,
      basicAuthPassword: json['basicAuthPassword'] as String?,
    );
  }

  ServiceInstance copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? basicAuthUsername,
    String? basicAuthPassword,
  }) {
    return ServiceInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      basicAuthUsername: basicAuthUsername ?? this.basicAuthUsername,
      basicAuthPassword: basicAuthPassword ?? this.basicAuthPassword,
    );
  }
}
