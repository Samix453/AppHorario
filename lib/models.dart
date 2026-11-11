import 'package:flutter/material.dart';

String pad2(int n) => n < 10 ? '0$n' : '$n';

/// Minutos desde medianoche -> "HH:MM" (1440 se muestra como 00:00).
String fmtMin(int m) {
  m = m % 1440;
  return '${pad2(m ~/ 60)}:${pad2(m % 60)}';
}

String dateKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String durText(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

/// 6.5 -> "6,5", 8.0 -> "8".
String numText(double v) {
  var s = v.toStringAsFixed(2);
  s = s.replaceAll(RegExp(r'0+$'), '');
  s = s.replaceAll(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}

Color inkOn(Color c) => c.computeLuminance() > 0.32 ? Colors.black : Colors.white;

class Category {
  String id;
  String name;
  int color;

  Category({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        color: (j['color'] as num).toInt(),
      );
}

class TaskItem {
  String id;
  String text;

  /// "HH:MM" o vacío. Solo lo usan las tareas añadidas sobre la marcha.
  String remind;

  TaskItem({required this.id, required this.text, this.remind = ''});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'remind': remind};

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        text: j['text'] as String,
        remind: (j['remind'] as String?) ?? '',
      );
}

class EventItem {
  String id;
  String title;
  String catId;

  /// 0 = usar el color de la categoría.
  int color;

  /// Días de la semana (1 = lunes ... 7 = domingo) si se repite cada semana.
  List<int> days;

  /// "yyyy-MM-dd" si es un evento puntual; vacío si es semanal.
  String date;

  /// Minutos desde medianoche.
  int start;
  int end;

  /// Minutos de aviso previo (0 = sin aviso previo).
  int notify;

  /// Seguimiento por horas en vez de check / no.
  bool byHours;
  double minH;

  List<TaskItem> tasks;

  /// Día en que se creó, para no contarlo en estadísticas anteriores.
  String created;

  EventItem({
    required this.id,
    required this.title,
    required this.catId,
    required this.color,
    required this.days,
    required this.date,
    required this.start,
    required this.end,
    required this.notify,
    required this.byHours,
    required this.minH,
    required this.tasks,
    required this.created,
  });

  bool get isOnce => date.isNotEmpty;
  int get length => end - start;

  bool occursOn(DateTime d) => isOnce ? date == dateKey(d) : days.contains(d.weekday);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'catId': catId,
        'color': color,
        'days': days,
        'date': date,
        'start': start,
        'end': end,
        'notify': notify,
        'byHours': byHours,
        'minH': minH,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'created': created,
      };

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: j['id'] as String,
        title: j['title'] as String,
        catId: (j['catId'] as String?) ?? '',
        color: ((j['color'] as num?) ?? 0).toInt(),
        days: ((j['days'] as List?) ?? []).map((e) => (e as num).toInt()).toList(),
        date: (j['date'] as String?) ?? '',
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
        notify: ((j['notify'] as num?) ?? 0).toInt(),
        byHours: (j['byHours'] as bool?) ?? false,
        minH: ((j['minH'] as num?) ?? 8).toDouble(),
        tasks: ((j['tasks'] as List?) ?? [])
            .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        created: (j['created'] as String?) ?? '',
      );
}
