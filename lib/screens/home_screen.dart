import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';
import '../utils/responsive.dart';
import 'check_in_screen.dart';
import 'add_member_screen.dart';
import 'member_list_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'member_detail_screen.dart';
import 'paywall_screen.dart';
import '../services/purchase_service.dart';

class HomeScreen extends StatelessWidget {
  final List<Member> members;
  final Future<void> Function() onUpdate;
  final Function(Member) onEditMember;
  final Function(Member) onDeleteMember;

  const HomeScreen({
    super.key,
    required this.members,
    required this.onUpdate,
    required this.onEditMember,
    required this.onDeleteMember,
  });

  @override
  Widget build(BuildContext context) {
    final pad = R.pad(context);
    final tablet = R.isTablet(context);

    final recentCheckIns = <Map<String, dynamic>>[];
    for (final m in members) {
      for (final c in m.checkIns) {
        recentCheckIns.add({
          'member': m,
          'name': m.fullName,
          'time': c,
          'photo': m.photoUrl,
        });
      }
    }
    recentCheckIns.sort((a, b) =>
        (b['time'] as DateTime).compareTo(a['time'] as DateTime));
    final limitedCheckIns = recentCheckIns.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("GymOS",
            style: TextStyle(fontSize: R.fontSize(context, 20))),
        leading: kDebugMode
            ? IconButton(
                icon: const Icon(Icons.lock_open),
                tooltip: 'Debug: unlock pro',
                onPressed: () => PurchaseService().unlockProFake(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          children: [

            // Hero check-in button
            SizedBox(
              width: double.infinity,
              height: R.heroHeight(context),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 3,
                ),
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => CheckInScreen(
                              members: members, onUpdate: onUpdate)));
                  if (!context.mounted) return;
                  await onUpdate();
                },
                child: Text(
                  "Check-In Member",
                  style: TextStyle(
                    fontSize: R.fontSize(context, 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: pad * 0.75),

            // Add Member + Members
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: R.buttonHeight(context),
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const AddMemberScreen()));
                        if (!context.mounted) return;
                        if (result == true) await onUpdate();
                      },
                      child: Text("Add Member",
                          style: TextStyle(
                              fontSize: R.fontSize(context, 15))),
                    ),
                  ),
                ),
                SizedBox(width: pad * 0.75),
                Expanded(
                  child: SizedBox(
                    height: R.buttonHeight(context),
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => MemberListScreen(
                                      members: members,
                                      onEditMember: onEditMember,
                                      onDeleteMember: onDeleteMember,
                                      onRefresh: onUpdate,
                                    )));
                        if (!context.mounted) return;
                        await onUpdate();
                      },
                      child: Text("Members",
                          style: TextStyle(
                              fontSize: R.fontSize(context, 15))),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: pad * 0.75),

            // Dashboard + Sales (pro gated)
            ValueListenableBuilder<bool>(
              valueListenable: PurchaseService().isProNotifier,
              builder: (context, isPro, _) {
                return Row(
                  children: [
                    Expanded(child: _proButton(context, label: "Dashboard",
                        isPro: isPro,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const DashboardScreen())))),
                    SizedBox(width: pad * 0.75),
                    Expanded(child: _proButton(context, label: "Sales",
                        isPro: isPro,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const SalesScreen())))),
                  ],
                );
              },
            ),

            SizedBox(height: pad),
            const Divider(),
            SizedBox(height: pad * 0.5),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent Check-Ins",
                style: TextStyle(
                  fontSize: R.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(height: pad * 0.5),

            Expanded(
              child: limitedCheckIns.isEmpty
                  ? const Center(child: Text("No check-ins yet"))
                  : ListView.builder(
                      itemCount: limitedCheckIns.length,
                      itemBuilder: (context, i) {
                        final c = limitedCheckIns[i];
                        final avatarR = tablet ? 24.0 : 18.0;
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: tablet ? 4 : 0),
                          leading: CircleAvatar(
                            radius: avatarR,
                            backgroundColor: Colors.grey[400],
                            backgroundImage: (c['photo'] != null &&
                                    c['photo'].toString().isNotEmpty)
                                ? NetworkImage(c['photo'])
                                : null,
                            child: (c['photo'] == null ||
                                    c['photo'].toString().isEmpty)
                                ? Text(c['name'][0].toUpperCase(),
                                    style: TextStyle(
                                        fontSize: tablet ? 16 : 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(c['name'],
                              style: TextStyle(
                                  fontSize: R.fontSize(context, 15))),
                          trailing: Text(
                              DateUtilsHelper.formatDateTime(c['time']),
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: R.fontSize(context, 13))),
                          onTap: () async {
                            final result = await Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => MemberDetailScreen(
                                        member: c['member'])));
                            if (result == true) await onUpdate();
                          },
                        );
                      },
                    ),
            ),

            SizedBox(height: pad),
          ],
        ),
      ),
    );
  }

  Widget _proButton(BuildContext context,
      {required String label,
      required bool isPro,
      required VoidCallback onTap}) {
    return SizedBox(
      height: R.buttonHeight(context),
      child: ElevatedButton(
        onPressed: () {
          if (isPro) {
            onTap();
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()));
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(fontSize: R.fontSize(context, 15))),
            if (!isPro) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
