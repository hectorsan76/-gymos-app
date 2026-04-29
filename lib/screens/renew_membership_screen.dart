import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/membership_plan.dart';

class RenewMembershipScreen extends StatefulWidget {
  final Member member;
  final Function(Member, int) onRenew;

  const RenewMembershipScreen({
    super.key,
    required this.member,
    required this.onRenew,
  });

  @override
  State<RenewMembershipScreen> createState() =>
      _RenewMembershipScreenState();
}

class _RenewMembershipScreenState extends State<RenewMembershipScreen> {
  bool isProcessing = false;

  void handleRenew(MembershipPlan plan) {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    widget.onRenew(widget.member, plan.durationDays);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ ADDED
      appBar: AppBar(
        title: const Text("Renew Membership"),
        backgroundColor: Colors.transparent, // ✅ ADDED
        elevation: 0, // ✅ ADDED
        foregroundColor: Colors.black, // ✅ ADDED
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // 🔥 FIX
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: MembershipPlans.plans.length,
            itemBuilder: (context, index) {
              final plan = MembershipPlans.plans[index];

              return Card(
                color: Theme.of(context).cardColor, // ✅ ADDED
                elevation: 0, // ✅ ADDED
                shape: RoundedRectangleBorder( // ✅ ADDED
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16), // ✅ ADDED
                  onTap: isProcessing ? null : () => handleRenew(plan),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${plan.durationDays} days",
                              style: const TextStyle(color: Colors.grey), // ✅ ADDED
                            ),
                          ],
                        ),
                        isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 18), // ✅ MODIFIED
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}