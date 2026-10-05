import 'package:flutter_riverpod/flutter_riverpod.dart';
// package_info_plus is already built into the app (sentry_flutter depends on
// it), so reading the version here adds no new package. It is not listed in
// pubspec.yaml yet; list it there and drop this ignore the next time
// pubspec.lock is regenerated on the pinned Flutter version.
// ignore: depend_on_referenced_packages
import 'package:package_info_plus/package_info_plus.dart';

/// The installed build's version and build number, for example `1.0.0+34`,
/// as the store built it (Codemagic sets the build number at build time, so
/// it cannot be a constant in the code). Null when the platform can't say.
Future<String?> readAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return null;
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (_) {
    return null;
  }
}

final appVersionProvider = FutureProvider<String?>((ref) => readAppVersion());
