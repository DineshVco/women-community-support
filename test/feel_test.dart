import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/constants/daily_questions.dart';
import 'package:women_community_support/core/theme/app_motion.dart';
import 'package:women_community_support/core/utils/greeting.dart';

void main() {
  group('greetingFor', () {
    test('matches the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 21, 59)), 'Good evening');
      expect(
        greetingFor(DateTime(2026, 1, 1, 22)),
        'Take a breath, it is late',
      );
      expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Take a breath, it is late');
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

  group('DailyQuestions', () {
    test('has 30 questions that are all valid post titles', () {
      expect(DailyQuestions.all, hasLength(30));
      expect(DailyQuestions.all.toSet(), hasLength(30));
      for (final q in DailyQuestions.all) {
        expect(q.length, inInclusiveRange(3, 120), reason: q);
      }
    });

    test('changes daily and repeats every 30 days', () {
      final jan1 = DateTime(2026, 1, 1);
      expect(DailyQuestions.forDate(jan1), DailyQuestions.all[0]);
      expect(
        DailyQuestions.forDate(DateTime(2026, 1, 2)),
        DailyQuestions.all[1],
      );
      expect(
        DailyQuestions.forDate(DateTime(2026, 1, 31)),
        DailyQuestions.all[0],
      );
    });

    test('is the same all day long', () {
      expect(
        DailyQuestions.forDate(DateTime(2026, 5, 4, 0, 1)),
        DailyQuestions.forDate(DateTime(2026, 5, 4, 23, 59)),
      );
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
