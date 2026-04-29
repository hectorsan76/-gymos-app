import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ ADDED

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

  final MobileScannerController cameraController = MobileScannerController(); // ✅ ADDED

  Member? currentMember;
  String? message;
  String? subMessage;
  bool _isProcessing = false;
  Color? flashColor;

  String searchQuery = "";

  // ✅ ADDED (match Home green)
  final Color successGreen = const Color(0xFF2ECC71);

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

  void onDetect(BarcodeCapture capture) async { // ✅ ADDED
    if (_isProcessing) return;

    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    if (code == null || code.length < 6) return;

    final found = widget.members.firstWhere(
      (m) => m.id == code,
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

  Future<void> processMember(Member found) async {
    if (_isProcessing) return;
    FocusScope.of(context).unfocus(); // ✅ ADDED
    _isProcessing = true;

    if (found.id == "0") {
      setState(() {
        currentMember = found;
        message = "MEMBER NOT FOUND";
        subMessage = "See front desk";
      });

      triggerFlash(Colors.red.shade600); // ✅ MODIFIED
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

    if (!hasPlan) {
      message = "NO PLAN";
      subMessage = "Purchase membership";
      triggerFlash(Colors.grey.shade600); // ✅ MODIFIED
      player.play(AssetSource('error.mp3'));
    }
    else if (member.isCancelled) {
      message = "CANCELLED";
      subMessage = "See front desk";
      triggerFlash(Colors.red.shade600); // ✅ MODIFIED
      player.play(AssetSource('error.mp3'));
    }
    else if (isPaused) {
      message = "PAUSED";
      subMessage = "See front desk";
      triggerFlash(Colors.orange.shade600); // ✅ MODIFIED
      player.play(AssetSource('error.mp3'));
    }
    else if (!isActive) {
      message = "EXPIRED";
      subMessage = "Renew membership";
      triggerFlash(Colors.red.shade600); // ✅ MODIFIED
      player.play(AssetSource('error.mp3'));
    }
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
        triggerFlash(successGreen); // ✅ MODIFIED
        player.play(AssetSource('success.mp3'));
        isSuccess = true;
      } catch (e) {
        debugPrint("CHECK-IN ERROR: $e");

        message = "ERROR";
        subMessage = "Try again";
        triggerFlash(Colors.red.shade600); // ✅ MODIFIED
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
        backgroundColor: Colors.grey[400],
        child: Text(
          fallback,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return CircleAvatar(
      radius: 40,
      backgroundImage: CachedNetworkImageProvider(url),
      backgroundColor: Colors.grey[400],
    );
  }

  @override
  void dispose() { // ✅ ADDED
    cameraController.dispose();
    super.dispose();
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
                  crossAxisAlignment: CrossAxisAlignment.center, // ✅ ADDED
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search Member",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length >= 6) handleScan();
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox( // ✅ ADDED
                        width: double.infinity,
                        height: 320,
                        child: message != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.center, // ✅ ADDED
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 120,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: message == "CHECKED IN"
                                          ? successGreen // ✅ MODIFIED
                                          : (isPaused
                                              ? Colors.orange.shade600
                                              : Colors.red.shade600), // ✅ MODIFIED
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      message!,
                                      textAlign: TextAlign.center, // ✅ ADDED
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 38,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),

                                  if (subMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      subMessage!,
                                      textAlign: TextAlign.center, // ✅ ADDED
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  if (currentMember != null)
                                    Expanded(
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              buildAvatar(
                                                currentMember!.photoUrl,
                                                currentMember!.firstName[0].toUpperCase(),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      currentMember!.fullName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.bold),
                                                    ),
                                                    Text(
                                                      currentMember!.email,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "Expires: ${DateUtilsHelper.formatDate(currentMember!.expiryDate)}",
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_scanner,
                                      size: 46,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Ready to scan",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      "Show member QR code to camera",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      const SizedBox(height: 16), // ✅ ADDED

                      SizedBox( // ✅ ADDED
                        height: 260,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              MobileScanner(
                                controller: cameraController,
                                onDetect: onDetect,
                              ),
                              Center(
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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