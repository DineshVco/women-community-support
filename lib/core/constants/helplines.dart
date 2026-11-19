class Helpline {
  const Helpline({
    required this.name,
    required this.number,
    required this.description,
  });

  final String name;
  final String number;
  final String description;
}

/// Only the emergency number lives in code, so the "In danger right now?"
/// card works even if nothing else loads. Every other help line comes from
/// content/directory.json (see HelpLines), so the Care tab, Get help and
/// the Directory always show the same entries. A test checks that 999 here
/// matches the file.
class Helplines {
  Helplines._();

  static const Helpline emergency = Helpline(
    name: 'Emergency',
    number: '999',
    description:
        'Police, ambulance and fire. Use this if you are in danger now.',
  );
}
