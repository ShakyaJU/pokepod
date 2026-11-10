import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android's Auto Backup is the only thing that can put first-run state onto
/// a brand-new install without the app ever writing it there.
///
/// SharedPreferences is a single file (`FlutterSharedPreferences.xml`), so a
/// restore brings the `onboarding.v1` and `notifications.v1` completion flags
/// back together with the progress keys. `firstLaunch` is then false before
/// the app's first run and both first-install screens are skipped — with
/// nothing in Dart to blame and nothing logged, because no Dart code ever
/// wrote those keys.
///
/// The Help guide promises the opposite anyway: progress "does not sync to
/// the cloud", and uninstalling "permanently erases local progress". These
/// tests pin the manifest that keeps that promise, the same way
/// `notification_android_test.dart` pins the receivers no widget test can
/// reach: the backup framework is not executable from a test host either.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml');

  group('Android backup is opted out', () {
    test('the manifest does not let the app take part', () {
      final xml = manifest.readAsStringSync();

      expect(
        xml,
        contains('android:allowBackup="false"'),
        reason:
            'allowBackup defaults to true when the attribute is absent, and '
            'that default is exactly what let a restored SharedPreferences '
            'file skip the introduction and the notification explanation on '
            'an install with no history of its own',
      );
    });

    test('points Android 12+ at rules of its own', () {
      final xml = manifest.readAsStringSync();

      expect(
        xml,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        reason:
            'allowBackup is deprecated from Android 12 and dataExtractionRules '
            'is what that version actually reads, so without it the opt-out '
            'would stop applying on the newest devices',
      );
    });

    test('cloud backup cannot restore SharedPreferences', () {
      expect(
        rules.existsSync(),
        isTrue,
        reason:
            'the manifest references this file; a missing resource fails '
            'the build rather than quietly re-enabling backup',
      );

      final cloud = RegExp(
        '<cloud-backup>.*?</cloud-backup>',
        multiLine: true,
        dotAll: true,
      ).firstMatch(rules.readAsStringSync());

      expect(
        cloud,
        isNotNull,
        reason:
            'a rules file with no <cloud-backup> section leaves cloud '
            'restore running against the default behaviour',
      );
      expect(
        cloud!.group(0),
        contains('<exclude domain="sharedpref" path="."/>'),
        reason:
            'sharedpref holds every completion flag and all progress in one '
            'file, so excluding it is what keeps a restored install from '
            'looking like a returning user',
      );
    });

    test('device-to-device transfer cannot restore SharedPreferences', () {
      final transfer = RegExp(
        '<device-transfer>.*?</device-transfer>',
        multiLine: true,
        dotAll: true,
      ).firstMatch(rules.readAsStringSync());

      expect(
        transfer,
        isNotNull,
        reason:
            'cloud backup and device transfer are separate paths — OEM '
            'migrations such as Smart Switch use this one, so excluding only '
            'the cloud would leave the original bug reachable',
      );
      expect(
        transfer!.group(0),
        contains('<exclude domain="sharedpref" path="."/>'),
        reason:
            'the same SharedPreferences file arrives through this path '
            'and must be excluded here too',
      );
    });
  });
}
