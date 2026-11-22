import 'package:flutter/foundation.dart';

// Die drei Phasen der Pomodoro-Technik.
enum Phase { work, shortBreak, longBreak }

extension PhaseText on Phase {
  String get label => switch (this) {
        Phase.work => 'Arbeit',
        Phase.shortBreak => 'Kurze Pause',
        Phase.longBreak => 'Lange Pause',
      };
}

// Einstellungen in Minuten. Unveränderlich: Für Änderungen gibt es copyWith.
@immutable
class PomodoroSettings {
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsUntilLongBreak; // nach so vielen Arbeitsphasen kommt die lange Pause
  final bool autoStart; // nächste Phase automatisch starten?
  final int dailyGoal; // Ziel: so viele Pomodoros pro Tag

  const PomodoroSettings({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.roundsUntilLongBreak = 4,
    this.autoStart = false,
    this.dailyGoal = 8,
  });

  PomodoroSettings copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsUntilLongBreak,
    bool? autoStart,
    int? dailyGoal,
  }) =>
      PomodoroSettings(
        workMinutes: workMinutes ?? this.workMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        roundsUntilLongBreak: roundsUntilLongBreak ?? this.roundsUntilLongBreak,
        autoStart: autoStart ?? this.autoStart,
        dailyGoal: dailyGoal ?? this.dailyGoal,
      );

  Duration durationOf(Phase p) => Duration(
        minutes: switch (p) {
          Phase.work => workMinutes,
          Phase.shortBreak => shortBreakMinutes,
          Phase.longBreak => longBreakMinutes,
        },
      );

  Map<String, Object> toJson() => {
        'work': workMinutes,
        'short': shortBreakMinutes,
        'long': longBreakMinutes,
        'rounds': roundsUntilLongBreak,
        'auto': autoStart,
        'goal': dailyGoal,
      };

  factory PomodoroSettings.fromJson(Map<String, dynamic> j) => PomodoroSettings(
        workMinutes: j['work'] as int? ?? 25,
        shortBreakMinutes: j['short'] as int? ?? 5,
        longBreakMinutes: j['long'] as int? ?? 15,
        roundsUntilLongBreak: j['rounds'] as int? ?? 4,
        autoStart: j['auto'] as bool? ?? false,
        dailyGoal: j['goal'] as int? ?? 8, // alte Einstellungen ohne Ziel -> Standardwert
      );

  /// Fortschritt zum Tagesziel von 0.0 bis 1.0 (mehr als das Ziel zählt als 1.0).
  double goalProgress(int doneToday) => dailyGoal <= 0 ? 1 : (doneToday / dailyGoal).clamp(0.0, 1.0);
}

/// Die Logik des Timers – ohne UI, damit man sie leicht testen kann.
///
/// Wichtig: Wir speichern die END-Zeit und rechnen die Restzeit jedes Mal neu.
/// So geht keine Zeit verloren, wenn der Browser-Tab im Hintergrund langsamer tickt.
class PomodoroController extends ChangeNotifier {
  PomodoroController({PomodoroSettings settings = const PomodoroSettings(), DateTime Function()? clock})
      : _settings = settings,
        _clock = clock ?? DateTime.now,
        _remaining = settings.durationOf(Phase.work);

  final DateTime Function() _clock;
  PomodoroSettings _settings;
  Phase _phase = Phase.work;
  Duration _remaining;
  DateTime? _endsAt; // null = pausiert
  int _completedWork = 0; // fertige Arbeitsphasen (für die lange Pause)

  /// Wird aufgerufen, wenn eine Phase fertig ist (z. B. für eine Meldung).
  void Function(Phase finished)? onPhaseFinished;

  PomodoroSettings get settings => _settings;
  Phase get phase => _phase;
  Duration get remaining => _remaining;
  bool get isRunning => _endsAt != null;
  int get completedWork => _completedWork;

  /// Fortschritt der aktuellen Phase von 0.0 bis 1.0.
  double get progress {
    final total = _settings.durationOf(_phase).inMilliseconds;
    if (total == 0) return 1;
    return (1 - _remaining.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Welche Runde im aktuellen Zyklus (1 bis roundsUntilLongBreak).
  int get round {
    final n = _settings.roundsUntilLongBreak;
    if (_phase == Phase.work) return _completedWork % n + 1;
    // In der Pause zeigen wir die Runde, die gerade fertig ist.
    return _completedWork == 0 ? 1 : (_completedWork - 1) % n + 1;
  }

  void start() {
    if (isRunning) return;
    _endsAt = _clock().add(_remaining);
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _remaining = _endsAt!.difference(_clock());
    _endsAt = null;
    notifyListeners();
  }

  void toggle() => isRunning ? pause() : start();

  /// Aktuelle Phase von vorne beginnen.
  void reset() {
    _endsAt = null;
    _remaining = _settings.durationOf(_phase);
    notifyListeners();
  }

  /// Phase überspringen (zählt NICHT als fertige Arbeit).
  void skip() => _goToNext(countWork: false);

  /// Neue Einstellungen. Wenn der Timer steht, passt sich die Restzeit an.
  void updateSettings(PomodoroSettings s) {
    _settings = s;
    if (!isRunning) _remaining = s.durationOf(_phase);
    notifyListeners();
  }

  /// Soll regelmäßig aufgerufen werden (z. B. jede Sekunde von einem Timer).
  void tick() {
    if (!isRunning) return;
    final left = _endsAt!.difference(_clock());
    if (left > Duration.zero) {
      _remaining = left;
      notifyListeners();
      return;
    }
    final finished = _phase;
    _goToNext(countWork: true);
    onPhaseFinished?.call(finished);
  }

  /// Welche Phase kommt als nächstes?
  Phase nextPhase({required bool countWork}) {
    if (_phase != Phase.work) return Phase.work;
    final done = _completedWork + (countWork ? 1 : 0);
    // Nach jeder n-ten fertigen Arbeitsphase gibt es die lange Pause.
    return countWork && done % _settings.roundsUntilLongBreak == 0 ? Phase.longBreak : Phase.shortBreak;
  }

  void _goToNext({required bool countWork}) {
    final next = nextPhase(countWork: countWork);
    if (_phase == Phase.work && countWork) _completedWork++;
    _phase = next;
    _remaining = _settings.durationOf(next);
    _endsAt = _settings.autoStart && countWork ? _clock().add(_remaining) : null;
    notifyListeners();
  }
}

/// "mm:ss" – z. B. 24:59
String formatDuration(Duration d) {
  // Aufrunden, damit 0:00 erst ganz am Ende erscheint.
  final secs = (d.inMilliseconds / 1000).ceil().clamp(0, 1 << 31);
  final m = (secs ~/ 60).toString().padLeft(2, '0');
  final s = (secs % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
