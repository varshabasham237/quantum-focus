class BlockedApp {
  final String packageName;
  final String appName;

  const BlockedApp({
    required this.packageName,
    required this.appName,
  });

  factory BlockedApp.fromJson(Map<String, dynamic> json) => BlockedApp(
        packageName: json['package_name'] as String,
        appName: json['app_name'] as String,
      );

  Map<String, dynamic> toJson() => {
        'package_name': packageName,
        'app_name': appName,
      };
}

class InstalledApp {
  final String packageName;
  final String appName;

  const InstalledApp({required this.packageName, required this.appName});
}
