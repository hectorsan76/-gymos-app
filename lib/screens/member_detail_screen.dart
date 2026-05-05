import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ ADDED

import '../models/member.dart';
import '../models/membership_plan.dart';
import '../utils/date_utils.dart';
import 'member_qr_screen.dart';
import 'edit_member_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final supabase = Supabase.instance.client;

  String currency = "USD";

List<dynamic> purchaseHistory = []; // ✅ ADDED
bool isLoadingPurchases = true; // ✅ ADDED
bool isProcessingSale = false; // ✅ ADDED

@override
void initState() {
  super.initState();
  loadCurrency();
  loadPurchases(); // ✅ ADDED
}

Future<void> loadCurrency() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  final profile = await supabase
      .from('profiles')
      .select('currency')
      .eq('id', user.id)
      .maybeSingle();

  if (profile != null && profile['currency'] != null) {
    setState(() {
      currency = profile['currency'];
    });
  }
}

Future<void> loadPurchases() async {
  try {
    final data = await supabase
        .from('renewals')
        .select()
        .eq('member_id', widget.member.id)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      purchaseHistory = data;
      isLoadingPurchases = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      isLoadingPurchases = false;
    });
  }
}

String formatPhone(String phone) { // ✅ ADDED
  phone = phone.trim();

  if (phone.startsWith('+')) {
    return '+' + phone.substring(1).replaceAll(RegExp(r'\D'), '');
  }

  return phone.replaceAll(RegExp(r'\D'), '');
}

Future<void> openWhatsApp(String phone, String name) async { // ✅ ADDED
  final formatted = formatPhone(phone);

  final message = Uri.encodeComponent( // ✅ MODIFIED
  "Hey $name \nWe haven’t seen you in a bit.\nCome get a workout in this week"
);

  final url = "https://wa.me/${formatted.replaceAll('+', '')}?text=$message";
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> sendEmail(String email, String name) async { // ✅ ADDED
  final subject = Uri.encodeComponent("We miss you at the gym");
  final body = Uri.encodeComponent( // ✅ MODIFIED
  "Hey $name 👋\n\nWe haven’t seen you in a bit.\nCome get a workout in this week 💪"
);

  final uri = Uri.parse("mailto:$email?subject=$subject&body=$body");

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

  String getCurrencySymbol() {
    switch (currency) {
      case "USD":
        return "\$";
      case "EUR":
        return "€";
      case "GBP":
        return "£";
      case "AUD":
        return "\$";
      case "IDR":
        return "Rp";
      default:
        return "";
    }
  }

  void showSellMembershipModal() {
    String paymentMethod = "cash";
    final amountController = TextEditingController();
    MembershipPlan? selectedPlan;

    final currencySymbol = getCurrencySymbol();

    showDialog(
  context: context,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor, // ✅ MODIFIED
          shape: RoundedRectangleBorder( // ✅ ADDED
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text( // ✅ MODIFIED
            "Sell Membership",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // ✅ ADDED
              children: [

                    const Text("Select Plan", style: TextStyle(fontWeight: FontWeight.w600)), // ✅ MODIFIED
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8, // ✅ ADDED
                      children: MembershipPlans.plans.map((plan) {
                        return ChoiceChip(
                          label: Text(plan.name),
                          selected: selectedPlan == plan,
                          onSelected: (_) {
                            setModalState(() {
                              selectedPlan = plan;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    Text("Amount ($currencySymbol)", style: const TextStyle(fontWeight: FontWeight.w600)), // ✅ MODIFIED
                    const SizedBox(height: 6), // ✅ ADDED
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: "Enter amount (0 allowed)",
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // ✅ ADDED
                        border: OutlineInputBorder(), // ✅ ADDED
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text("Payment Method", style: TextStyle(fontWeight: FontWeight.w600)), // ✅ MODIFIED
                    const SizedBox(height: 12), // ✅ ADDED
                    Wrap(
                      spacing: 8,
                      runSpacing: 8, // ✅ ADDED
                      children: ["cash", "card", "transfer"].map((method) {
                        return ChoiceChip(
                          label: Text(method.toUpperCase()),
                          selected: paymentMethod == method,
                          onSelected: (_) {
                            setModalState(() {
                              paymentMethod = method;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ✅ ADDED
              actions: [
  TextButton(
    onPressed: isProcessingSale ? null : () {
      Navigator.pop(context);
    },
    child: const Text("Cancel"),
  ),
  SizedBox( // ✅ ADDED
    height: 44,
    child: ElevatedButton(
      onPressed: isProcessingSale ? null : () async {

  if (isProcessingSale) return;

  setState(() => isProcessingSale = true);

  if (selectedPlan == null) {
    setState(() => isProcessingSale = false);
    return;
  }

  if (amountController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Amount required (enter 0 if free)"),
      ),
    );
    setState(() => isProcessingSale = false);
    return;
  }

  final amount = double.tryParse(amountController.text.trim());

  if (amount == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invalid number"),
      ),
    );
    setState(() => isProcessingSale = false);
    return;
  }

  final user = supabase.auth.currentUser;
  if (user == null) {
    setState(() => isProcessingSale = false);
    return;
  }

  final now = DateTime.now();

  DateTime newExpiry;

  if (selectedPlan!.durationDays == 1) {
    newExpiry = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );
  } else {
    newExpiry = now.add(Duration(days: selectedPlan!.durationDays));
  }

  final paymentStatus = amount == 0 ? "free" : "paid";

  if (!mounted) {
  setState(() => isProcessingSale = false);
  return;
}

final nowUtc = DateTime.now().toUtc();
final nowSecond = DateTime.utc(
  nowUtc.year,
  nowUtc.month,
  nowUtc.day,
  nowUtc.hour,
  nowUtc.minute,
  nowUtc.second,
).toIso8601String();

try {

  await supabase.from('renewals').insert({
    'member_id': widget.member.id,
    'gym_id': user.id,
    'duration_days': selectedPlan!.durationDays,
    'payment_method': paymentMethod,
    'amount': amount,
    'payment_status': paymentStatus,
    'membership_type': selectedPlan!.name,
    'created_at_second': nowSecond,
  });

} catch (e) {

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Duplicate purchase blocked")),
  );

  setState(() => isProcessingSale = false);
  return;
}

  await supabase.from('members').update({
    'expiry_date': newExpiry.toIso8601String(),
    'is_cancelled': false,
    'paused_until': null,
    'remaining_days_on_pause': null,
    'membership_type': selectedPlan!.name,
  }).eq('id', widget.member.id);

  await loadPurchases();

  setState(() {
    widget.member.expiryDate = newExpiry;
    widget.member.isCancelled = false;
    widget.member.pausedUntil = null;
    widget.member.remainingDaysOnPause = null;
    widget.member.membershipType = selectedPlan!.name;
    isProcessingSale = false;
  });

  Navigator.pop(context);
},
child: isProcessingSale
    ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : const Padding( // ✅ ADDED
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text("Confirm"),
      ),
    ),
  ),
              ],
            );
          },
        );
      },
    ).then((_) {
  if (mounted) {
    setState(() => isProcessingSale = false);
  }
});
  }

  // REST OF FILE UNCHANGED (NO LOGIC MODIFICATIONS)

  Future<void> openEditMember() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMemberScreen(member: widget.member),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      setState(() {});
    }
  }

  Future<void> editExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.member.expiryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      await supabase.from('members').update({
        'expiry_date': picked.toIso8601String(),
      }).eq('id', widget.member.id);

      setState(() {
        widget.member.expiryDate = picked;
      });
    }
  }

  void showPauseOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [7, 14, 30].map((days) {
            return ListTile(
              title: Text("Pause $days days"),
              onTap: () async {
                Navigator.pop(context);
                await pauseDays(days);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> pauseDays(int days) async {
    final now = DateTime.now();
    final remaining =
        widget.member.expiryDate.difference(now).inDays;

    final pausedUntil = now.add(Duration(days: days));

    await supabase.from('members').update({
      'paused_until': pausedUntil.toIso8601String(),
      'remaining_days_on_pause': remaining > 0 ? remaining : 0,
    }).eq('id', widget.member.id);

    setState(() {
      widget.member.pausedUntil = pausedUntil;
      widget.member.remainingDaysOnPause =
          remaining > 0 ? remaining : 0;
    });
  }

  Future<void> resumeMembership() async {
    final now = DateTime.now();
    final remaining = widget.member.remainingDaysOnPause ?? 0;
    final newExpiry = now.add(Duration(days: remaining));

    await supabase.from('members').update({
      'expiry_date': newExpiry.toIso8601String(),
      'paused_until': null,
      'remaining_days_on_pause': null,
    }).eq('id', widget.member.id);

    setState(() {
      widget.member.expiryDate = newExpiry;
      widget.member.pausedUntil = null;
      widget.member.remainingDaysOnPause = null;
    });
  }

  Future<void> cancelMembership() async {
    await supabase.from('members').update({
      'is_cancelled': true,
      'membership_type': null,
    }).eq('id', widget.member.id);

    setState(() {
      widget.member.isCancelled = true;
      widget.member.membershipType = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Membership cancelled")),
    );
  }

  Widget _infoRow(IconData icon, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget buildAvatar(Member member) {
    final url = member.photoUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade400,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: "$url?t=${DateTime.now().millisecondsSinceEpoch}",
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            memCacheWidth: 200,
            memCacheHeight: 200,
            fadeInDuration: const Duration(milliseconds: 100),
            placeholder: (_, __) => const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Center(
              child: Text(
                member.firstName.isNotEmpty
                    ? member.firstName[0].toUpperCase()
                    : "?",
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
  radius: 50,
  backgroundColor: Colors.grey.shade400,
  child: Text(
        member.firstName.isNotEmpty
            ? member.firstName[0].toUpperCase()
            : "?",
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    final sortedCheckIns = [...member.checkIns]
      ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now(); // ✅ ADDED
    final totalCheckIns = sortedCheckIns.length; // ✅ ADDED
    final last30DaysCount = sortedCheckIns.where((c) => c.isAfter(now.subtract(const Duration(days: 30)))).length; // ✅ ADDED
    final daysSinceLast = sortedCheckIns.isNotEmpty ? now.difference(sortedCheckIns.first).inDays : null; // ✅ ADDED

    final hasPlan = member.membershipType != null &&
        member.membershipType!.isNotEmpty;

    final isPaused = member.pausedUntil != null &&
        member.pausedUntil!.isAfter(DateTime.now());

    final isActive = hasPlan &&
        !member.isCancelled &&
        member.expiryDate.isAfter(DateTime.now());

    final statusText = isPaused
        ? "PAUSED"
        : hasPlan
            ? (isActive ? "ACTIVE" : "EXPIRED")
            : "NO PLAN";

    final statusColor = isPaused
        ? Colors.orange
        : hasPlan
            ? (isActive ? const Color(0xFF4DCCC2) : Colors.red) // ✅ MODIFIED
            : Colors.grey;

    final membershipLabel =
        hasPlan ? member.membershipType! : "No Active Plan";

    final canPause = hasPlan && !member.isCancelled && member.expiryDate.isAfter(DateTime.now()); // ✅ ADDED

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(member.fullName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: openEditMember),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // ── Header card: avatar + name + status ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        buildAvatar(member),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.fullName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                member.isCancelled ? "No Active Plan" : membershipLabel,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "Expires: ${DateUtilsHelper.formatDate(member.expiryDate)}",
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              if (isPaused)
                                Text(
                                  "Resumes: ${DateUtilsHelper.formatDate(member.pausedUntil!)}",
                                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Contact info card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        _infoRow(Icons.email, member.email,
                            trailing: member.email.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.email, size: 20),
                                    onPressed: () => sendEmail(member.email, member.firstName),
                                  )
                                : null),
                        _infoRow(Icons.phone, member.phone,
                            trailing: member.phone.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.chat, size: 18,
                                        color: Color(0xFF25D366)),
                                    onPressed: () => openWhatsApp(member.phone, member.firstName),
                                  )
                                : null),
                        if ((member.address ?? '').isNotEmpty)
                          _infoRow(Icons.location_on, member.address!),
                        if ((member.country ?? '').isNotEmpty)
                          _infoRow(Icons.flag, member.country!),
                        if ((member.instagram ?? '').isNotEmpty)
                          _infoRow(Icons.camera_alt, "IG: ${member.instagram!}"),
                        if ((member.notes ?? '').isNotEmpty)
                          _infoRow(Icons.notes, member.notes!),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Purchase button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: showSellMembershipModal,
                    child: const Text("Purchase Membership"),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Action buttons 2x2 grid ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: editExpiry,
                        child: const Text("Edit Expiry"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canPause ? null : Colors.grey,
                        ),
                        onPressed: canPause
                            ? showPauseOptions
                            : () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Cannot pause this membership")),
                                ),
                        child: const Text("Pause"),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: resumeMembership,
                        child: const Text("Resume"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: cancelMembership,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MemberQRScreen(member: member)),
                        ),
                        child: const Text("QR Code"),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

const Divider(),

const SizedBox(height: 10),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Check-Ins",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6), // ✅ ADDED

         Column( // ✅ MODIFIED
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      "Last 30 days: $last30DaysCount",
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    Text(
      "Total: $totalCheckIns",
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    Text(
      "Last visit: ${daysSinceLast ?? '-'} days ago",
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
  ],
),

          const SizedBox(height: 10),

          SizedBox(
            height: 200,
            child: sortedCheckIns.isEmpty
                ? const Center(child: Text("No check-ins yet"))
                : ListView.builder(
                    itemCount: sortedCheckIns.length,
                    itemBuilder: (_, i) {
                      final c = sortedCheckIns[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          DateUtilsHelper.formatDateTime(c),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),

    const SizedBox(width: 16),

    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Purchases",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),

      const SizedBox(height: 10),

      SizedBox(
        height: 200,
        child: isLoadingPurchases
            ? const Center(child: CircularProgressIndicator())
            : purchaseHistory.isEmpty
                ? const Center(child: Text("No purchases yet"))
                : ListView.builder(
                    itemCount: purchaseHistory.length,
                    itemBuilder: (_, i) {
                      final p = purchaseHistory[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p['membership_type'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${getCurrencySymbol()}${p['amount']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateUtilsHelper.formatDateTime(
                                DateTime.parse(
                                  p['created_at'] ?? p['created_at_second'],
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    ],
  ),
),
],
),

const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }
}