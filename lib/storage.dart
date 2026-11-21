import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pomodoro.dart';

/// Speichert Einstellungen und die Statistik lokal auf dem Gerät.
class Storage {
  static const _settingsKey = 'settings';
  static const _historyKey = 'history'; // Datum -> Anzahl Pomodoros

  Future<PomodoroSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const PomodoroSettings();
    return PomodoroSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(PomodoroSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(s.toJson()));
  }

  Future<Map<String, int>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
  }

  /// Einen fertigen Pomodoro für heute zählen.
  Future<Map<String, int>> addPomodoro(DateTime day) async {
    final history = await loadHistory();
    final key = dayKey(day);
    history[key] = (history[key] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history));
    return history;
  }
}

// "2026-11-21"
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Die letzten 7 Tage (ältester zuerst) mit Anzahl – für das Balkendiagramm.
List<(DateTime, int)> lastSevenDays(Map<String, int> history, DateTime today) {
  final start = DateTime(today.year, today.month, today.day);
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = start.subtract(Duration(days: i));
        return (d, history[dayKey(d)] ?? 0);
      }(),
  ];
}

/// Wie viele Tage hintereinander (bis heute) mindestens ein Pomodoro?
int streak(Map<String, int> history, DateTime today) {
  var d = DateTime(today.year, today.month, today.day);
  // Heute noch nichts gemacht? Dann zählen wir ab gestern.
  if ((history[dayKey(d)] ?? 0) == 0) d = d.subtract(const Duration(days: 1));
  var count = 0;
  while ((history[dayKey(d)] ?? 0) > 0) {
    count++;
    d = d.subtract(const Duration(days: 1));
  }
  return count;
}
