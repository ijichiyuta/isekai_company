import 'dart:async';

/// Drives real-time ticks. Abstracted so tests can step ticks manually and
/// keep the deterministic core under a controlled clock (no wall-clock in
/// tests, mirroring §2.2's discipline in the UI layer).
abstract class TickClock {
  void start(Duration interval, void Function() onTick);
  void stop();
  bool get isRunning;
}

class RealTickClock implements TickClock {
  Timer? _timer;

  @override
  bool get isRunning => _timer != null;

  @override
  void start(Duration interval, void Function() onTick) {
    stop();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Test clock: [fire] advances one tick on demand; no real time passes.
class FakeTickClock implements TickClock {
  void Function()? _onTick;
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  void start(Duration interval, void Function() onTick) {
    _onTick = onTick;
    _running = true;
  }

  @override
  void stop() {
    _running = false;
  }

  /// Fire [n] ticks (only while "running", matching the real clock).
  void fire([int n = 1]) {
    for (var i = 0; i < n; i++) {
      if (_running) _onTick?.call();
    }
  }
}
