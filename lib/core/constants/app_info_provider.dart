import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  const AppInfo({
    this.appName = 'HI Chinese',
    this.packageName = 'com.hichinese.hi_chinese',
    this.version = '1.0.9',
    this.buildNumber = '10',
  });

  String get fullVersionString => 'v$version+$buildNumber';
}

final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(
      appName: info.appName.isNotEmpty ? info.appName : 'HI Chinese',
      packageName: info.packageName.isNotEmpty ? info.packageName : 'com.hichinese.hi_chinese',
      version: info.version.isNotEmpty ? info.version : '1.0.9',
      buildNumber: info.buildNumber.isNotEmpty ? info.buildNumber : '10',
    );
  } catch (_) {
    return const AppInfo();
  }
});
