import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui.dart';
import 'event_editor.dart';

/// Editor semanal (rejilla de 24 h) y vista de mes.
class CalendarPage extends StatefulWidget {
  final AppStore store;

  const CalendarPage({super.key, required this.store});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const double _hourH = 44;

  late final ScrollController _weekScroll = ScrollController(initialScrollOffset: _hourH * 6.5);
  Timer? _timer;
  bool _month = false;
  int _weekOffset = 0;
  int _monthOffset = 0;
  String _selDate = dateKey(DateTime.now());

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _changed());
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    _timer?.cancel();
    _weekScroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _newEvent() {
    openEventEditor(context, s, presetDate: _month ? _selDate : null);
  }

  @override
  Widget build(BuildContext context) {
    final accent = s.accentColor;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1) + _weekOffset * 7);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final monthFirst = DateTime(now.year, now.month + _monthOffset, 1);

    final weekTitle = monday.month == sunday.month
        ? '${monday.day} – ${sunday.day} ${kMonths[sunday.month - 1].substring(0, 3)}'
        : '${monday.day} ${kMonths[monday.month - 1].substring(0, 3)} – ${sunday.day} ${kMonths[sunday.month - 1].substring(0, 3)}';
    final monthTitle = '${capitalize(kMonths[monthFirst.month - 1])} ${monthFirst.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
          child: PageHeader(
            label: _month ? 'Mes' : 'Semana',
            title: _month ? monthTitle : weekTitle,
            accent: accent,
            actions: [
              RoundIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Anterior',
                onTap: () => setState(() => _month ? _monthOffset-- : _weekOffset--),
              ),
              const SizedBox(width: 6),
              RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Siguiente',
                onTap: () => setState(() => _month ? _monthOffset++ : _weekOffset++),
              ),
              const SizedBox(width: 6),
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Nuevo evento',
                background: accent,
                foreground: Colors.black,
                onTap: _newEvent,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Expanded(child: Pill(label: 'Semana', selected: !_month, accent: accent, onTap: () => setState(() => _month = false))),
              const SizedBox(width: 6),
              Expanded(child: Pill(label: 'Mes', selected: _month, accent: accent, onTap: () => setState(() => _month = true))),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _month
                ? KeyedSubtree(key: const ValueKey('month'), child: _monthView(monthFirst, accent))
                : KeyedSubtree(key: const ValueKey('week'), child: _weekView(monday, now, accent)),
          ),
        ),
      ],
    );
  }

  // ---------- Semana ----------

  Widget _weekView(DateTime monday, DateTime now, Color accent) {
    final todayKey = dateKey(now);
    final nowTop = (now.hour * 60 + now.minute) / 60 * _hourH;
    final days = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 8, 6),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(kLetters[i], style: const TextStyle(fontSize: 11, color: kGrey)),
                      const SizedBox(height: 2),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: dateKey(days[i]) == todayKey ? accent : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${days[i].day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: dateKey(days[i]) == todayKey ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _weekScroll,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: SizedBox(
              height: _hourH * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Stack(
                      children: [
                        for (var h = 0; h < 24; h++)
                          Positioned(
                            top: h * _hourH + 2,
                            left: 0,
                            child: Text(pad2(h), style: const TextStyle(fontSize: 10, color: kGrey)),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      painter: _GridPainter(_hourH),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(child: _dayColumn(days[i], dateKey(days[i]) == todayKey, nowTop)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayColumn(DateTime d, bool isToday, double nowTop) {
    final evs = s.eventsOn(d);
    return Stack(
      children: [
        for (final e in evs) _weekBlock(e, d),
        if (isToday)
          Positioned(
            top: nowTop,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Container(height: 2, color: Colors.white)),
          ),
      ],
    );
  }

  Widget _weekBlock(EventItem e, DateTime d) {
    final color = s.colorOf(e);
    final ink = inkOn(color);
    final h = e.length / 60 * _hourH - 1;
    final height = h < 6 ? 6.0 : h;
    return Positioned(
      top: e.start / 60 * _hourH,
      left: 1,
      right: 1,
      height: height,
      child: Semantics(
        button: true,
        label: '${e.title}, ${fmtMin(e.start)} a ${fmtMin(e.end)}',
        child: GestureDetector(
          onTap: () => openEventEditor(context, s, event: e),
          child: Container(
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.fromLTRB(3, 2, 2, 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: e.isOnce ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: height >= 16
                ? Text(
                    e.title,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 9, height: 1.15, fontWeight: FontWeight.w600, color: ink),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // ---------- Mes ----------

  Widget _monthView(DateTime first, Color accent) {
    final todayKey = dateKey(DateTime.now());
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1;
    final sel = parseKey(_selDate);
    final selEvents = s.eventsOn(sel);

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var dn = 1; dn <= daysInMonth; dn++) _monthCell(DateTime(first.year, first.month, dn), todayKey, accent),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final l in kLetters)
                Expanded(child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kGrey))),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 1,
            padding: EdgeInsets.zero,
            children: cells,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${kDays[sel.weekday - 1]}, ${sel.day} de ${kMonths[sel.month - 1]}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (selEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Nada planificado este día.', style: TextStyle(fontSize: 13, color: kGrey)),
            ),
          for (final e in selEvents) _monthRow(e),
          const SizedBox(height: 8),
          Pill(label: 'Añadir evento este día', selected: true, accent: accent, onTap: _newEvent, height: 48),
        ],
      ),
    );
  }

  Widget _monthCell(DateTime d, String todayKey, Color accent) {
    final k = dateKey(d);
    final isSel = k == _selDate;
    final isToday = k == todayKey;
    final dots = s.events.where((e) => e.date == k).take(3).toList();
    return Semantics(
      button: true,
      label: '${d.day} de ${kMonths[d.month - 1]}',
      child: GestureDetector(
        onTap: () => setState(() => _selDate = k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSel ? accent : kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isToday ? Colors.white : (isSel ? accent : const Color(0xFF1C1C1C))),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${d.day}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSel ? Colors.black : Colors.white),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in dots)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: s.colorOf(e),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthRow(EventItem e) {
    final color = s.colorOf(e);
    final ink = inkOn(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openEventEditor(context, s, event: e),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${fmtMin(e.start)} – ${fmtMin(e.end)}', style: TextStyle(fontSize: 12, color: ink)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(border: Border.all(color: ink), borderRadius: BorderRadius.circular(8)),
                  child: Text(e.isOnce ? 'Puntual' : 'Semanal', style: TextStyle(fontSize: 11, color: ink)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double hourH;

  _GridPainter(this.hourH);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      final y = h * hourH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final col = Paint()
      ..color = const Color(0xFF141414)
      ..strokeWidth = 1;
    final w = size.width / 7;
    for (var i = 0; i <= 7; i++) {
      canvas.drawLine(Offset(i * w, 0), Offset(i * w, size.height), col);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.hourH != hourH;
}
