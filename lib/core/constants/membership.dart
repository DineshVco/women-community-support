/// Who can join Looma.
class Membership {
  Membership._();

  /// Minimum age to join. Change it here only; firestore.rules has a
  /// matching (year-based) check, so update that number too.
  static const int minimumAge = 18;

  /// Age in whole years on [today] for someone born on [birthday].
  static int ageOn(DateTime birthday, DateTime today) {
    var age = today.year - birthday.year;
    final hadBirthdayThisYear =
        today.month > birthday.month ||
        (today.month == birthday.month && today.day >= birthday.day);
    if (!hadBirthdayThisYear) age--;
    return age;
  }

  static bool isOldEnough(DateTime birthday, DateTime today) =>
      ageOn(birthday, today) >= minimumAge;
}
