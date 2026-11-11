import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';

class StatRow {
  final String name;
  final Color color;
  double done = 0;
  int total = 0;
  int minutes = 0;

  StatRow(this.name, this.color);

  double? get pct => total == 0 ? null : done / total;
}

class DayBar {
  final String letter;
  final double? pct;
  final bool today;

  DayBar(this.letter, this.pct, this.today);
}

class Stats {
  double done = 0;
  int answered = 0;
  int minutes = 0;
  int tasksDone = 0;
  int tasksTotal = 0;
  List<DayBar> days = [];
  List<StatRow> byCat = [];
  List<StatRow> byEvent = [];
}

class AppStore extends ChangeNotifier {
  static const _prefsKey = 'horario_v1';
  static const defaultAccent = 0xFFC6FF3D;

  List<EventItem> events = [];
  List<Category> cats = [];

  /// "fecha|evento" -> "done" | "no"
  Map<String, String> log = {};

  /// "fecha|evento" -> horas hechas
  Map<String, double> hours = {};

  /// "fecha|tarea" -> hecha
  Map<String, bool> taskDone = {};

  /// "fecha|evento" -> tareas añadidas sobre la marcha ese día
  Map<String, List<TaskItem>> extra = {};

  int accent = defaultAccent;

  SharedPreferences? _prefs;
  int _n = 0;

  Color get accentColor => Color(accent);

  String uid() {
    _n++;
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$_n';
  }

  // ---------- Guardado ----------

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      }
    } catch (_) {
      // Si los datos guardados no se pueden leer, se arranca en vacío.
    }
  }

  void _fromJson(Map<String, dynamic> j) {
    events = ((j['events'] as List?) ?? [])
        .map((e) => EventItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    cats = ((j['cats'] as List?) ?? [])
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    log = ((j['log'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as String));
    hours = ((j['hours'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    taskDone = ((j['taskDone'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as bool));
    extra = ((j['extra'] as Map?) ?? {}).map((k, v) => MapEntry(
          k as String,
          (v as List).map((t) => TaskItem.fromJson(Map<String, dynamic>.from(t as Map))).toList(),
        ));
    accent = ((j['accent'] as num?) ?? defaultAccent).toInt();
  }

  Map<String, dynamic> _toJson() => {
        'events': events.map((e) => e.toJson()).toList(),
        'cats': cats.map((c) => c.toJson()).toList(),
        'log': log,
        'hours': hours,
        'taskDone': taskDone,
        'extra': extra.map((k, v) => MapEntry(k, v.map((t) => t.toJson()).toList())),
        'accent': accent,
      };

  void _commit({bool resync = false}) {
    notifyListeners();
    try {
      _prefs?.setString(_prefsKey, jsonEncode(_toJson()));
    } catch (_) {}
    if (resync) Notifier.resync(this);
  }

  // ---------- Consultas ----------

  List<EventItem> eventsOn(DateTime d) {
    final list = events.where((e) => e.occursOn(d)).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  Category? catOf(String id) {
    for (final c in cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Color colorOf(EventItem e) {
    if (e.color != 0) return Color(e.color);
    final c = catOf(e.catId);
    return c == null ? const Color(0xFF8A8A8A) : Color(c.color);
  }

  String evKey(String dayKey, EventItem e) => '$dayKey|${e.id}';

  /// Parte cumplida de un evento ese día (0..1) o null si no hay registro.
  double? fraction(EventItem e, String dayKey) {
    final k = evKey(dayKey, e);
    if (e.byHours) {
      final h = hours[k];
      if (h == null) return null;
      final min = e.minH <= 0 ? 1.0 : e.minH;
      return (h / min).clamp(0.0, 1.0).toDouble();
    }
    final v = log[k];
    if (v == 'done') return 1;
    if (v == 'no') return 0;
    return null;
  }

  List<TaskItem> tasksOf(EventItem e, String dayKey) => [...e.tasks, ...(extra[evKey(dayKey, e)] ?? const <TaskItem>[])];

  bool isTaskDone(String dayKey, TaskItem t) => taskDone['$dayKey|${t.id}'] ?? false;

  // ---------- Cambios ----------

  void toggleStatus(EventItem e, String dayKey, String value) {
    final k = evKey(dayKey, e);
    if (log[k] == value) {
      log.remove(k);
    } else {
      log[k] = value;
    }
    _commit();
  }

  void setHours(EventItem e, String dayKey, double value) {
    hours[evKey(dayKey, e)] = value;
    _commit();
  }

  void toggleTask(String dayKey, TaskItem t) {
    final k = '$dayKey|${t.id}';
    taskDone[k] = !(taskDone[k] ?? false);
    _commit(resync: t.remind.isNotEmpty);
  }

  void addExtraTask(EventItem e, String dayKey, String text, String remind) {
    final k = evKey(dayKey, e);
    extra.putIfAbsent(k, () => []).add(TaskItem(id: uid(), text: text, remind: remind));
    _commit(resync: remind.isNotEmpty);
  }

  void removeExtraTask(EventItem e, String dayKey, TaskItem t) {
    final k = evKey(dayKey, e);
    extra[k]?.removeWhere((x) => x.id == t.id);
    _commit(resync: t.remind.isNotEmpty);
  }

  void upsertEvent(EventItem e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _commit(resync: true);
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _commit(resync: true);
  }

  Category addCategory(String name) {
    const palette = [0xFF7DB7FF, 0xFFFF9F5A, 0xFF5FE0C0, 0xFFFF7DB0, 0xFFB9A3FF, 0xFFFFD95A, 0xFF9BE564, 0xFF7DE3FF, 0xFFFF8F8F, 0xFFB7B7B7];
    final c = Category(id: uid(), name: name, color: palette[cats.length % palette.length]);
    cats.add(c);
    _commit();
    return c;
  }

  void deleteCategory(String id) {
    cats.removeWhere((c) => c.id == id);
    for (final e in events) {
      if (e.catId == id) e.catId = '';
    }
    _commit();
  }

  void setAccent(int value) {
    accent = value;
    _commit();
  }

  // ---------- Estadísticas ----------

  Stats computeStats(int rangeDays) {
    const letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final todayKey = dateKey(now);
    final st = Stats();
    final byCat = <String, StatRow>{};
    final byEv = <String, StatRow>{};
    final span = rangeDays < 7 ? 7 : rangeDays;

    for (var i = span - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      final dk = dateKey(d);
      final inRange = i < rangeDays;
      double dayDone = 0;
      int dayAns = 0;

      for (final e in eventsOn(d)) {
        if (e.created.isNotEmpty && e.created.compareTo(dk) > 0) continue;
        final f = fraction(e, dk);
        if (f != null) {
          dayAns++;
          dayDone += f;
          if (inRange) {
            final mins = e.byHours ? ((hours[evKey(dk, e)] ?? 0) * 60).round() : (f >= 1 ? e.length : 0);
            st.answered++;
            st.done += f;
            st.minutes += mins;
            final cat = catOf(e.catId);
            final cr = byCat.putIfAbsent(
              cat?.id ?? '',
              () => StatRow(cat?.name ?? 'Sin categoría', cat == null ? const Color(0xFF8A8A8A) : Color(cat.color)),
            );
            cr.total++;
            cr.done += f;
            cr.minutes += mins;
            final er = byEv.putIfAbsent(e.title, () => StatRow(e.title, colorOf(e)));
            er.total++;
            er.done += f;
            er.minutes += mins;
          }
        }
        if (inRange && (dk.compareTo(todayKey) < 0 || e.start <= nowMin)) {
          for (final t in tasksOf(e, dk)) {
            st.tasksTotal++;
            if (isTaskDone(dk, t)) st.tasksDone++;
          }
        }
      }

      if (i < 7) {
        st.days.add(DayBar(letters[d.weekday - 1], dayAns == 0 ? null : dayDone / dayAns, i == 0));
      }
    }

    st.byCat = byCat.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
    st.byEvent = byEv.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
    return st;
  }
}
