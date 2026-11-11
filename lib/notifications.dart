import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// Programa los avisos de los eventos y de las tareas con recordatorio.
class Notifier {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _runId = 0;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'eventos',
      'Eventos y tareas',
      channelDescription: 'Avisos de inicio de eventos y recordatorios de tareas',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      }
      const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<bool> test() async {
    if (!_ready) return false;
    try {
      await _plugin.show(999999, 'Aviso de prueba', 'Las notificaciones funcionan.', _details);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Borra todo lo programado y lo vuelve a programar según los datos actuales.
  static Future<void> resync(AppStore s) async {
    if (!_ready) return;
    final run = ++_runId;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    var id = 1;
    final now = tz.TZDateTime.now(tz.local);

    for (final e in List<EventItem>.from(s.events)) {
      if (run != _runId) return;
      final range = '${fmtMin(e.start)} – ${fmtMin(e.end)}';
      final startTitle = 'Empieza: ${e.title}';
      final startBody = e.tasks.isEmpty ? range : '$range · ${e.tasks.length} tareas';
      final beforeTitle = '${e.title} en ${durText(e.notify)}';
      final beforeBody = 'Empieza a las ${fmtMin(e.start)}';

      if (e.isOnce) {
        final d = parseKey(e.date);
        final at = tz.TZDateTime(tz.local, d.year, d.month, d.day, e.start ~/ 60, e.start % 60);
        if (at.isAfter(now)) await _once(id++, startTitle, startBody, at);
        if (e.notify > 0) {
          final before = at.subtract(Duration(minutes: e.notify));
          if (before.isAfter(now)) await _once(id++, beforeTitle, beforeBody, before);
        }
      } else {
        for (final wd in e.days) {
          await _weekly(id++, startTitle, startBody, wd, e.start, now);
          if (e.notify > 0) {
            var m = e.start - e.notify;
            var w = wd;
            while (m < 0) {
              m += 1440;
              w = w == 1 ? 7 : w - 1;
            }
            await _weekly(id++, beforeTitle, beforeBody, w, m, now);
          }
        }
      }
    }

    // Recordatorios de tareas añadidas sobre la marcha.
    for (final entry in Map<String, List<TaskItem>>.from(s.extra).entries) {
      if (run != _runId) return;
      final dayKey = entry.key.split('|').first;
      DateTime d;
      try {
        d = parseKey(dayKey);
      } catch (_) {
        continue;
      }
      for (final t in List<TaskItem>.from(entry.value)) {
        if (t.remind.isEmpty || s.isTaskDone(dayKey, t)) continue;
        final p = t.remind.split(':');
        if (p.length != 2) continue;
        final h = int.tryParse(p[0]);
        final mi = int.tryParse(p[1]);
        if (h == null || mi == null) continue;
        final at = tz.TZDateTime(tz.local, d.year, d.month, d.day, h, mi);
        if (at.isAfter(now)) await _once(id++, 'Tarea: ${t.text}', 'Recordatorio de las ${t.remind}', at);
      }
    }
  }

  static tz.TZDateTime _next(int weekday, int minutes, tz.TZDateTime now) {
    for (var i = 0; i < 8; i++) {
      final d = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, minutes ~/ 60, minutes % 60);
      if (d.weekday == weekday && d.isAfter(now)) return d;
    }
    return tz.TZDateTime(tz.local, now.year, now.month, now.day + 7, minutes ~/ 60, minutes % 60);
  }

  static Future<void> _weekly(int id, String title, String body, int weekday, int minutes, tz.TZDateTime now) async {
    await _schedule(id, title, body, _next(weekday, minutes, now), DateTimeComponents.dayOfWeekAndTime);
  }

  static Future<void> _once(int id, String title, String body, tz.TZDateTime at) async {
    await _schedule(id, title, body, at, null);
  }

  static Future<void> _schedule(int id, String title, String body, tz.TZDateTime at, DateTimeComponents? match) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    } catch (_) {
      // Sin permiso de alarmas exactas: se programa como aviso aproximado.
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match,
        );
      } catch (_) {}
    }
  }
}
