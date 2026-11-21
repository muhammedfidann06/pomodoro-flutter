import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/main.dart';
import 'package:pomodoro/pomodoro.dart';
import 'package:pomodoro/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Eine "falsche" Uhr: Wir bestimmen selbst, wie spät es ist.
class FakeClock {
  DateTime now = DateTime(2026, 11, 21, 9);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('PomodoroController', () {
    late FakeClock clock;
    late PomodoroController c;
    const s = PomodoroSettings(workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, roundsUntilLongBreak: 2);

    setUp(() {
      clock = FakeClock();
      c = PomodoroController(settings: s, clock: () => clock.now);
    });

    test('Startet mit Arbeit und 25:00', () {
      expect(c.phase, Phase.work);
      expect(formatDuration(c.remaining), '25:00');
      expect(c.isRunning, isFalse);
    });

    test('Restzeit läuft ab und Pause hält sie an', () {
      c.start();
      clock.advance(const Duration(minutes: 10));
      c.tick();
      expect(formatDuration(c.remaining), '15:00');
      c.pause();
      clock.advance(const Duration(minutes: 5)); // in der Pause passiert nichts
      c.tick();
      expect(formatDuration(c.remaining), '15:00');
      expect(c.progress, closeTo(0.4, 0.001));
    });

    test('Nach Arbeit kommt kurze Pause, nach 2 Runden lange Pause', () {
      final finished = <Phase>[];
      c.onPhaseFinished = finished.add;

      void finishPhase() {
        c.start();
        clock.advance(c.remaining + const Duration(seconds: 1));
        c.tick();
      }

      finishPhase();
      expect(c.phase, Phase.shortBreak);
      expect(c.completedWork, 1);
      finishPhase();
      expect(c.phase, Phase.work);
      finishPhase();
      expect(c.phase, Phase.longBreak);
      expect(c.completedWork, 2);
      expect(finished, [Phase.work, Phase.shortBreak, Phase.work]);
    });

    test('Überspringen zählt nicht als fertige Arbeit', () {
      c.skip();
      expect(c.phase, Phase.shortBreak);
      expect(c.completedWork, 0);
    });

    test('Auto-Start startet die nächste Phase sofort', () {
      c.updateSettings(s.copyWith(autoStart: true));
      c.start();
      clock.advance(const Duration(minutes: 26));
      c.tick();
      expect(c.phase, Phase.shortBreak);
      expect(c.isRunning, isTrue);
    });

    test('Neue Einstellungen ändern die Zeit, wenn der Timer steht', () {
      c.updateSettings(s.copyWith(workMinutes: 50));
      expect(formatDuration(c.remaining), '50:00');
    });
  });

  test('formatDuration rundet auf', () {
    expect(formatDuration(const Duration(milliseconds: 59001)), '01:00');
    expect(formatDuration(Duration.zero), '00:00');
  });

  test('Settings JSON hin und zurück', () {
    const s = PomodoroSettings(workMinutes: 40, autoStart: true);
    final back = PomodoroSettings.fromJson(s.toJson());
    expect(back.workMinutes, 40);
    expect(back.autoStart, isTrue);
  });

  group('Statistik', () {
    final today = DateTime(2026, 11, 21);
    final history = {'2026-11-21': 3, '2026-11-20': 1, '2026-11-19': 2, '2026-11-17': 5};

    test('Serie zählt Tage ohne Lücke', () {
      expect(streak(history, today), 3);
      // Heute noch nichts -> Serie bis gestern zählt trotzdem.
      expect(streak({'2026-11-20': 1}, today), 1);
      expect(streak({}, today), 0);
    });

    test('Letzte 7 Tage', () {
      final week = lastSevenDays(history, today);
      expect(week.length, 7);
      expect(week.last.$2, 3);
      expect(week.first.$1, DateTime(2026, 11, 15));
    });
  });

  testWidgets('App startet, Start/Pause funktioniert', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Großer Bildschirm wie ein Handy im Hochformat, damit alle Knöpfe sichtbar sind.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PomodoroApp(storage: Storage()));
    await tester.pump();

    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });
}
