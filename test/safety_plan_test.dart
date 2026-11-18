import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/safety_plan.dart';
import 'package:women_community_support/presentation/screens/me/safety_plan_screen.dart';

const _plan = SafetyPlan(
  contacts: [
    SafeContact(name: 'Aunty Rose', number: '012-345 6789', anytime: true),
  ],
  safePlace: 'My sister in Shah Alam',
  codeWord: 'pineapple',
  ready: {'id', 'charger'},
  notes: 'Spare key under the blue pot',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SafetyPlanStore', () {
    test('saves and loads the whole plan', () async {
      final store = SafetyPlanStore(MemorySecureStore());
      await store.save(_plan);
      final loaded = await store.load();

      expect(loaded.contacts.single.name, 'Aunty Rose');
      expect(loaded.contacts.single.anytime, isTrue);
      expect(loaded.safePlace, 'My sister in Shah Alam');
      expect(loaded.codeWord, 'pineapple');
      expect(loaded.ready, {'id', 'charger'});
      expect(loaded.notes, 'Spare key under the blue pot');
    });

    test('what is stored is encrypted (no readable words)', () async {
      final secure = MemorySecureStore();
      await SafetyPlanStore(secure).save(_plan);
      final stored = secure.values[SafetyPlanStore.dataKey]!;
      for (final word in ['Aunty', 'Rose', 'pineapple', 'Shah Alam', '012']) {
        expect(stored, isNot(contains(word)));
      }
      // The key is separate, and random.
      expect(secure.values[SafetyPlanStore.keyKey], isNotNull);
    });

    test('it is never written anywhere but secure storage', () async {
      final secure = MemorySecureStore();
      await SafetyPlanStore(secure).save(_plan);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(secure.values.keys, {
        SafetyPlanStore.dataKey,
        SafetyPlanStore.keyKey,
      });
    });

    test('"Clear my plan" deletes the plan and its key', () async {
      final secure = MemorySecureStore();
      final store = SafetyPlanStore(secure);
      await store.save(_plan);
      await store.clear();
      expect(secure.values, isEmpty);
      expect((await store.load()).isEmpty, isTrue);
    });

    test('an empty phone gives an empty plan', () async {
      final plan = await SafetyPlanStore(MemorySecureStore()).load();
      expect(plan.isEmpty, isTrue);
    });
  });

  group('SafetyPlanScreen', () {
    Future<SafetyPlanStore> pump(
      WidgetTester tester, {
      SafetyPlan? saved,
    }) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = SafetyPlanStore(MemorySecureStore());
      if (saved != null) await store.save(saved);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SafetyPlanScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('says clearly it stays on this phone, and is not 999', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(SafetyPlanScreen.onlyOnPhone), findsOneWidget);
      expect(find.text(SafetyPlanScreen.footer), findsOneWidget);
      for (final section in [
        'Safe contacts',
        'A safe place I can go',
        'A code word to tell a friend',
        'Things to keep ready',
        'Notes',
      ]) {
        expect(find.text(section), findsOneWidget);
      }
      for (final (_, label) in SafetyPlan.readyItems) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows a saved plan', (tester) async {
      await pump(tester, saved: _plan);
      expect(find.text('Aunty Rose'), findsOneWidget);
      expect(find.text('012-345 6789 · can call anytime'), findsOneWidget);
      expect(find.text('pineapple'), findsOneWidget);
    });

    testWidgets('adding a contact and ticking items saves on the phone', (
      tester,
    ) async {
      final store = await pump(tester);

      await tester.tap(find.text('Add a contact'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Mira');
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone number'),
        '011-222 3333',
      );
      await tester.tap(find.text('Can be called anytime'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Money'));
      await tester.pump(const Duration(milliseconds: 700)); // autosave
      await tester.pumpAndSettle();

      final saved = await store.load();
      expect(saved.contacts.single.name, 'Mira');
      expect(saved.contacts.single.anytime, isTrue);
      expect(saved.ready, {'money'});
      expect(find.text('Saved on this phone'), findsOneWidget);
    });

    testWidgets('"Clear my plan" asks first, then deletes it', (tester) async {
      final store = await pump(tester, saved: _plan);

      await tester.tap(find.text('Clear my plan'));
      await tester.pumpAndSettle();
      expect(find.text('Clear your plan?'), findsOneWidget);
      // The dialog's button (the page also has one with the same words).
      await tester.tap(find.text('Clear my plan').last);
      await tester.pumpAndSettle();

      expect((await store.load()).isEmpty, isTrue);
      expect(find.text('Aunty Rose'), findsNothing);
      expect(find.text('Your plan was cleared'), findsOneWidget);

      // Emptying the fields must not autosave an empty plan back.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Your plan was cleared'), findsOneWidget);
      expect(find.text('Saved on this phone'), findsNothing);
    });
  });
}
