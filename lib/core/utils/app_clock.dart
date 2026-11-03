import 'package:flutter/foundation.dart';

class AppClock {
  AppClock._();

  static DateTime Function()? _customNow;
  static Duration? _customTimeZoneOffset;

  static DateTime now() {
    if (_customNow != null) {
      final dt = _customNow!();
      if (_customTimeZoneOffset != null) {
        return dt.toUtc().add(_customTimeZoneOffset!);
      }
      return dt;
    }
    return DateTime.now();
  }

  static DateTime nowUtc() {
    if (_customNow != null) {
      return _customNow!().toUtc();
    }
    return DateTime.now().toUtc();
  }

  static String nowUtcIso() => nowUtc().toIso8601String();

  static Duration get currentOffset {
    if (_customTimeZoneOffset != null) {
      return _customTimeZoneOffset!;
    }
    return DateTime.now().timeZoneOffset;
  }

  static String toLocalDateString(DateTime dt, {Duration? timeZoneOffset}) {
    final offset = timeZoneOffset ?? (_customTimeZoneOffset ?? (dt.isUtc ? DateTime.now().timeZoneOffset : null));
    final local = offset != null
        ? dt.toUtc().add(offset)
        : (dt.isUtc ? dt.toLocal() : dt);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String todayLocalDateString({Duration? timeZoneOffset}) {
    return toLocalDateString(nowUtc(), timeZoneOffset: timeZoneOffset ?? currentOffset);
  }

  @visibleForTesting
  static void setMockClock({DateTime? now, Duration? timeZoneOffset}) {
    if (now != null) {
      _customNow = () => now;
    } else {
      _customNow = null;
    }
    _customTimeZoneOffset = timeZoneOffset;
  }

  @visibleForTesting
  static void reset() {
    _customNow = null;
    _customTimeZoneOffset = null;
  }
}
