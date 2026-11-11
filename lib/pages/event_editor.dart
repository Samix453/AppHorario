import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui.dart';

Future<void> openEventEditor(BuildContext context, AppStore store, {EventItem? event, String? presetDate}) {
  return Navigator.of(context).push<void>(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, a, b) => EventEditorPage(store: store, event: event, presetDate: presetDate),
    transitionsBuilder: (context, a, b, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
        child: child,
      ),
    ),
  ));
}

class EventEditorPage extends StatefulWidget {
  final AppStore store;
  final EventItem? event;
  final String? presetDate;

  const EventEditorPage({super.key, required this.store, this.event, this.presetDate});

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _minH;
  final TextEditingController _newCat = TextEditingController();
  final TextEditingController _newTask = TextEditingController();

  bool _weekly = true;
  Set<int> _days = {};
  String _date = '';
  int _start = 16 * 60;
  int _end = 17 * 60;
  String _cat = '';
  int _color = 0;
  int _notify = 0;
  bool _byHours = false;
  List<TaskItem> _tasks = [];

  String _timeEdit = '';
  bool _hourMode = true;
  bool _catOpen = false;
  String _error = '';

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final today = DateTime.now();
    if (e != null) {
      _weekly = !e.isOnce;
      _days = e.days.toSet();
      _date = e.isOnce ? e.date : dateKey(today);
      _start = e.start;
      _end = e.end;
      _cat = e.catId;
      _color = e.color;
      _notify = e.notify;
      _byHours = e.byHours;
      _tasks = e.tasks.map((t) => TaskItem(id: t.id, text: t.text, remind: t.remind)).toList();
    } else {
      _days = {today.weekday};
      _date = widget.presetDate ?? dateKey(today);
      _weekly = widget.presetDate == null;
    }
    _title = TextEditingController(text: e?.title ?? '');
    _minH = TextEditingController(text: numText(e?.minH ?? 8));
  }

  @override
  void dispose() {
    _title.dispose();
    _minH.dispose();
    _newCat.dispose();
    _newTask.dispose();
    super.dispose();
  }

  bool get _timeOk => _end > _start;

  void _setTime(String which, int mins) {
    mins = ((mins % 1440) + 1440) % 1440;
    setState(() {
      _error = '';
      if (which == 'start') {
        final dur = _end - _start;
        _start = mins;
        if (dur > 0) {
          final ne = mins + dur;
          _end = ne > 1440 ? 1440 : ne;
        }
      } else {
        _end = mins == 0 ? 1440 : mins;
      }
    });
  }

  int _current(String which) => (which == 'start' ? _start : _end) % 1440;

  Future<void> _pickDate() async {
    final init = parseKey(_date);
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _date = dateKey(d));
  }

  void _save() {
    final title = _title.text.trim();
    final minH = double.tryParse(_minH.text.trim().replaceAll(',', '.')) ?? 0;
    String err = '';
    if (title.isEmpty) {
      err = 'Ponle un nombre al evento.';
    } else if (!_timeOk) {
      err = 'La hora de fin debe ser posterior a la de inicio.';
    } else if (_weekly && _days.isEmpty) {
      err = 'Elige al menos un día de la semana.';
    } else if (_byHours && minH <= 0) {
      err = 'Indica un mínimo de horas mayor que cero.';
    }
    if (err.isNotEmpty) {
      setState(() => _error = err);
      return;
    }
    final old = widget.event;
    final days = _days.toList()..sort();
    s.upsertEvent(EventItem(
      id: old?.id ?? s.uid(),
      title: title,
      catId: _cat,
      color: _color,
      days: _weekly ? days : <int>[],
      date: _weekly ? '' : _date,
      start: _start,
      end: _end,
      notify: _notify,
      byHours: _byHours,
      minH: minH <= 0 ? 8 : minH,
      tasks: _tasks,
      created: old?.created ?? dateKey(DateTime.now()),
    ));
    Navigator.of(context).pop();
  }

  void _delete() {
    final old = widget.event;
    if (old != null) s.deleteEvent(old.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = s.accentColor;
    final cat = s.catOf(_cat);
    final dateD = parseKey(_date);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 15, color: kGrey)),
                  ),
                  Expanded(
                    child: Text(
                      widget.event == null ? 'Nuevo evento' : 'Editar evento',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Material(
                    color: accent,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _save,
                      child: const SizedBox(
                        height: 44,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            widthFactor: 1,
                            child: Text('Guardar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadePanel(
                      open: _error.isNotEmpty,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF5A2A2A)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error, style: const TextStyle(fontSize: 14, color: kError)),
                      ),
                    ),
                    const FieldLabel('Nombre'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      decoration: fieldDecoration('Ej. Programación'),
                    ),
                    const SizedBox(height: 20),

                    // Repetición
                    const FieldLabel('Repetición'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Pill(label: 'Cada semana', selected: _weekly, accent: accent, onTap: () => setState(() => _weekly = true))),
                        const SizedBox(width: 6),
                        Expanded(child: Pill(label: 'Solo un día', selected: !_weekly, accent: accent, onTap: () => setState(() => _weekly = false))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _weekly
                          ? Row(
                              key: const ValueKey('days'),
                              children: [
                                for (var i = 0; i < 7; i++) ...[
                                  if (i > 0) const SizedBox(width: 6),
                                  Expanded(
                                    child: Semantics(
                                      label: kDays[i],
                                      child: Pill(
                                        label: kLetters[i],
                                        selected: _days.contains(i + 1),
                                        accent: accent,
                                        onTap: () => setState(() {
                                          _error = '';
                                          if (!_days.remove(i + 1)) _days.add(i + 1);
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Material(
                              key: const ValueKey('date'),
                              color: kField,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: kBorder),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _pickDate,
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${kDays[dateD.weekday - 1]}, ${dateD.day} de ${kMonths[dateD.month - 1]} de ${dateD.year}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Horario
                    const FieldLabel('Horario'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _timeButton('Empieza', 'start', _start, accent)),
                        const SizedBox(width: 10),
                        Expanded(child: _timeButton('Termina', 'end', _end, accent)),
                      ],
                    ),
                    FadePanel(open: _timeEdit.isNotEmpty, child: _clockPanel(accent)),
                    const SizedBox(height: 10),
                    const FieldLabel('Duración rápida'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final u in const [15, 30, 45, 60, 90, 120, 180])
                          Pill(
                            label: durText(u),
                            selected: _end - _start == u,
                            accent: accent,
                            onTap: () => setState(() {
                              _error = '';
                              final ne = _start + u;
                              _end = ne > 1440 ? 1440 : ne;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timeOk ? 'Dura ${durText(_end - _start)}' : 'La hora de fin debe ser posterior a la de inicio.',
                      style: TextStyle(fontSize: 13, color: _timeOk ? Colors.white : kError),
                    ),
                    const SizedBox(height: 20),

                    // Categoría
                    const FieldLabel('Categoría'),
                    const SizedBox(height: 8),
                    Material(
                      color: kField,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: kBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _catOpen = !_catOpen),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              _dot(cat == null ? const Color(0xFF8A8A8A) : Color(cat.color)),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  cat?.name ?? 'Sin categoría',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              AnimatedRotation(
                                turns: _catOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.expand_more_rounded, color: kGrey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FadePanel(open: _catOpen, child: _catPanel(accent)),
                    const SizedBox(height: 20),

                    // Seguimiento
                    const FieldLabel('Seguimiento'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Pill(label: 'Check o No', selected: !_byHours, accent: accent, onTap: () => setState(() => _byHours = false))),
                        const SizedBox(width: 6),
                        Expanded(child: Pill(label: 'Por horas', selected: _byHours, accent: accent, onTap: () => setState(() => _byHours = true))),
                      ],
                    ),
                    FadePanel(
                      open: _byHours,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const FieldLabel('Mínimo de horas para el 100 %'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _minH,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 16, color: Colors.white),
                              decoration: fieldDecoration('8'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color
                    const FieldLabel('Color del evento'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in kEventPalette)
                          Semantics(
                            button: true,
                            label: 'Color',
                            child: GestureDetector(
                              onTap: () => setState(() => _color = _color == c ? 0 : c),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black, width: 3),
                                  boxShadow: [BoxShadow(color: _color == c ? Colors.white : Colors.black, spreadRadius: 2)],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Si no eliges ninguno, usa el color de su categoría.', style: TextStyle(fontSize: 12, color: kGrey)),
                    const SizedBox(height: 20),

                    // Avisos
                    const FieldLabel('Aviso antes de empezar'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final n in const [0, 5, 10, 15, 30, 60])
                          Pill(
                            label: n == 0 ? 'Sin aviso' : durText(n),
                            selected: _notify == n,
                            accent: accent,
                            onTap: () => setState(() => _notify = n),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tareas
                    const FieldLabel('Tareas dentro del evento'),
                    const SizedBox(height: 8),
                    for (final t in _tasks)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.only(left: 12),
                        constraints: const BoxConstraints(minHeight: 44),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF222222)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(t.text, style: const TextStyle(fontSize: 15))),
                            IconButton(
                              tooltip: 'Quitar tarea',
                              onPressed: () => setState(() => _tasks.removeWhere((x) => x.id == t.id)),
                              icon: const Icon(Icons.close_rounded, size: 18, color: kGrey),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTask,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(fontSize: 15, color: Colors.white),
                            decoration: fieldDecoration('Ej. Lavarse los dientes'),
                            onSubmitted: (_) => _addTask(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Pill(label: 'Añadir', selected: false, accent: accent, onTap: _addTask),
                      ],
                    ),

                    if (widget.event != null) ...[
                      const SizedBox(height: 24),
                      Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF5A2A2A)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _delete,
                          child: const SizedBox(
                            height: 48,
                            child: Center(
                              child: Text('Eliminar evento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kError)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addTask() {
    final text = _newTask.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(TaskItem(id: s.uid(), text: text));
      _newTask.clear();
    });
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _timeButton(String label, String which, int value, Color accent) {
    final active = _timeEdit == which;
    return Material(
      color: kField,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? accent : kBorder, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _timeEdit = active ? '' : which;
          _hourMode = true;
        }),
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
              const SizedBox(height: 2),
              Text(fmtMin(value), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clockPanel(Color accent) {
    final which = _timeEdit.isEmpty ? 'start' : _timeEdit;
    final cur = _current(which);
    final hour = cur ~/ 60;
    final minute = cur % 60;

    Widget part(String text, bool selected, VoidCallback onTap) => Material(
          color: selected ? accent : kChip,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 48,
              constraints: const BoxConstraints(minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  text,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: selected ? Colors.black : Colors.white),
                ),
              ),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  which == 'end' ? 'Hora de fin' : 'Hora de inicio',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              part(pad2(hour), _hourMode, () => setState(() => _hourMode = true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              part(pad2(minute), !_hourMode, () => setState(() => _hourMode = false)),
              IconButton(
                tooltip: 'Cerrar selector de hora',
                onPressed: () => setState(() => _timeEdit = ''),
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClockDial(
              hourMode: _hourMode,
              hour: hour,
              minute: minute,
              accent: accent,
              onHour: (h) => _setTime(which, h * 60 + _current(which) % 60),
              onMinute: (m) => _setTime(which, (_current(which) ~/ 60) * 60 + m),
              onHourDone: () => setState(() => _hourMode = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catPanel(Color accent) {
    Widget row(String id, String name, Color color) {
      final sel = _cat == id;
      return InkWell(
        onTap: () => setState(() {
          _cat = id;
          _catOpen = false;
        }),
        child: Container(
          height: 46,
          padding: const EdgeInsets.only(left: 12, right: 4),
          color: sel ? const Color(0xFF1C1C1C) : Colors.transparent,
          child: Row(
            children: [
              _dot(color),
              const SizedBox(width: 9),
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
              if (sel) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.check_rounded, size: 18, color: accent)),
              if (id.isNotEmpty)
                IconButton(
                  tooltip: 'Borrar categoría',
                  onPressed: () => setState(() {
                    s.deleteCategory(id);
                    if (_cat == id) _cat = '';
                  }),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kGrey),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 232),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    row('', 'Sin categoría', const Color(0xFF8A8A8A)),
                    for (final c in s.cats) row(c.id, c.name, Color(c.color)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCat,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      decoration: fieldDecoration('Nueva categoría'),
                      onSubmitted: (_) => _addCat(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Pill(label: 'Crear', selected: false, accent: accent, onTap: _addCat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCat() {
    final name = _newCat.text.trim();
    if (name.isEmpty) return;
    final c = s.addCategory(name);
    setState(() {
      _cat = c.id;
      _catOpen = false;
      _newCat.clear();
    });
  }
}

/// Reloj analógico de 24 h: anillo exterior 01–12, interior 13–00. Se puede tocar o arrastrar.
class ClockDial extends StatelessWidget {
  static const double size = 280;
  static const double outerR = 114;
  static const double innerR = 74;

  final bool hourMode;
  final int hour;
  final int minute;
  final Color accent;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;
  final VoidCallback onHourDone;

  const ClockDial({
    super.key,
    required this.hourMode,
    required this.hour,
    required this.minute,
    required this.accent,
    required this.onHour,
    required this.onMinute,
    required this.onHourDone,
  });

  void _handle(Offset p) {
    final d = p - const Offset(size / 2, size / 2);
    if (d.distance < 14) return;
    var ang = math.atan2(d.dx, -d.dy);
    if (ang < 0) ang += 2 * math.pi;
    final idx = (ang / (math.pi / 6)).round() % 12;
    if (hourMode) {
      final inner = d.distance < (outerR + innerR) / 2;
      final h = inner ? (idx == 0 ? 0 : idx + 12) : (idx == 0 ? 12 : idx);
      if (h != hour) onHour(h);
    } else {
      final m = idx * 5;
      if (m != minute) onMinute(m);
    }
  }

  void _end() {
    if (hourMode) onHourDone();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hourMode ? 'Reloj para elegir la hora' : 'Reloj para elegir los minutos',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handle(d.localPosition),
        onTapUp: (_) => _end(),
        onVerticalDragStart: (d) => _handle(d.localPosition),
        onVerticalDragUpdate: (d) => _handle(d.localPosition),
        onVerticalDragEnd: (_) => _end(),
        onHorizontalDragStart: (d) => _handle(d.localPosition),
        onHorizontalDragUpdate: (d) => _handle(d.localPosition),
        onHorizontalDragEnd: (_) => _end(),
        child: CustomPaint(
          size: const Size(size, size),
          painter: _DialPainter(hourMode: hourMode, hour: hour, minute: minute, accent: accent),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final bool hourMode;
  final int hour;
  final int minute;
  final Color accent;

  _DialPainter({required this.hourMode, required this.hour, required this.minute, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width / 2, Paint()..color = kField);

    Offset pos(int idx, double r) {
      final a = idx * math.pi / 6;
      return Offset(c.dx + r * math.sin(a), c.dy - r * math.cos(a));
    }

    // Aguja y selección.
    Offset selPos;
    double selR;
    if (hourMode) {
      final outer = hour >= 1 && hour <= 12;
      selPos = pos(hour % 12, outer ? ClockDial.outerR : ClockDial.innerR);
      selR = outer ? 21 : 18;
    } else {
      final a = minute * math.pi / 30;
      selPos = Offset(c.dx + ClockDial.outerR * math.sin(a), c.dy - ClockDial.outerR * math.cos(a));
      selR = 21;
    }
    final hand = Paint()
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(c, selPos, hand);
    canvas.drawCircle(c, 5, Paint()..color = accent);
    canvas.drawCircle(selPos, selR, Paint()..color = accent);

    void label(String text, Offset at, bool selected, double fontSize) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: selected ? Colors.black : Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    if (hourMode) {
      for (var h = 0; h < 24; h++) {
        final outer = h >= 1 && h <= 12;
        label(pad2(h), pos(h % 12, outer ? ClockDial.outerR : ClockDial.innerR), h == hour, outer ? 15 : 13);
      }
    } else {
      for (var i = 0; i < 12; i++) {
        label(pad2(i * 5), pos(i, ClockDial.outerR), i * 5 == minute, 15);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.hourMode != hourMode || old.hour != hour || old.minute != minute || old.accent != accent;
}
