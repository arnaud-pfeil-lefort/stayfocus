import 'dart:io';

import 'usage/android.dart';
import 'usage/ios.dart';
import 'usage/source.dart';
import 'usage/unsupported.dart';

UsageSource createUsageSource() {
  if (Platform.isAndroid) {
    return AndroidUsageSource();
  }
  if (Platform.isIOS) {
    return IosUsageSource();
  }
  return UnsupportedUsageSource();
}
