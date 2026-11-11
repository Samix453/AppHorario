// Ajusta el proyecto Android que genera `flutter create` para esta app:
// permisos y receptores de notificaciones, desugaring, firma estable e icono.
//
// Uso (desde la raíz del proyecto):
//   flutter create --platforms=android --org com.samix --project-name app_horario .
//   dart run tool/patch_android.dart
import 'dart:io';

const _permissions = '''
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
''';

const _receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';

const _groovySigning = r'''
    signingConfigs {
        release {
            storeFile file("apphorario.p12")
            storePassword System.getenv("KEYSTORE_PASS") ?: ""
            keyAlias "apphorario"
            keyPassword System.getenv("KEYSTORE_PASS") ?: ""
            storeType "pkcs12"
        }
    }

''';

const _groovyRelease = r'''signingConfig = file("apphorario.p12").exists() ? signingConfigs.release : signingConfigs.debug
            minifyEnabled = false
            shrinkResources = false''';

const _groovyDeps = r'''

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.0.4"
}
''';

const _ktsSigning = r'''
    signingConfigs {
        create("release") {
            storeFile = file("apphorario.p12")
            storePassword = System.getenv("KEYSTORE_PASS") ?: ""
            keyAlias = "apphorario"
            keyPassword = System.getenv("KEYSTORE_PASS") ?: ""
            storeType = "pkcs12"
        }
    }

''';

const _ktsRelease = r'''signingConfig = if (file("apphorario.p12").exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false''';

const _ktsDeps = r'''

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
''';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('No existe android/. Ejecuta antes: flutter create --platforms=android --org com.samix --project-name app_horario .');
    exit(1);
  }

  var m = manifest.readAsStringSync();
  if (!m.contains('POST_NOTIFICATIONS')) {
    m = m.replaceFirst('<application', '$_permissions    <application');
    m = m.replaceFirst('</application>', '$_receivers    </application>');
  }
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Horario"');
  manifest.writeAsStringSync(m);
  stdout.writeln('AndroidManifest.xml ajustado.');

  final groovy = File('android/app/build.gradle');
  final kts = File('android/app/build.gradle.kts');
  if (groovy.existsSync()) {
    var g = groovy.readAsStringSync();
    if (!g.contains('coreLibraryDesugaring')) {
      g = g.replaceFirst(RegExp(r'compileOptions\s*\{'), 'compileOptions {\n        coreLibraryDesugaringEnabled true');
      g = g.replaceFirst(RegExp(r'defaultConfig\s*\{'), 'defaultConfig {\n        multiDexEnabled true');
      g = g.replaceFirst(RegExp(r'\n(\s*)buildTypes\s*\{'), '\n$_groovySigning    buildTypes {');
      g = g.replaceFirst(RegExp(r'signingConfig\s*=?\s*signingConfigs\.debug'), _groovyRelease);
      g = '$g$_groovyDeps';
      groovy.writeAsStringSync(g);
    }
    stdout.writeln('android/app/build.gradle ajustado.');
  } else if (kts.existsSync()) {
    var g = kts.readAsStringSync();
    if (!g.contains('coreLibraryDesugaring')) {
      g = g.replaceFirst(RegExp(r'compileOptions\s*\{'), 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
      g = g.replaceFirst(RegExp(r'defaultConfig\s*\{'), 'defaultConfig {\n        multiDexEnabled = true');
      g = g.replaceFirst(RegExp(r'\n(\s*)buildTypes\s*\{'), '\n$_ktsSigning    buildTypes {');
      g = g.replaceFirst(RegExp(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'), _ktsRelease);
      g = '$g$_ktsDeps';
      kts.writeAsStringSync(g);
    }
    stdout.writeln('android/app/build.gradle.kts ajustado.');
  } else {
    stderr.writeln('No se ha encontrado android/app/build.gradle(.kts).');
    exit(1);
  }

  // Icono de la app.
  final res = Directory('tool/android_res');
  if (res.existsSync()) {
    for (final f in res.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(res.path.length + 1);
      final target = File('android/app/src/main/res/$rel');
      target.parent.createSync(recursive: true);
      f.copySync(target.path);
    }
    stdout.writeln('Icono copiado.');
  }

  // Almacén de claves para que todas las versiones compartan la misma firma.
  final ks = File('tool/apphorario.p12');
  if (ks.existsSync()) {
    ks.copySync('android/app/apphorario.p12');
    stdout.writeln('Firma copiada.');
  }
}
