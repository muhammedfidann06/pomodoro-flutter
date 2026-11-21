import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pomodoro.dart';
import 'storage.dart';
import 'widgets.dart';

void main() => runApp(PomodoroApp(storage: Storage()));

class PomodoroApp extends StatelessWidget {
  final Storage storage;
  const PomodoroApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pomodoro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: Colors.red, brightness: Brightness.dark, useMaterial3: true),
        home: TimerPage(storage: storage),
      );
}

// Jede Phase hat ihre eigene Farbe.
Color phaseColor(Phase p) => switch (p) {
      Phase.work => const Color(0xFFE53935),
      Phase.shortBreak => const Color(0xFF43A047),
      Phase.longBreak => const Color(0xFF1E88E5),
    };

class TimerPage extends StatefulWidget {
  final Storage storage;
  const TimerPage({super.key, required this.storage});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final _controller = PomodoroController();
  final _task = TextEditingController();
  Map<String, int> _history = {};
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.onPhaseFinished = _onFinished;
    // Jede Sekunde reicht nicht ganz genau – 250 ms sieht flüssiger aus.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _controller.tick());
    _load();
  }

  Future<void> _load() async {
    final s = await widget.storage.loadSettings();
    final h = await widget.storage.loadHistory();
    if (!mounted) return;
    _controller.updateSettings(s);
    setState(() => _history = h);
  }

  void _onChange() {
    // Restzeit im Browser-Tab bzw. Task-Switcher anzeigen.
    SystemChrome.setApplicationSwitcherDescription(ApplicationSwitcherDescription(
      label: '${formatDuration(_controller.remaining)} · ${_controller.phase.label}',
      primaryColor: phaseColor(_controller.phase).toARGB32(),
    ));
    setState(() {});
  }

  Future<void> _onFinished(Phase finished) async {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    if (finished == Phase.work) {
      final h = await widget.storage.addPomodoro(DateTime.now());
      if (mounted) setState(() => _history = h);
    }
    if (!mounted) return;
    final msg = finished == Phase.work ? 'Super gemacht! Zeit für eine Pause.' : 'Pause vorbei. Weiter geht\'s!';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSettings() async {
    final result = await showModalBottomSheet<PomodoroSettings>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(initial: _controller.settings),
    );
    if (result == null) return;
    _controller.updateSettings(result);
    await widget.storage.saveSettings(result);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _task.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final color = phaseColor(c.phase);
    final today = _history[dayKey(DateTime.now())] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        actions: [
          IconButton(tooltip: 'Einstellungen', icon: const Icon(Icons.tune), onPressed: _openSettings),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              PhaseSelector(current: c.phase, color: color),
              const SizedBox(height: 24),
              TimerRing(
                progress: c.progress,
                color: color,
                time: formatDuration(c.remaining),
                subtitle: 'Runde ${c.round} von ${c.settings.roundsUntilLongBreak}',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(tooltip: 'Zurücksetzen', icon: const Icon(Icons.replay), onPressed: c.reset),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    key: const Key('startButton'),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size(160, 56),
                    ),
                    onPressed: c.toggle,
                    icon: Icon(c.isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(c.isRunning ? 'Pause' : 'Start'),
                  ),
                  const SizedBox(width: 16),
                  IconButton.outlined(tooltip: 'Überspringen', icon: const Icon(Icons.skip_next), onPressed: c.skip),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _task,
                decoration: const InputDecoration(
                  labelText: 'Woran arbeitest du gerade?',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              StatsCard(
                today: today,
                streak: streak(_history, DateTime.now()),
                week: lastSevenDays(_history, DateTime.now()),
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
