import 'package:flutter/material.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';
import 'check_in_screen.dart';
import 'add_member_screen.dart';
import 'member_list_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'member_detail_screen.dart';

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
    final safeMembers = members;

    final recentCheckIns = <Map<String, dynamic>>[];

    for (final m in safeMembers) {
      for (final c in m.checkIns) {
        recentCheckIns.add({
          'member': m,
          'name': m.fullName,
          'time': c,
          'photo': m.photoUrl,
        });
      }
    }

    recentCheckIns.sort(
      (a, b) =>
          (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );

    final limitedCheckIns = recentCheckIns.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("GymOS"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                const SizedBox(height: 8),

                /// 🔥 CENTERED BUTTON BLOCK
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        /// GREEN HERO BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 120,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ECC71), // ✅ GREEN
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 3,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CheckInScreen(
                                    members: safeMembers,
                                    onUpdate: onUpdate,
                                  ),
                                ),
                              );

                              if (!context.mounted) return;
                              await onUpdate();
                            },
                            child: const Text(
                              "Check-In Member",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AddMemberScreen(),
                                      ),
                                    );

                                    if (!context.mounted) return;

                                    if (result == true) {
                                      await onUpdate();
                                    }
                                  },
                                  child: const Text(
                                    "Add Member",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MemberListScreen(
                                          members: safeMembers,
                                          onEditMember: onEditMember,
                                          onDeleteMember:
                                              onDeleteMember,
                                          onRefresh: onUpdate,
                                        ),
                                      ),
                                    );

                                    if (!context.mounted) return;
                                    await onUpdate();
                                  },
                                  child: const Text(
                                    "Members",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _button(
                          context,
                          label: "Dashboard",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DashboardScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(),
                const SizedBox(height: 10),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Recent Check-Ins",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 300,
                  child: limitedCheckIns.isEmpty
                      ? const Center(child: Text("No check-ins yet"))
                      : ListView.builder(
                          itemCount: limitedCheckIns.length,
                          itemBuilder: (context, i) {
                            final c = limitedCheckIns[i];

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey[400],
                                backgroundImage:
                                    (c['photo'] != null &&
                                            c['photo']
                                                .toString()
                                                .isNotEmpty)
                                        ? NetworkImage(c['photo'])
                                        : null,
                                child: (c['photo'] == null ||
                                        c['photo']
                                            .toString()
                                            .isEmpty)
                                    ? Text(
                                        c['name'][0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(c['name']),
                              trailing: Text(
                                DateUtilsHelper.formatDateTime(
                                    c['time']),
                                style: const TextStyle(
                                    color: Colors.grey),
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MemberDetailScreen(
                                      member: c['member'],
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  await onUpdate();
                                }
                              },
                            );
                          },
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}