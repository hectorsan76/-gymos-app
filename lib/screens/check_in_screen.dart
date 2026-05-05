import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

class _CheckInScreenState extends State<CheckInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final AudioPlayer player = AudioPlayer();
  final supabase = Supabase.instance.client;
  final MobileScannerController cameraController = MobileScannerController();

  late final AnimationController _overlayAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  Member? currentMember;
  String? message;
  String? subMessage;
  bool _isProcessing = false;
  bool _showOverlay = false;
  Color _overlayColor = const Color(0xFF2ECC71);
  bool _isSuccess = false;

  String searchQuery = '';

  static const _successGreen = Color(0xFF2ECC71);

  @override
  void initState() {
    super.initState();
    _overlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _overlayAnim, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _overlayAnim, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _overlayAnim.dispose();
    cameraController.dispose();
    controller.dispose();
    searchController.dispose();
    player.dispose();
    super.dispose();
  }

  void resetScreen() {
    if (!mounted) return;
    _overlayAnim.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showOverlay = false;
        currentMember = null;
        message = null;
        subMessage = null;
        searchQuery = '';
        _isSuccess = false;
        controller.clear();
        searchController.clear();
      });
    });
  }

  void _showResult({
    required Member member,
    required String msg,
    String? sub,
    required Color color,
    required bool success,
  }) {
    if (!mounted) return;
    setState(() {
      currentMember = member;
      message = msg;
      subMessage = sub;
      _overlayColor = color;
      _isSuccess = success;
      _showOverlay = true;
    });
    _overlayAnim.forward(from: 0);
  }

  void onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.length < 6) return;
    final found = widget.members.firstWhere(
      (m) => m.id == code,
      orElse: () => _unknownMember(),
    );
    await processMember(found);
  }

  Member _unknownMember() => Member(
        id: '0',
        firstName: 'Unknown',
        lastName: 'Member',
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        phone: 'N/A',
        email: 'N/A',
      );

  Future<void> processMember(Member found) async {
    if (_isProcessing) return;
    FocusScope.of(context).unfocus();
    _isProcessing = true;

    if (found.id == '0') {
      _showResult(
        member: found,
        msg: 'NOT FOUND',
        sub: 'See front desk',
        color: Colors.red.shade700,
        success: false,
      );
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

    final hasPlan =
        member.membershipType != null && member.membershipType!.isNotEmpty;
    final isPaused = member.pausedUntil != null &&
        member.pausedUntil!.isAfter(DateTime.now());
    final isActive =
        hasPlan && !member.isCancelled && member.expiryDate.isAfter(DateTime.now());

    if (!mounted) return;

    if (!hasPlan) {
      _showResult(
        member: member,
        msg: 'NO PLAN',
        sub: 'Purchase a membership',
        color: Colors.grey.shade700,
        success: false,
      );
      player.play(AssetSource('error.mp3'));
    } else if (member.isCancelled) {
      _showResult(
        member: member,
        msg: 'CANCELLED',
        sub: 'See front desk',
        color: Colors.red.shade700,
        success: false,
      );
      player.play(AssetSource('error.mp3'));
    } else if (isPaused) {
      _showResult(
        member: member,
        msg: 'PAUSED',
        sub: 'Membership is on hold',
        color: Colors.orange.shade700,
        success: false,
      );
      player.play(AssetSource('error.mp3'));
    } else if (!isActive) {
      _showResult(
        member: member,
        msg: 'EXPIRED',
        sub: 'Renew membership',
        color: Colors.red.shade700,
        success: false,
      );
      player.play(AssetSource('error.mp3'));
    } else {
      try {
        final user = supabase.auth.currentUser;
        if (user == null) throw Exception('Not logged in');

        await supabase.from('check_ins').insert({
          'member_id': member.id,
          'gym_id': user.id,
        });

        member.checkIns.add(DateTime.now());
        _showResult(
          member: member,
          msg: 'CHECKED IN',
          sub: null,
          color: _successGreen,
          success: true,
        );
        player.play(AssetSource('success.mp3'));
        await widget.onUpdate();
        Future.delayed(const Duration(milliseconds: 2500), resetScreen);
      } catch (e) {
        debugPrint('CHECK-IN ERROR: $e');
        _showResult(
          member: member,
          msg: 'ERROR',
          sub: 'Try again',
          color: Colors.red.shade700,
          success: false,
        );
        player.play(AssetSource('error.mp3'));
      }
    }

    if (!_isSuccess) {
      Future.delayed(const Duration(seconds: 4), resetScreen);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      _isProcessing = false;
    });

    searchQuery = '';
    searchController.clear();
  }

  Future<void> handleScan() async {
    if (_isProcessing) return;
    final input = controller.text.trim();
    if (input.length < 6) return;
    final found = widget.members.firstWhere(
      (m) => m.id == input,
      orElse: () => _unknownMember(),
    );
    await processMember(found);
  }

  Widget _buildAvatar(String? url, String fallback, {double radius = 40}) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[400],
        child: Text(
          fallback,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(url),
      backgroundColor: Colors.grey[400],
    );
  }

  Widget _buildOverlay() {
    final member = currentMember!;
    final initials = member.firstName.isNotEmpty
        ? member.firstName[0].toUpperCase()
        : '?';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: _overlayColor,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildAvatar(member.photoUrl, initials, radius: 64),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _isSuccess ? Icons.check : Icons.close,
                            color: _overlayColor,
                            size: 24,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      member.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),

                    if (subMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),
                    Text(
                      member.email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),

                    if (!_isSuccess) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Expires: ${DateUtilsHelper.formatDate(member.expiryDate)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.members.where((m) {
      return m.fullName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Member',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => searchQuery = v),
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
                              leading: _buildAvatar(
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
                          hintText: 'Enter Member ID',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          if (v.length >= 6) handleScan();
                        },
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner,
                                size: 46, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'Ready to scan',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Show member QR code to camera',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
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
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_showOverlay)
            Positioned.fill(child: _buildOverlay()),
        ],
      ),
    );
  }
}
