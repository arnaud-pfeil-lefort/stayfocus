import 'dart:io';

import 'usage/android.dart';
import 'usage/source.dart';
import 'usage/unsupported.dart';

UsageSource createUsageSource() {
  if (Platform.isAndroid) {
    return AndroidUsageSource();
  }
  return UnsupportedUsageSource();
}
