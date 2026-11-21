# 🍅 Pomodoro – Flutter Focus Timer

[![ci](https://github.com/muhammedfidann06/pomodoro-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/muhammedfidann06/pomodoro-flutter/actions/workflows/ci.yml)

**Live demo:** https://muhammedfidann06.github.io/pomodoro-flutter/

A cross-platform Pomodoro timer (Android, iOS, Web, Desktop) built with Flutter and Material 3.

## Features
- Work / short break / long break cycle with a configurable number of rounds
- Drift-free timer: stores the *end time* instead of counting ticks, so it stays exact when the app or browser tab is in the background
- Smooth animated progress ring, a colour for each phase, dark mode
- Remaining time shown in the browser tab / task switcher
- Settings (durations, rounds, auto-start) saved locally with `shared_preferences`
- Statistics: today, day streak and a 7-day bar chart
- Sound, haptic feedback and a message when a phase ends
- Keyboard shortcuts on web and desktop: **Space** start/pause, **R** reset, **S** skip

## Architecture
```
lib/
  pomodoro.dart   # PomodoroController (pure logic, ChangeNotifier) + settings
  storage.dart    # persistence, streak & weekly statistics
  widgets.dart    # TimerRing, PhaseSelector, StatsCard, SettingsSheet
  main.dart       # app + TimerPage
```
The controller gets an injectable clock (`DateTime Function()`), so the tests can "fast-forward" time without waiting.

## Run
```bash
flutter pub get
flutter create . --platforms=web,android   # only needed once (platform folders)
flutter run
flutter test
```

## Kurzbeschreibung (Deutsch)
Ein Pomodoro-Timer mit Flutter: 25 Minuten arbeiten, dann eine kurze Pause, nach vier Runden eine lange Pause.
Die Einstellungen und die Statistik werden lokal gespeichert. Die Logik ist von der UI getrennt und hat Unit-Tests.
