/// A predefined goal category with a display label and emoji.
/// `value` is the string persisted to the backend `type` field.
class GoalType {
  const GoalType(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;
}

const goalTypes = <GoalType>[
  GoalType('emergency_fund', 'Fondo de emergencia', '🛟'),
  GoalType('savings', 'Ahorro', '💰'),
  GoalType('travel', 'Viaje', '✈️'),
  GoalType('house', 'Casa', '🏠'),
  GoalType('car', 'Auto', '🚗'),
  GoalType('education', 'Educación', '🎓'),
  GoalType('retirement', 'Retiro', '🌴'),
  GoalType('other', 'Otro', '🎯'),
];

/// Returns the GoalType for [value], falling back to the last entry ("Otro").
GoalType goalTypeFor(String value) =>
    goalTypes.firstWhere((t) => t.value == value, orElse: () => goalTypes.last);
