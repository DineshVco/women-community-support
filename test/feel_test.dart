import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/constants/daily_questions.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/core/theme/app_motion.dart';
import 'package:women_community_support/core/utils/greeting.dart';

void main() {
  group('greetingFor', () {
    test('matches the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 21, 59)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 22)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 5)), 'Good morning');
    });
  });

  group('countRecent', () {
    test('counts only the last 24 hours', () {
      final now = DateTime(2026, 3, 20, 12);
      final times = [
        now.subtract(const Duration(minutes: 5)),
        now.subtract(const Duration(hours: 23)),
        now.subtract(const Duration(hours: 25)),
      ];
      expect(countRecent(times, now: now), 2);
    });
  });

  group('DailyQuestions (content/daily_questions.json)', () {
    final all =
        ContentLibrary.parse(
          guidesJson: File('content/guides.json').readAsStringSync(),
          directoryJson: File('content/directory.json').readAsStringSync(),
          dailyQuestionsJson:
              File('content/daily_questions.json').readAsStringSync(),
        ).dailyQuestions;

    test('has 30 questions that are all valid post titles', () {
      expect(all, hasLength(30));
      expect(all.toSet(), hasLength(30));
      for (final q in all) {
        expect(q.length, inInclusiveRange(3, 120), reason: q);
      }
    });

    test('changes daily and repeats every 30 days', () {
      expect(DailyQuestions.forDate(all, DateTime(2026, 1, 1)), all[0]);
      expect(DailyQuestions.forDate(all, DateTime(2026, 1, 2)), all[1]);
      expect(DailyQuestions.forDate(all, DateTime(2026, 1, 31)), all[0]);
    });

    test('is the same all day long', () {
      expect(
        DailyQuestions.forDate(all, DateTime(2026, 5, 4, 0, 1)),
        DailyQuestions.forDate(all, DateTime(2026, 5, 4, 23, 59)),
      );
    });

    test('no questions: no card', () {
      expect(DailyQuestions.forDate(const [], DateTime(2026, 5, 4)), isNull);
    });
  });

  group('SpringCurve', () {
    for (final entry
        in {
          'spring': AppMotion.spring,
          'springPop': AppMotion.springPop,
        }.entries) {
      test('${entry.key} starts at 0, ends at 1 with no visible jump', () {
        final curve = entry.value;
        expect(curve.transform(0), 0);
        expect(curve.transform(1), 1);
        // Settled just before the end, so finishing at exactly 1 is invisible.
        expect(curve.transform(0.99), closeTo(1, 0.005));
        // Overshoots a little, never a lot.
        var peak = 0.0;
        for (var i = 0; i <= 100; i++) {
          final v = curve.transform(i / 100);
          if (v > peak) peak = v;
        }
        expect(peak, lessThan(1.15));
      });
    }
  });
}
