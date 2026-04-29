import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym_app/utils/currency_utils.dart' as cu;

import 'member_detail_screen.dart';
import '../models/member.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> sales = [];
  Map<String, dynamic> memberMap = {};

  bool isLoading = true;

  String currency = "USD";
  String filter = "ALL";

  @override
  void initState() {
    super.initState();
    loadSales();
  }

  Future<void> loadSales() async {
    setState(() => isLoading = true);

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

      final now = DateTime.now();

      List<dynamic> filtered = renewals.where((r) {
        final date = DateTime.parse(r['created_at']);

        if (filter == "TODAY") {
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }

        if (filter == "7D") {
          return date.isAfter(now.subtract(const Duration(days: 7)));
        }

        if (filter == "30D") {
          return date.isAfter(now.subtract(const Duration(days: 30)));
        }

        return true;
      }).toList();

      setState(() {
        sales = filtered;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("SALES ERROR: $e");
      setState(() => isLoading = false);
    }
  }

  Widget filterBar() {
    final theme = Theme.of(context);

    Widget chip(String label) {
      final isSelected = filter == label;

      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.textTheme.bodyMedium?.color,
        ),
        onSelected: (_) {
          setState(() {
            filter = label;
          });
          loadSales();
        },
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip("TODAY"),
        chip("7D"),
        chip("30D"),
        chip("ALL"),
      ],
    );
  }

  Widget summaryBar() {
    double total = 0;

    for (var r in sales) {
      total += (r['amount'] ?? 0).toDouble();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            "Total Revenue",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            cu.CurrencyUtils.format(total, currency),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${sales.length} sales",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget buildAvatar(Map<String, dynamic>? m) {
    final url = m?['photo_url'];

    if (url != null && url.toString().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(url),
      );
    }

    final first = m?['first_name'] ?? '';
    return CircleAvatar(
      radius: 20,
      child: Text(
        first.isNotEmpty ? first[0].toUpperCase() : "?",
      ),
    );
  }

  Widget salesList() {
    final theme = Theme.of(context);

    if (sales.isEmpty) {
      return const Center(child: Text("No sales found"));
    }

    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, i) {
        final r = sales[i];

        final rawMember = memberMap[r['member_id']];
        final member = rawMember != null
            ? Member.fromJson(rawMember)
            : null;

        final name = member != null
            ? "${member.firstName} ${member.lastName}"
            : "Member";

        final amount = (r['amount'] ?? 0).toDouble();
        final plan = r['membership_type'] ?? "";
        final method =
            (r['payment_method'] ?? "").toString().toUpperCase();

        final date = DateTime.parse(r['created_at']);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (member == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: member),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildAvatar(rawMember),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),

                        const SizedBox(height: 4),

                        Text("Plan: $plan"),
                        Text("Payment: $method"),
                        Text("Date: ${date.toLocal().toString().substring(0, 16)}"),
                      ],
                    ),
                  ),

                  Text(
                    cu.CurrencyUtils.format(amount, currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Sales"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadSales,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    summaryBar(),
                    const SizedBox(height: 16),
                    filterBar(),
                    const SizedBox(height: 16),
                    Expanded(child: salesList()),
                  ],
                ),
              ),
            ),
    );
  }
}