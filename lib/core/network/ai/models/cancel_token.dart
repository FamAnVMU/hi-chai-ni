class CancelToken {
  bool _isCancelled = false;
  String? _reason;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String reason = 'Cancelled by user']) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  void onCancelled(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}
