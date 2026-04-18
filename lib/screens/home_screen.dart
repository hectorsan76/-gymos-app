import 'package:flutter/material.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';
import 'check_in_screen.dart';
import 'add_member_screen.dart';
import 'member_list_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'member_detail_screen.dart'; // ✅ ADDED

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
          'member': m, // ✅ CRITICAL ADD
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
          child: Column(
            children: [
              const SizedBox(height: 20),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _button(
                      context,
                      label: "Check-In",
                      onTap: () async {
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
                    ),

                    _button(
                      context,
                      label: "Add Member",
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddMemberScreen(),
                          ),
                        );

                        if (!context.mounted) return;

                        if (result == true) {
                          await onUpdate();
                        }
                      },
                    ),

                    _button(
                      context,
                      label: "Members",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberListScreen(
                              members: safeMembers,
                              onEditMember: onEditMember,
                              onDeleteMember: onDeleteMember,
                              onRefresh: onUpdate,
                            ),
                          ),
                        );

                        if (!context.mounted) return;
                        await onUpdate();
                      },
                    ),

                    _button(
                      context,
                      label: "Dashboard",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DashboardScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Divider(),
              const SizedBox(height: 10),

              const Text(
                "Recent Check-Ins",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 200,
                child: limitedCheckIns.isEmpty
                    ? const Center(child: Text("No check-ins yet"))
                    : ListView.builder(
                        itemCount: limitedCheckIns.length,
                        itemBuilder: (context, i) {
                          final c = limitedCheckIns[i];

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  (c['photo'] != null &&
                                          c['photo'].toString().isNotEmpty)
                                      ? NetworkImage(c['photo'])
                                      : null,
                              child: (c['photo'] == null ||
                                      c['photo'].toString().isEmpty)
                                  ? Text(
                                      c['name'][0].toUpperCase(),
                                      style: const TextStyle(fontSize: 14),
                                    )
                                  : null,
                            ),
                            title: Text(c['name']),
                            trailing: Text(
                              DateUtilsHelper.formatDateTime(c['time']),
                              style: const TextStyle(color: Colors.grey),
                            ),

                            // ✅ THIS IS THE KEY FEATURE
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MemberDetailScreen(
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
        height: 60,
        child: ElevatedButton(
          onPressed: onTap,
          child: Text(
            label,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}