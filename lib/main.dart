import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notifications.dart';
import 'pages/calendar_page.dart';
import 'pages/stats_page.dart';
import 'pages/today_page.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final store = AppStore();
  await store.load();
  await Notifier.init();
  runApp(HorarioApp(store: store));
  Notifier.resync(store);
}

class HorarioApp extends StatelessWidget {
  final AppStore store;

  const HorarioApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = store.accentColor;
        return MaterialApp(
          title: 'Horario',
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
            colorScheme: ColorScheme.dark(
              primary: accent,
              onPrimary: Colors.black,
              secondary: accent,
              onSecondary: Colors.black,
              surface: const Color(0xFF0E0E0E),
              onSurface: Colors.white,
            ),
            textSelectionTheme: TextSelectionThemeData(cursorColor: accent),
            sliderTheme: SliderThemeData(
              activeTrackColor: accent,
              thumbColor: accent,
              inactiveTrackColor: const Color(0xFF2A2A2A),
              overlayColor: accent.withOpacity(0.15),
            ),
          ),
          home: HomePage(store: store),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final AppStore store;

  const HomePage({super.key, required this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Notifier.requestPermission());
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final accent = store.accentColor;
    Widget page;
    switch (_tab) {
      case 1:
        page = CalendarPage(key: const ValueKey('calendar'), store: store);
        break;
      case 2:
        page = StatsPage(key: const ValueKey('stats'), store: store);
        break;
      default:
        page = TodayPage(key: const ValueKey('today'), store: store, onGoToCalendar: () => setState(() => _tab = 1));
    }
    const names = ['Hoy', 'Semana', 'Estadísticas'];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: page,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
          ),
          child: Row(
            children: [
              for (var i = 0; i < names.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _tab == i ? accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          names[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _tab == i ? Colors.white : kGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
