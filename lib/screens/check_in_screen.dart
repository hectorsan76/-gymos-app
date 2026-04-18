import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';

class CheckInScreen extends StatefulWidget {
  final List<Member> members;
  final Function() onUpdate;

  const CheckInScreen({
    super.key,
    required this.members,
    required this.onUpdate,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final TextEditingController controller = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final AudioPlayer player = AudioPlayer();

  final supabase = Supabase.instance.client;

  Member? currentMember;
  String? message;
  String? subMessage;
  bool _isProcessing = false;
  Color? flashColor;

  String searchQuery = "";

  void resetScreen() {
    if (!mounted) return;
    setState(() {
      currentMember = null;
      message = null;
      subMessage = null;
      searchQuery = "";
      controller.clear();
      searchController.clear();
    });
  }

  void triggerFlash(Color color) {
    if (!mounted) return;

    setState(() {
      flashColor = color;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          flashColor = null;
        });
      }
    });
  }

  Future<void> processMember(Member found) async {
    if (_isProcessing) return;
    _isProcessing = true;

    if (found.id == "0") {
      setState(() {
        currentMember = found;
        message = "MEMBER NOT FOUND";
        subMessage = "See front desk";
      });

      triggerFlash(Colors.red);
      player.play(AssetSource('error.mp3'));

      Future.delayed(const Duration(seconds: 4), resetScreen);

      _isProcessing = false;
      return;
    }

    final res = await supabase
        .from('members')
        .select(
            'id, first_name, last_name, email, phone, photo_url, expiry_date, paused_until, is_cancelled, membership_type')
        .eq('id', found.id)
        .single();

    final member = Member.fromJson(res);

    final hasPlan = member.membershipType != null &&
        member.membershipType!.isNotEmpty;

    final isPaused = member.pausedUntil != null &&
        member.pausedUntil!.isAfter(DateTime.now());

    final isActive = hasPlan &&
        !member.isCancelled &&
        member.expiryDate.isAfter(DateTime.now());

    bool isSuccess = false;

    if (!mounted) return;

    setState(() {
      currentMember = member;
    });

    // ❌ NO PLAN
    if (!hasPlan) {
      message = "NO PLAN";
      subMessage = "Purchase membership";
      triggerFlash(Colors.grey);
      player.play(AssetSource('error.mp3'));

    }
    // ❌ CANCELLED
    else if (member.isCancelled) {
      message = "CANCELLED";
      subMessage = "See front desk";
      triggerFlash(Colors.red);
      player.play(AssetSource('error.mp3'));

    }
    // ❌ PAUSED
    else if (isPaused) {
      message = "PAUSED";
      subMessage = "See front desk";
      triggerFlash(Colors.orange);
      player.play(AssetSource('error.mp3'));

    }
    // ❌ EXPIRED
    else if (!isActive) {
      message = "EXPIRED";
      subMessage = "Renew membership";
      triggerFlash(Colors.red);
      player.play(AssetSource('error.mp3'));

    }
    // ✅ SUCCESS
    else {
      try {
        final user = supabase.auth.currentUser;

        if (user == null) {
          throw Exception("User not logged in");
        }

        await supabase.from('check_ins').insert({
          'member_id': member.id,
          'gym_id': user.id,
        });

        member.checkIns.add(DateTime.now());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🔥 ${member.fullName} checked in"),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        message = "CHECKED IN";
        subMessage = null;
        triggerFlash(Colors.green);
        player.play(AssetSource('success.mp3'));
        isSuccess = true;
      } catch (e) {
        debugPrint("CHECK-IN ERROR: $e");

        message = "ERROR";
        subMessage = "Try again";
        triggerFlash(Colors.red);
        player.play(AssetSource('error.mp3'));
      }
    }

    if (mounted) setState(() {});

    searchQuery = "";
    searchController.clear();

    if (isSuccess) {
      await widget.onUpdate();
      Future.delayed(const Duration(milliseconds: 2500), resetScreen);
    } else {
      Future.delayed(const Duration(seconds: 4), resetScreen);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      _isProcessing = false;
    });
  }

  Future<void> handleScan() async {
    if (_isProcessing) return;

    final input = controller.text.trim();
    if (input.length < 6) return;

    final found = widget.members.firstWhere(
      (m) => m.id == input,
      orElse: () => Member(
        id: "0",
        firstName: "Unknown",
        lastName: "Member",
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        phone: "N/A",
        email: "N/A",
      ),
    );

    await processMember(found);
  }

  Widget buildAvatar(String? url, String fallback) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[300],
        child: Text(fallback),
      );
    }

    return CircleAvatar(
      radius: 40,
      backgroundImage: CachedNetworkImageProvider(url),
      backgroundColor: Colors.grey[300],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.members.where((m) {
      return m.fullName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    final isPaused = currentMember?.pausedUntil != null &&
        currentMember!.pausedUntil!.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text("Check-In")),
      body: Stack(
        children: [
          if (flashColor != null)
            Container(color: flashColor!.withOpacity(0.2)),

          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search Member",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    if (searchQuery.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final m = filtered[i];

                          return Card(
                            child: ListTile(
                              leading: buildAvatar(
                                  m.photoUrl, m.firstName[0].toUpperCase()),
                              title: Text(m.fullName),
                              subtitle: Text(m.email),
                              onTap: () => processMember(m),
                            ),
                          );
                        },
                      )
                    else ...[
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: "Enter Member ID",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length >= 6) handleScan();
                        },
                      ),

                      const SizedBox(height: 20),

                      if (message != null)
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 160,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: message == "CHECKED IN"
                                    ? Colors.green
                                    : (isPaused ? Colors.orange : Colors.red),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                message!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),

                            if (subMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                subMessage!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),

                      const SizedBox(height: 20),

                      if (currentMember != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              children: [
                                buildAvatar(
                                  currentMember!.photoUrl,
                                  currentMember!.firstName[0].toUpperCase(),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  currentMember!.fullName,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currentMember!.email,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Expires: ${DateUtilsHelper.formatDate(currentMember!.expiryDate)}",
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}