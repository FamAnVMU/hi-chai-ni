import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum AudioPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

class PermissionHelper {
  PermissionHelper._();

  @visibleForTesting
  static AudioPermissionResult? mockPermissionResult;

  @visibleForTesting
  static PermissionStatus? mockPermissionStatus;

  /// Checks the current microphone permission status without prompting.
  static Future<PermissionStatus> checkMicrophoneStatus() async {
    if (mockPermissionStatus != null) {
      return mockPermissionStatus!;
    }
    return await Permission.microphone.status;
  }

  /// Requests microphone permission with contextual user explanation.
  /// Does NOT prompt at app startup. Only invoked on user demand.
  static Future<AudioPermissionResult> requestMicrophoneWithRationale(
    BuildContext context, {
    required String featureName,
  }) async {
    if (mockPermissionResult != null) {
      return mockPermissionResult!;
    }
    final currentStatus = await checkMicrophoneStatus();

    if (currentStatus.isGranted) {
      return AudioPermissionResult.granted;
    }

    if (currentStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermanentlyDeniedDialog(context, featureName);
      }
      return AudioPermissionResult.permanentlyDenied;
    }

    // Show contextual rationale dialog before invoking OS permission dialog
    if (context.mounted) {
      final proceed = await _showRationaleDialog(context, featureName);
      if (!proceed) {
        return AudioPermissionResult.denied;
      }
    }

    // Trigger Android OS permission prompt
    final requestedStatus = await Permission.microphone.request();

    if (requestedStatus.isGranted) {
      return AudioPermissionResult.granted;
    } else if (requestedStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermanentlyDeniedDialog(context, featureName);
      }
      return AudioPermissionResult.permanentlyDenied;
    } else if (requestedStatus.isRestricted) {
      return AudioPermissionResult.restricted;
    } else {
      return AudioPermissionResult.denied;
    }
  }

  /// Explains why the permission is needed before asking the OS.
  static Future<bool> _showRationaleDialog(
    BuildContext context,
    String featureName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2418),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.mic_rounded, color: Color(0xFFA3D635)),
            SizedBox(width: 10),
            Text(
              'Quyền truy cập Micro',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'HI Chinese cần quyền truy cập Micro để sử dụng tính năng $featureName '
          '(phân tích phát âm thanh điệu và đối thoại cùng AI Tutor).\n\n'
          'Ứng dụng chỉ thu âm khi bạn nhấn giữ nút nói và tuyệt đối không ghi âm ngầm trong nền.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Để sau', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA3D635),
              foregroundColor: const Color(0xFF121811),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tiếp tục cấp quyền', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Directs user to Android App Settings if permission was permanently denied.
  static Future<void> _showPermanentlyDeniedDialog(
    BuildContext context,
    String featureName,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2418),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.settings_suggest_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text(
              'Cần mở Cài đặt ứng dụng',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Quyền truy cập Micro cho tính năng $featureName đã bị từ chối trước đó.\n\n'
          'Vui lòng vào Cài đặt ứng dụng để bật lại quyền Micro cho HI Chinese.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA3D635),
              foregroundColor: const Color(0xFF121811),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Mở Cài đặt', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
