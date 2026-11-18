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

/// IMPORTANT: confirm every number on the organisation's official website
/// before the demo. Numbers change, and this app must never show a wrong one.
class Helplines {
  Helplines._();

  static const Helpline emergency = Helpline(
    name: 'Emergency',
    number: '999',
    description: 'Police, ambulance and fire. Use this if you are in danger now.',
  );

  static const List<Helpline> support = [
    Helpline(
      name: 'Talian Kasih',
      number: '15999',
      description: 'Government helpline for abuse and welfare cases.',
    ),
    Helpline(
      name: 'Befrienders Kuala Lumpur',
      number: '03-7627 2929',
      description:
          'Emotional support, including if you are having thoughts of suicide.',
    ),
    Helpline(
      name: 'Women’s Aid Organisation (WAO)',
      number: '03-3000 8858',
      description: 'Support for women facing abuse or violence.',
    ),
  ];
}
