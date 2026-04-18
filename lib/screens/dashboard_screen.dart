import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym_app/utils/currency_utils.dart' as cu;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  double revenueToday = 0;

  // ✅ UPDATED STRUCTURE
  Map<String, Map<String, dynamic>> salesBreakdown = {};

  int checkInsToday = 0;

  String currency = "USD";

  bool isLoading = true;

  double revenueWeek = 0; // ✅ ADDED
  double revenueMonth = 0; // ✅ ADDED
  double revenueLifetime = 0; // ✅ ADDED
  int salesTodayCount = 0; // ✅ ADDED
  int activeMembersCount = 0; // ✅ ADDED

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() => isLoading = true);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final last7Days = now.subtract(const Duration(days: 7)); // ✅ ADDED
    final startOfMonth = DateTime(now.year, now.month, 1); // ✅ ADDED

    try {
      final user = supabase.auth.currentUser;

      // ✅ FETCH USER CURRENCY
      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('currency')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && profile['currency'] != null) {
          currency = profile['currency'];
        }
      }

      // 🔥 FETCH RENEWALS
      final renewals = await supabase
          .from('renewals')
          .select(); // ✅ MODIFIED

      double total = 0;
      double weekTotal = 0; // ✅ ADDED
      double monthTotal = 0; // ✅ ADDED
      double lifetimeTotal = 0; // ✅ ADDED
      int todayCount = 0; // ✅ ADDED

      Map<String, Map<String, dynamic>> breakdown = {};

      for (var r in renewals) {
        final amount = (r['amount'] ?? 0).toDouble();
        final date = DateTime.parse(r['created_at']); // ✅ ADDED

        // ✅ HARD FIX FOR "UNKNOWN"
        final type = (r['membership_type'] != null &&
                r['membership_type'].toString().isNotEmpty)
            ? r['membership_type'].toString()
            : "${r['duration_days'] ?? 0} Day Pass";

        lifetimeTotal += amount; // ✅ ADDED

        if (date.isAfter(startOfDay)) { // ✅ ADDED
          total += amount;
          todayCount++; // ✅ ADDED

          if (!breakdown.containsKey(type)) {
            breakdown[type] = {
              "count": 0,
              "revenue": 0.0,
            };
          }

          breakdown[type]!["count"] += 1;
          breakdown[type]!["revenue"] += amount;
        }

        if (date.isAfter(last7Days)) {
          weekTotal += amount; // ✅ ADDED
        }

        if (date.isAfter(startOfMonth)) {
          monthTotal += amount; // ✅ ADDED
        }
      }

      // 🔥 FETCH CHECK-INS
      final checkins = await supabase
          .from('check_ins')
          .select()
          .gte('created_at', startOfDay.toIso8601String());

      // 🔥 FETCH MEMBERS FOR ACTIVE COUNT
      final members = await supabase.from('members').select(); // ✅ ADDED

      int activeCount = members.where((m) { // ✅ ADDED
        final hasPlan = m['membership_type'] != null &&
            m['membership_type'].toString().isNotEmpty;

        final isCancelled = m['is_cancelled'] == true;

        final expiry = DateTime.parse(m['expiry_date']);

        final pausedUntil = m['paused_until'] != null
            ? DateTime.parse(m['paused_until'])
            : null;

        final isPaused = pausedUntil != null &&
            pausedUntil.isAfter(now);

        return hasPlan &&
            !isCancelled &&
            expiry.isAfter(now) &&
            !isPaused;
      }).length;

      setState(() {
        revenueToday = total;
        salesBreakdown = breakdown;
        checkInsToday = checkins
            .map((c) => c['member_id'])
            .toSet()
            .length; // ✅ MODIFIED (unique members only)
        revenueWeek = weekTotal; // ✅ ADDED
        revenueMonth = monthTotal; // ✅ ADDED
        revenueLifetime = lifetimeTotal; // ✅ ADDED
        salesTodayCount = todayCount; // ✅ ADDED
        activeMembersCount = activeCount; // ✅ ADDED
        isLoading = false;
      });
    } catch (e) {
      debugPrint("DASHBOARD ERROR: $e");
      setState(() => isLoading = false);
    }
  }

  Widget buildRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Today Revenue",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            cu.CurrencyUtils.format(revenueToday, currency),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSalesBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sales Breakdown",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (salesBreakdown.isEmpty)
          const Text("No sales today"),

        ...salesBreakdown.entries.map((e) {
          final name = e.key;
          final count = e.value["count"];
          final revenue = e.value["revenue"];

          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            subtitle: Text(
              cu.CurrencyUtils.format(revenue, currency),
            ),
            trailing: Text("x$count"),
          );
        }),
      ],
    );
  }

  Widget buildCheckins() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Check-Ins Today",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          checkInsToday.toString(),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget buildExtraStats() { // ✅ ADDED
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Stats",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text("7 Days: ${cu.CurrencyUtils.format(revenueWeek, currency)}"),
        Text("Month: ${cu.CurrencyUtils.format(revenueMonth, currency)}"),
        Text("All Time: ${cu.CurrencyUtils.format(revenueLifetime, currency)}"),
        const SizedBox(height: 10),
        Text("Sales Today: $salesTodayCount"),
        Text("Active Members: $activeMembersCount"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  buildRevenueCard(),
                  const SizedBox(height: 20),
                  buildExtraStats(), // ✅ ADDED
                  const SizedBox(height: 20),
                  buildSalesBreakdown(),
                  const SizedBox(height: 20),
                  buildCheckins(),
                ],
              ),
            ),
    );
  }
}