import 'package:flutter/material.dart';

import 'pomodoro.dart';

// Zeigt die drei Phasen. Die aktive Phase ist farbig.
class PhaseSelector extends StatelessWidget {
  final Phase current;
  final Color color;
  const PhaseSelector({super.key, required this.current, required this.color});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final p in Phase.values)
            Chip(
              label: Text(p.label),
              backgroundColor: p == current ? color.withValues(alpha: 0.2) : null,
              side: BorderSide(color: p == current ? color : Colors.transparent),
            ),
        ],
      );
}

// Der große Kreis mit der Restzeit in der Mitte.
class TimerRing extends StatelessWidget {
  final double progress;
  final Color color;
  final String time;
  final String subtitle;
  const TimerRing({super.key, required this.progress, required this.color, required this.time, required this.subtitle});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // TweenAnimationBuilder: Der Kreis bewegt sich weich, nicht in Sprüngen.
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (_, value, __) => CircularProgressIndicator(
                value: value,
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    key: const Key('time'),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()], // Ziffern gleich breit
                        ),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      );
}

// Statistik: heute, Serie und ein kleines Balkendiagramm für 7 Tage.
class StatsCard extends StatelessWidget {
  final int today;
  final int streak;
  final List<(DateTime, int)> week;
  final Color color;
  const StatsCard({super.key, required this.today, required this.streak, required this.week, required this.color});

  static const _days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final max = week.fold<int>(1, (m, e) => e.$2 > m ? e.$2 : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Stat(icon: Icons.check_circle, label: 'Heute', value: '$today')),
                Expanded(child: _Stat(icon: Icons.local_fire_department, label: 'Serie', value: '$streak Tage')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (day, count) in week)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$count', style: Theme.of(context).textTheme.labelSmall),
                          Container(
                            height: 50 * count / max + 2,
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                          ),
                          Text(_days[day.weekday - 1], style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ],
      );
}

// Einstellungen mit Schiebereglern. Gibt beim Speichern die neuen Werte zurück.
class SettingsSheet extends StatefulWidget {
  final PomodoroSettings initial;
  const SettingsSheet({super.key, required this.initial});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late PomodoroSettings _s = widget.initial;

  Widget _slider(String label, int value, int min, int max, ValueChanged<int> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value', style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Einstellungen', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _slider('Arbeit (Minuten)', _s.workMinutes, 5, 60, (v) => setState(() => _s = _s.copyWith(workMinutes: v))),
              _slider('Kurze Pause (Minuten)', _s.shortBreakMinutes, 1, 15,
                  (v) => setState(() => _s = _s.copyWith(shortBreakMinutes: v))),
              _slider('Lange Pause (Minuten)', _s.longBreakMinutes, 5, 45,
                  (v) => setState(() => _s = _s.copyWith(longBreakMinutes: v))),
              _slider('Runden bis zur langen Pause', _s.roundsUntilLongBreak, 2, 8,
                  (v) => setState(() => _s = _s.copyWith(roundsUntilLongBreak: v))),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nächste Phase automatisch starten'),
                value: _s.autoStart,
                onChanged: (v) => setState(() => _s = _s.copyWith(autoStart: v)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(context, _s), child: const Text('Speichern')),
              ),
            ],
          ),
        ),
      );
}
