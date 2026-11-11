import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../ui.dart';

/// Día a pantalla completa: bloques de color con altura proporcional a su duración.
class TodayPage extends StatefulWidget {
  final AppStore store;
  final VoidCallback onGoToCalendar;

  const TodayPage({super.key, required this.store, required this.onGoToCalendar});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  static const double _px = 1.2; // píxeles por minuto
  static const double _minBlock = 52;

  final ScrollController _scroll = ScrollController();
  final TextEditingController _taskCtl = TextEditingController();
  Timer? _timer;
  String _openTasks = '';
  String _openHours = '';
  String _remind = '';
  bool _settings = false;
  int _offset = 0;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _changed());
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToNow());
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    _timer?.cancel();
    _scroll.dispose();
    _taskCtl.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  DateTime get _day {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + _offset);
  }

  double _blockHeight(EventItem e) {
    final h = e.length * _px - 2;
    return h < _minBlock ? _minBlock : h;
  }

  void _jumpToNow() {
    if (!mounted || _offset != 0 || !_scroll.hasClients) return;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    double y = 0;
    int prevEnd = -1;
    for (final e in s.eventsOn(_day)) {
      if (prevEnd >= 0 && e.start > prevEnd) y += (e.start - prevEnd) * _px;
      if (nowMin < e.end) break;
      y += _blockHeight(e) + 2;
      if (e.end > prevEnd) prevEnd = e.end;
    }
    final max = _scroll.position.maxScrollExtent;
    final target = y - 12;
    _scroll.jumpTo(target < 0 ? 0 : (target > max ? max : target));
  }

  void _moveDay(int delta) {
    setState(() {
      _offset += delta;
      _openTasks = '';
      _openHours = '';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToNow());
  }

  Future<void> _pickRemind() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Avisar a las',
      cancelText: 'Sin aviso',
      confirmText: 'Aceptar',
    );
    if (!mounted) return;
    setState(() => _remind = t == null ? '' : '${pad2(t.hour)}:${pad2(t.minute)}');
  }

  void _addTask(EventItem e, String dk) {
    final text = _taskCtl.text.trim();
    if (text.isEmpty) return;
    s.addExtraTask(e, dk, text, _remind);
    _taskCtl.clear();
    setState(() => _remind = '');
  }

  @override
  Widget build(BuildContext context) {
    final accent = s.accentColor;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final day = _day;
    final dk = dateKey(day);
    final isToday = _offset == 0;
    final evs = s.eventsOn(day);

    double done = 0;
    for (final e in evs) {
      done += s.fraction(e, dk) ?? 0;
    }
    final pct = evs.isEmpty ? 0.0 : done / evs.length;

    final rows = <Widget>[];
    int prevEnd = -1;
    for (var i = 0; i < evs.length; i++) {
      final e = evs[i];
      final gap = (prevEnd >= 0 && e.start > prevEnd) ? (e.start - prevEnd) * _px : 0.0;
      if (e.end > prevEnd) prevEnd = e.end;
      final isNow = isToday && nowMin >= e.start && nowMin < e.end;
      rows.add(Padding(
        padding: EdgeInsets.only(top: gap, bottom: 2),
        child: SlideIn(
          key: ValueKey('$dk-${e.id}'),
          delayMs: i * 50 > 700 ? 700 : i * 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 2),
                  child: Text(fmtMin(e.start), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: kGrey)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _block(e, dk, isNow, accent)),
            ],
          ),
        ),
      ));
    }

    final title = isToday ? 'Hoy' : (_offset == -1 ? 'Ayer' : (_offset == 1 ? 'Mañana' : 'Día'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                label: title,
                title: '${kDays[day.weekday - 1]}, ${day.day} de ${kMonths[day.month - 1]}',
                accent: accent,
                actions: [
                  RoundIconButton(icon: Icons.chevron_left, tooltip: 'Día anterior', onTap: () => _moveDay(-1)),
                  const SizedBox(width: 6),
                  RoundIconButton(icon: Icons.chevron_right, tooltip: 'Día siguiente', onTap: () => _moveDay(1)),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Ajustes',
                    child: Material(
                      color: kField,
                      shape: const CircleBorder(side: BorderSide(color: kBorder)),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _settings = !_settings),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              FadePanel(open: _settings, child: _settingsPanel(accent)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF1C1C1C),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('${numText((done * 10).round() / 10)} de ${evs.length} eventos hechos', style: const TextStyle(fontSize: 13, color: kGrey)),
            ],
          ),
        ),
        Expanded(
          child: evs.isEmpty
              ? _empty(accent)
              : SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 4, 16, 24),
                  child: Column(children: rows),
                ),
        ),
      ],
    );
  }

  Widget _empty(Color accent) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No hay nada planificado para este día.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: kGrey, height: 1.4),
          ),
          const SizedBox(height: 16),
          Pill(label: 'Añadir eventos en Semana', selected: true, accent: accent, onTap: widget.onGoToCalendar, height: 48),
        ],
      ),
    );
  }

  Widget _settingsPanel(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Color secundario'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kAccentPalette)
                Semantics(
                  button: true,
                  label: 'Color',
                  child: GestureDetector(
                    onTap: () => s.setAccent(c),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: [BoxShadow(color: s.accent == c ? Colors.white : Colors.black, spreadRadius: 2)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Pill(
            label: 'Probar notificación',
            selected: false,
            accent: accent,
            onTap: () async {
              await Notifier.requestPermission();
              final ok = await Notifier.test();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Aviso de prueba enviado.' : 'No se ha podido enviar. Revisa el permiso de notificaciones.'),
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _block(EventItem e, String dk, bool isNow, Color accent) {
    final color = s.colorOf(e);
    final ink = inkOn(color);
    final key = s.evKey(dk, e);
    final status = s.log[key] ?? '';
    final tasks = s.tasksOf(e, dk);
    final tasksDone = tasks.where((t) => s.isTaskDone(dk, t)).length;
    final isNo = !e.byHours && status == 'no';

    var meta = '${fmtMin(e.start)} – ${fmtMin(e.end)} · ${durText(e.length)}';
    if (tasks.isNotEmpty) meta += ' · $tasksDone/${tasks.length} tareas';
    final h = s.hours[key];
    if (e.byHours) {
      final f = s.fraction(e, dk) ?? 0;
      meta += ' · ${(f * 100).round()}% de ${numText(e.minH)} h mín.';
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isNo ? 0.45 : 1,
      child: Container(
        constraints: BoxConstraints(minHeight: _blockHeight(e)),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isNow
              ? const [BoxShadow(color: Colors.white, spreadRadius: 4), BoxShadow(color: Colors.black, spreadRadius: 2)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() {
                        _openTasks = _openTasks == e.id ? '' : e.id;
                        _taskCtl.clear();
                        _remind = '';
                      }),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    e.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: ink,
                                      decoration: isNo ? TextDecoration.lineThrough : TextDecoration.none,
                                      decorationColor: ink,
                                    ),
                                  ),
                                ),
                                if (isNow) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                    decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(8)),
                                    child: Text('Ahora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (e.byHours)
                    Material(
                      color: const Color(0xD9000000),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _openHours = _openHours == e.id ? '' : e.id),
                        child: Container(
                          height: 44,
                          constraints: const BoxConstraints(minWidth: 64),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              h == null ? 'Horas' : '${numText(h)} h',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    _markButton(
                      icon: Icons.check_rounded,
                      tooltip: 'Hecho',
                      selected: status == 'done',
                      on: const Color(0xFF4ADE80),
                      off: const Color(0xD1062814),
                      onTap: () => s.toggleStatus(e, dk, 'done'),
                    ),
                    const SizedBox(width: 6),
                    _markButton(
                      icon: Icons.close_rounded,
                      tooltip: 'No hecho',
                      selected: status == 'no',
                      on: const Color(0xFFF87171),
                      off: const Color(0xD1340A0C),
                      onTap: () => s.toggleStatus(e, dk, 'no'),
                    ),
                  ],
                ],
              ),
            ),
            FadePanel(open: e.byHours && _openHours == e.id, child: _hoursPanel(e, dk, h)),
            FadePanel(open: _openTasks == e.id, child: _tasksPanel(e, dk, tasks, accent)),
          ],
        ),
      ),
    );
  }

  Widget _markButton({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required Color on,
    required Color off,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? on : off,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: selected ? Colors.black : on)),
        ),
      ),
    );
  }

  Widget _panelShell({required String title, required VoidCallback onClose, Widget? trailing, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 6),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 12),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGrey)),
              const Spacer(),
              if (trailing != null) trailing,
              IconButton(
                tooltip: 'Cerrar',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }

  Widget _hoursPanel(EventItem e, String dk, double? h) {
    final max = e.minH <= 0 ? 1.0 : e.minH;
    final value = (h ?? 0).clamp(0.0, max).toDouble();
    final divisions = (max * 4).round();
    return _panelShell(
      title: 'Horas hechas',
      onClose: () => setState(() => _openHours = ''),
      trailing: Text('${numText(value)} h', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      children: [
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: divisions < 1 ? 1 : divisions,
          onChanged: (v) => s.setHours(e, dk, (v * 4).round() / 4),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0 h', style: TextStyle(fontSize: 12, color: kGrey)),
            Text('${numText(max)} h', style: const TextStyle(fontSize: 12, color: kGrey)),
          ],
        ),
      ],
    );
  }

  Widget _tasksPanel(EventItem e, String dk, List<TaskItem> tasks, Color accent) {
    final extraIds = (s.extra[s.evKey(dk, e)] ?? const <TaskItem>[]).map((t) => t.id).toSet();
    return _panelShell(
      title: 'Tareas',
      onClose: () => setState(() => _openTasks = ''),
      children: [
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin tareas todavía.', style: TextStyle(fontSize: 13, color: kGrey)),
          ),
        for (final t in tasks) _taskRow(e, dk, t, accent, extraIds.contains(t.id)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskCtl,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration('Añadir tarea'),
                onSubmitted: (_) => _addTask(e, dk),
              ),
            ),
            const SizedBox(width: 6),
            Pill(label: _remind.isEmpty ? 'Aviso' : _remind, selected: _remind.isNotEmpty, accent: accent, onTap: _pickRemind),
            const SizedBox(width: 6),
            RoundIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Añadir tarea',
              background: accent,
              foreground: Colors.black,
              radius: 12,
              onTap: () => _addTask(e, dk),
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskRow(EventItem e, String dk, TaskItem t, Color accent, bool isExtra) {
    final done = s.isTaskDone(dk, t);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => s.toggleTask(dk, t),
      onLongPress: isExtra ? () => s.removeExtraTask(e, dk, t) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: done ? accent : const Color(0xFF6A6A6A), width: 2),
              ),
              child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.black) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.text,
                style: TextStyle(
                  fontSize: 15,
                  color: done ? kGrey : Colors.white,
                  decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: kGrey,
                ),
              ),
            ),
            if (t.remind.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
                child: Text('Aviso ${t.remind}', style: const TextStyle(fontSize: 12, color: kGrey)),
              ),
          ],
        ),
      ),
    );
  }
}
