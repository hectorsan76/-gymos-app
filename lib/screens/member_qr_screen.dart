import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:screenshot/screenshot.dart';

import '../models/member.dart';
import '../utils/date_utils.dart';
import '../utils/web_download.dart';

class MemberQRScreen extends StatefulWidget {
  final Member member;

  const MemberQRScreen({super.key, required this.member});

  @override
  State<MemberQRScreen> createState() => _MemberQRScreenState();
}

class _MemberQRScreenState extends State<MemberQRScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  bool isBusy = false;

  String getStatus(Member m) {
    if (m.isCancelled) return "CANCELLED";

    if (m.pausedUntil != null &&
        m.pausedUntil!.isAfter(DateTime.now())) {
      return "PAUSED";
    }

    if (!m.isActive) return "EXPIRED";

    return "ACTIVE";
  }

  String get safeId {
    final id = widget.member.id;
    final isUuid = id.contains("-") && id.length > 30;

    if (!isUuid) {
      debugPrint("INVALID QR ID: $id");
      return "INVALID_MEMBER_ID";
    }

    return id;
  }

  String get qrUrl {
    return "https://quickchart.io/qr?size=400&text=$safeId";
  }

  String getFileName() {
    final cleanName =
        widget.member.fullName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return "gymos_${cleanName}_card.png";
  }

  Future<void> copyLink() async {
    await Clipboard.setData(ClipboardData(text: qrUrl));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("QR link copied")),
    );
  }

  Future<void> downloadCard() async {
    if (isBusy) return;
    setState(() => isBusy = true);

    final image = await screenshotController.capture(pixelRatio: 3);

    if (image == null) {
      if (mounted) setState(() => isBusy = false);
      return;
    }

    final fileName = getFileName();

    try {
      if (kIsWeb) {
        downloadFile(image, fileName);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');

        await file.writeAsBytes(image);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$fileName saved")),
        );
      }
    } catch (e) {
      debugPrint("DOWNLOAD ERROR: $e");
    }

    if (mounted) setState(() => isBusy = false);
  }

  Widget buildProfileImage(Member m) {
    final url = m.photoUrl;

    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        radius: 28,
        child: Icon(Icons.person),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundImage: CachedNetworkImageProvider(url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final status = getStatus(m);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ MODIFIED
      appBar: AppBar(
        title: const Text("Member Pass"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// CARD (captured)
              Screenshot(
                controller: screenshotController,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, // ✅ MODIFIED
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "GYMOS",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2, // ✅ ADDED
                        ),
                      ),

                      const SizedBox(height: 20),

                      buildProfileImage(m),

                      const SizedBox(height: 20),

                      CachedNetworkImage(
                        imageUrl: qrUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 20),

                      Text(
                        m.fullName,
                        textAlign: TextAlign.center, // ✅ ADDED
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        status,
                        style: TextStyle(
                          color: status == "ACTIVE"
                              ? const Color(0xFF4DCCC2) // ✅ MODIFIED
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Expires: ${DateUtilsHelper.formatDate(m.expiryDate)}",
                        style: const TextStyle(color: Colors.grey), // ✅ ADDED
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// BUTTONS (clean)
              SizedBox(
                width: double.infinity,
                height: 50, // ✅ ADDED
                child: ElevatedButton(
                  onPressed: isBusy ? null : downloadCard,
                  child: isBusy
                      ? const SizedBox( // ✅ ADDED
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Download Member Pass"),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 50, // ✅ ADDED
                child: OutlinedButton( // ✅ MODIFIED
                  onPressed: copyLink,
                  child: const Text("Copy QR Link"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}