# Horario

App de gestión de horas diarias (Flutter, Android). Planificas la semana con eventos, cada evento puede llevar una lista de tareas, la app avisa cuando empieza cada evento y guarda estadísticas de lo que cumples.

## Instalar en el móvil

1. Desde el móvil, abre la [última versión](https://github.com/Samix453/AppHorario/releases/latest) y descarga `AppHorario.apk`.
   Enlace directo: https://github.com/Samix453/AppHorario/releases/latest/download/AppHorario.apk
2. Abre el archivo y acepta instalar apps desde el navegador si Android lo pide.
3. Al abrir la app, acepta el permiso de notificaciones.

Cada cambio que se sube a `main` compila un APK nuevo y lo publica como versión (pestaña **Releases**). Las versiones nuevas se instalan encima de la anterior sin perder los datos.

### Para que los avisos lleguen siempre (Xiaomi / POCO)

HyperOS cierra las apps en segundo plano. En Ajustes → Aplicaciones → Horario:

- activa **Inicio automático**;
- en **Ahorro de batería**, elige **Sin restricciones**.

Dentro de la app, el botón redondo de arriba a la derecha en **Hoy** abre los ajustes: color secundario y **Probar notificación**.

## Qué hace

- **Hoy**: el día a pantalla completa, con cada evento como un bloque de su color y de alto proporcional a lo que dura. Check / No, o apuntar horas con un mínimo. Tareas dentro de cada evento; puedes añadir tareas sobre la marcha con hora de aviso (mantén pulsada una de esas para borrarla). Las flechas cambian de día.
- **Semana**: rejilla de 24 h para editar la semana tipo, y vista de **Mes** para eventos puntuales.
- **Estadísticas**: % de eventos cumplidos, horas hechas, % de tareas, por día, por categoría y por evento.
- **Avisos**: al empezar cada evento y, si quieres, unos minutos antes.

Los datos se guardan solo en el móvil.

## Desarrollo

La carpeta `android/` no está en el repositorio: se genera.

```
flutter create --platforms=android --org com.samix --project-name app_horario .
dart run tool/patch_android.dart
flutter run
```

Compilado con Flutter 3.24.5 (ver `.github/workflows/build.yml`).

### Sobre la firma

`tool/apphorario.p12` es la clave con la que se firman los APK, y su contraseña está en el workflow. Como el repositorio es público, la clave también lo es: sirve para que las actualizaciones se instalen encima, no como medida de seguridad. No instales un `AppHorario.apk` que no venga de este repositorio.
