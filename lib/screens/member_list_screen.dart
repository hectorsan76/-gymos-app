import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';
import '../utils/responsive.dart';
import 'member_detail_screen.dart';
import 'paywall_screen.dart';
import '../services/purchase_service.dart';

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
                ? Theme.of(context).primaryColor
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium?.color,
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
    final radius = R.avatarRadius(context);
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).cardColor,
        child: Text(fallback),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade400,
      backgroundImage: CachedNetworkImageProvider(url, cacheKey: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = PurchaseService(); // ✅ ADDED

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
        matchesFilter = status == MemberStatus.inactive;
      } else if (selectedFilter == "PAUSED") {
        matchesFilter = status == MemberStatus.paused;
      } else if (selectedFilter == "CANCELLED") {
        matchesFilter = status == MemberStatus.cancelled;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    if (selectedFilter == "EXPIRING") {
      filteredMembers.sort(
        (a, b) => a.expiryDate.compareTo(b.expiryDate),
      );
    }

    return ValueListenableBuilder<bool>( // ✅ ADDED
      valueListenable: purchaseService.isProNotifier, // ✅ ADDED
      builder: (context, isPro, child) {
        if (!isPro) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            );
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return child!;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Members"),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
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

                              final daysLeft = member.expiryDate
                                  .difference(DateTime.now())
                                  .inDays;

                              final cardPad = R.isTablet(context) ? 20.0 : 14.0;
                              final nameSize = R.fontSize(context, 16);
                              final subSize = R.fontSize(context, 13);

                              return GestureDetector(
                                onLongPress: () => _showActions(member),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MemberDetailScreen(member: member),
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
                                    child: Padding(
                                      padding: EdgeInsets.all(cardPad),
                                      child: Row(
                                        children: [
                                          buildAvatar(
                                            member.photoUrl,
                                            member.firstName.isNotEmpty
                                                ? member.firstName[0].toUpperCase()
                                                : "?",
                                          ),
                                          SizedBox(width: R.isTablet(context) ? 16 : 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member.fullName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: nameSize,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Expires: ${DateUtilsHelper.formatDate(member.expiryDate)}",
                                                  style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: subSize),
                                                ),
                                                if (selectedFilter == "EXPIRING")
                                                  Text(
                                                    "$daysLeft days left",
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: subSize,
                                                    ),
                                                  ),
                                                if (member.phone.isNotEmpty)
                                                  Text(
                                                    member.phone,
                                                    style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: subSize),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          buildStatus(member),
                                        ],
                                      ),
                                    ),
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
      ),
    );
  }
}