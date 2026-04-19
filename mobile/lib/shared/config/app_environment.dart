class AppEnvironment {
  const AppEnvironment({
    required this.appName,
    required this.flavor,
    required this.apiBaseUrl,
  });

  factory AppEnvironment.fromDartDefine() {
    return const AppEnvironment(
      appName: String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'Production Chat',
      ),
      flavor: String.fromEnvironment('APP_FLAVOR', defaultValue: 'development'),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
    );
  }

  final String appName;
  final String flavor;
  final String apiBaseUrl;
}
