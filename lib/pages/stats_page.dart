import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui.dart';

/// Gráficas y datos de cumplimiento de eventos y tareas.
class StatsPage extends StatefulWidget {
  final AppStore store;

  const StatsPage({super.key, required this.store});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _range = 7;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String _pct(double? v) => v == null ? '–' : '${(v * 100).round()}%';

  String _hours(int minutes) => '${numText((minutes / 6).round() / 10)} h';

  @override
  Widget build(BuildContext context) {
    final accent = s.accentColor;
    final st = s.computeStats(_range);
    final hasData = st.answered > 0 || st.tasksTotal > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
          child: PageHeader(label: 'Estadísticas', title: 'Últimos $_range días', accent: accent),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (final r in const [7, 30, 90]) ...[
                if (r != 7) const SizedBox(width: 6),
                Expanded(child: Pill(label: '$r días', selected: _range == r, accent: accent, onTap: () => setState(() => _range = r))),
              ],
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !hasData
                ? const Padding(
                    key: ValueKey('empty'),
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                        'Todavía no hay registros. Marca eventos y tareas en Hoy y aquí verás tus datos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: kGrey, height: 1.4),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    key: ValueKey('data-$_range'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _tile(_pct(st.answered == 0 ? null : st.done / st.answered), 'Eventos cumplidos', accent)),
                            const SizedBox(width: 8),
                            Expanded(child: _tile(_hours(st.minutes), 'Horas hechas', Colors.white)),
                            const SizedBox(width: 8),
                            Expanded(child: _tile(_pct(st.tasksTotal == 0 ? null : st.tasksDone / st.tasksTotal), 'Tareas hechas', Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Cumplimiento por día', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        _dayChart(st.days, accent),
                        if (st.byCat.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('Por categoría', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          for (final r in st.byCat) _catRow(r),
                        ],
                        if (st.byEvent.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Por evento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF222222)),
                            ),
                            child: Column(children: [for (final r in st.byEvent) _eventRow(r)]),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Veces hecho de veces registradas, porcentaje y horas totales.',
                            style: TextStyle(fontSize: 12, color: kGrey),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _tile(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
        ],
      ),
    );
  }

  Widget _dayChart(List<DayBar> days, Color accent) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_pct(days[i].pct), style: const TextStyle(fontSize: 10, color: kGrey)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 2, end: days[i].pct == null ? 2 : 4 + days[i].pct! * 64),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    builder: (context, h, _) => Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: days[i].today ? accent : const Color(0xFF5A5A5A),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(days[i].letter, style: const TextStyle(fontSize: 11, color: kGrey)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _catRow(StatRow r) {
    // Un gris muy oscuro no se vería sobre negro: se aclara solo para la barra.
    final barColor = r.color.computeLuminance() < 0.08 ? const Color(0xFF8A8A8A) : r.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: barColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
              Text('${_pct(r.pct)} · ${_hours(r.minutes)}', style: const TextStyle(fontSize: 13, color: kGrey)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: r.pct ?? 0,
              minHeight: 6,
              backgroundColor: const Color(0xFF1C1C1C),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventRow(StatRow r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
      child: Row(
        children: [
          Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 10),
          Text('${numText((r.done * 10).round() / 10)}/${r.total}', style: const TextStyle(fontSize: 13, color: kGrey)),
          SizedBox(
            width: 48,
            child: Text(_pct(r.pct), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 56,
            child: Text(_hours(r.minutes), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: kGrey)),
          ),
        ],
      ),
    );
  }
}
