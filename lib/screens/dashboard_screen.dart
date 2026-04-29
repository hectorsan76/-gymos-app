import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym_app/utils/currency_utils.dart' as cu;
import 'sales_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  String currency = "USD";

  double revenueToday = 0;
  double revenueWeek = 0;
  double revenueMonth = 0;

  int activeCount = 0;
  int expiredCount = 0;
  int pausedCount = 0;

  List<dynamic> recentSales = [];
  List<dynamic> expiringSoon = [];

  Map<String, dynamic> memberMap = {};

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() => isLoading = true);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final last7Days = now.subtract(const Duration(days: 7));
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      final user = supabase.auth.currentUser;

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

      final renewals = await supabase
          .from('renewals')
          .select()
          .order('created_at', ascending: false);

      final members = await supabase.from('members').select();

      memberMap = {
        for (var m in members) m['id']: m
      };

      double today = 0;
      double week = 0;
      double month = 0;

      for (var r in renewals) {
        final amount = (r['amount'] ?? 0).toDouble();
        final date = DateTime.parse(r['created_at']);

        if (date.isAfter(startOfDay)) {
          today += amount;
        }

        if (date.isAfter(last7Days)) {
          week += amount;
        }

        if (date.isAfter(startOfMonth)) {
          month += amount;
        }
      }

      int active = 0;
      int expired = 0;
      int paused = 0;

      List<dynamic> expiring = [];

      for (var m in members) {
        final hasPlan = m['membership_type'] != null &&
            m['membership_type'].toString().isNotEmpty;

        final isCancelled = m['is_cancelled'] == true;

        final expiry = DateTime.parse(m['expiry_date']);

        final pausedUntil = m['paused_until'] != null
            ? DateTime.parse(m['paused_until'])
            : null;

        final isPaused = pausedUntil != null &&
            pausedUntil.isAfter(now);

        if (isPaused) {
          paused++;
        } else if (hasPlan && !isCancelled && expiry.isAfter(now)) {
          active++;
        } else if (hasPlan && expiry.isBefore(now)) {
          expired++;
        }

        if (expiry.isAfter(now) &&
            expiry.isBefore(now.add(const Duration(days: 5)))) {
          expiring.add(m);
        }
      }

      setState(() {
        revenueToday = today;
        revenueWeek = week;
        revenueMonth = month;

        activeCount = active;
        expiredCount = expired;
        pausedCount = paused;

        recentSales = renewals.take(6).toList();
        expiringSoon = expiring.take(5).toList();

        isLoading = false;
      });
    } catch (e) {
      debugPrint("DASHBOARD ERROR: $e");
      setState(() => isLoading = false);
    }
  }

  Widget revenueBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E), // ✅ FORCED GREEN
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            "Today",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cu.CurrencyUtils.format(revenueToday, currency),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Week: ${cu.CurrencyUtils.format(revenueWeek, currency)}   Month: ${cu.CurrencyUtils.format(revenueMonth, currency)}",
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget statsRow() {
    final theme = Theme.of(context);

    Widget box(String label, int value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        box("Active", activeCount, Colors.green),
        const SizedBox(width: 10),
        box("Expired", expiredCount, Colors.red),
        const SizedBox(width: 10),
        box("Paused", pausedCount, Colors.orange),
      ],
    );
  }

  Widget expiringSoonBlock() {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Expiring Soon",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (expiringSoon.isEmpty)
              const Text("No upcoming expirations"),
            ...expiringSoon.map((m) {
              final expiry = DateTime.parse(m['expiry_date']);
              final days =
                  expiry.difference(DateTime.now()).inDays;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    "${m['first_name']} ${m['last_name']}"),
                trailing: Text("$days days"),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget recentSalesBlock() {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Sales",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesScreen(),
                      ),
                    );
                  },
                  child: const Text("View All Sales"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (recentSales.isEmpty)
              const Text("No sales yet"),
            ...recentSales.map((r) {
              final member = memberMap[r['member_id']];
              final name = member != null
                  ? "${member['first_name']} ${member['last_name']}"
                  : "Member";

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                subtitle: Text(r['membership_type'] ?? ""),
                trailing: Text(
                  cu.CurrencyUtils.format(
                      (r['amount'] ?? 0).toDouble(), currency),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  revenueBlock(),
                  const SizedBox(height: 16),
                  statsRow(),
                  const SizedBox(height: 16),
                  expiringSoonBlock(),
                  const SizedBox(height: 16),
                  recentSalesBlock(),
                ],
              ),
            ),
    );
  }
}