import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';
import 'member_detail_screen.dart';

class MemberListScreen extends StatefulWidget {
  final List<Member> members;
  final Function(Member) onEditMember;
  final Function(Member) onDeleteMember;
  final Future<void> Function()? onRefresh;

  const MemberListScreen({
    super.key,
    required this.members,
    required this.onEditMember,
    required this.onDeleteMember,
    this.onRefresh,
  });

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

enum MemberStatus {
  cancelled,
  paused,
  expired,
  active,
  inactive,
}

class _MemberListScreenState extends State<MemberListScreen> {
  String searchQuery = "";
  String selectedFilter = "ALL";

  MemberStatus getStatus(Member m) {
    final now = DateTime.now();

    final hasMembership =
        m.membershipType != null && m.membershipType!.isNotEmpty;

    if (m.isCancelled) return MemberStatus.cancelled;

    if (m.pausedUntil != null && m.pausedUntil!.isAfter(now)) {
      return MemberStatus.paused;
    }

    if (hasMembership && m.expiryDate.isBefore(now)) {
      return MemberStatus.expired;
    }

    if (hasMembership && m.expiryDate.isAfter(now)) {
      return MemberStatus.active;
    }

    return MemberStatus.inactive;
  }

  // ✅ ADDED (retention logic)
  bool isExpiringSoon(Member m) {
    final now = DateTime.now();
    return m.membershipType != null &&
        m.membershipType!.isNotEmpty &&
        m.expiryDate.isAfter(now) &&
        m.expiryDate.isBefore(now.add(const Duration(days: 5)));
  }

  bool isInactiveRetention(Member m) {
    final now = DateTime.now();

    if (m.checkIns.isEmpty) return true;

    final lastCheckIn = m.checkIns.reduce(
      (a, b) => a.isAfter(b) ? a : b,
    );

    return lastCheckIn.isBefore(now.subtract(const Duration(days: 7)));
  }

  Widget filterButton(String label) {
    final isSelected = selectedFilter == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = label;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF007AFF)
                : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildStatus(Member m) {
    final status = getStatus(m);

    switch (status) {
      case MemberStatus.cancelled:
        return const Text(
          "CANCELLED",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        );

      case MemberStatus.paused:
        return const Text(
          "PAUSED",
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
        );

      case MemberStatus.expired:
        return const Text(
          "EXPIRED",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        );

      case MemberStatus.active:
        return const Text(
          "ACTIVE",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
        );

      case MemberStatus.inactive:
        return const Text(
          "INACTIVE",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
        );
    }
  }

  void _showActions(Member member) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Member"),
              onTap: () {
                Navigator.pop(context);
                widget.onEditMember(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Member"),
              onTap: () {
                Navigator.pop(context);
                widget.onDeleteMember(member);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget buildAvatar(String? url, String fallback) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFE5E5EA),
        child: Text(fallback),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFE5E5EA),
      backgroundImage: CachedNetworkImageProvider(
        url,
        cacheKey: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.members.where((member) {
      final query = searchQuery.toLowerCase();

      final matchesSearch =
          member.firstName.toLowerCase().contains(query) ||
          member.lastName.toLowerCase().contains(query) ||
          member.id.toLowerCase().contains(query);

      bool matchesFilter = true;
final status = getStatus(member);

if (selectedFilter == "ALL") {
  matchesFilter = true;
} else if (selectedFilter == "ACTIVE") {
  matchesFilter = status == MemberStatus.active;
} else if (selectedFilter == "EXPIRED") {
  matchesFilter = status == MemberStatus.expired;
} else if (selectedFilter == "EXPIRING") {
  matchesFilter = isExpiringSoon(member);
} else if (selectedFilter == "INACTIVE") {
  matchesFilter = isInactiveRetention(member);
} else if (selectedFilter == "PAUSED") { // ✅ ADDED
  matchesFilter = status == MemberStatus.paused;
} else if (selectedFilter == "CANCELLED") { // ✅ ADDED
  matchesFilter = status == MemberStatus.cancelled;
}

      return matchesSearch && matchesFilter;
    }).toList();

    // ✅ ADDED (sort expiring soonest first)
    if (selectedFilter == "EXPIRING") {
      filteredMembers.sort(
        (a, b) => a.expiryDate.compareTo(b.expiryDate),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () { // ✅ MODIFIED
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          ListTile(
  title: const Text("EXPIRED"),
  onTap: () {
    Navigator.pop(context);
    setState(() => selectedFilter = "EXPIRED");
  },
),

ListTile(
  title: const Text("PAUSED"),
  onTap: () {
    Navigator.pop(context);
    setState(() => selectedFilter = "PAUSED");
  },
),

ListTile(
  title: const Text("CANCELLED"),
  onTap: () {
    Navigator.pop(context);
    setState(() => selectedFilter = "CANCELLED");
  },
),

          const SizedBox(height: 10),
        ],
      ),
    ),
  );
},
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    filterButton("ALL"),
                    filterButton("ACTIVE"),
                    filterButton("EXPIRING"),
                    filterButton("INACTIVE"),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search by name or ID",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: filteredMembers.isEmpty
                    ? const Center(child: Text("No members found"))
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh ?? () async {},
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = filteredMembers[index];

                            // ✅ ADDED (days left calc)
                            final daysLeft = member.expiryDate
                                .difference(DateTime.now())
                                .inDays;

                            return GestureDetector(
                              onLongPress: () => _showActions(member),
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),

                                  leading: buildAvatar(
                                    member.photoUrl,
                                    member.firstName.isNotEmpty
                                        ? member.firstName[0].toUpperCase()
                                        : "?",
                                  ),

                                  title: Text(
                                    member.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),

                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        "Expires: ${DateUtilsHelper.formatDate(member.expiryDate)}",
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),

                                      // ✅ ADDED (only show for expiring filter)
                                      if (selectedFilter == "EXPIRING")
                                        Text(
                                          "$daysLeft days left",
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),

                                      if (member.phone.isNotEmpty)
                                        Text(
                                          member.phone,
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                    ],
                                  ),

                                  trailing: buildStatus(member),

                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MemberDetailScreen(
                                                member: member),
                                      ),
                                    );

                                    if (result == true) {
                                      if (widget.onRefresh != null) {
                                        await widget.onRefresh!();
                                      }
                                    } else {
                                      if (mounted) setState(() {});
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}