class MembershipPlan {
  final String id;
  final String name;
  final int durationDays;

  const MembershipPlan({
    required this.id,
    required this.name,
    required this.durationDays,
  });
}

class MembershipPlans {
  static const List<MembershipPlan> plans = [
  MembershipPlan(id: 'day', name: 'Day Pass', durationDays: 1),
  MembershipPlan(id: 'week1', name: '1 Week', durationDays: 7),
  MembershipPlan(id: 'week2', name: '2 Weeks', durationDays: 14),
  MembershipPlan(id: 'month1', name: '1 Month', durationDays: 30),
  MembershipPlan(id: 'month3', name: '3 Months', durationDays: 90),
  MembershipPlan(id: 'year', name: '1 Year', durationDays: 365),
  MembershipPlan(id: 'comp', name: 'Comp (No Expiry)', durationDays: 3650),
];
}