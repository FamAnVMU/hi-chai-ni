import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_tab.dart';

export '../../domain/app_tab.dart';

/// Provider holding the currently active tab in the App Shell
class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() {
    return AppTab.home;
  }

  void selectTab(AppTab tab) {
    state = tab;
  }

  void selectIndex(int index) {
    state = AppTab.fromIndex(index);
  }
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, AppTab>(
  SelectedTabNotifier.new,
);

/// Provider tracking whether the current screen has unsaved changes.
/// Used by PopScope to show confirmation dialog before exiting.
class UnsavedChangesNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void setHasUnsavedChanges(bool value) {
    state = value;
  }
}

final hasUnsavedChangesProvider = NotifierProvider<UnsavedChangesNotifier, bool>(
  UnsavedChangesNotifier.new,
);
