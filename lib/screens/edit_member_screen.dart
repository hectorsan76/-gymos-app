import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../models/member.dart';

class EditMemberScreen extends StatefulWidget {
  final Member member;

  const EditMemberScreen({super.key, required this.member});

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController addressController;
  late TextEditingController countryController;
  late TextEditingController instagramController;
  late TextEditingController notesController;

  Uint8List? newImageBytes;
  bool isSaving = false;
  bool isDeleting = false; // ✅ ADDED

  @override
  void initState() {
    super.initState();

    final m = widget.member;

    firstNameController = TextEditingController(text: m.firstName);
    lastNameController = TextEditingController(text: m.lastName);
    phoneController = TextEditingController(text: m.phone);
    emailController = TextEditingController(text: m.email);
    addressController = TextEditingController(text: m.address ?? "");
    countryController = TextEditingController(text: m.country ?? "");
    instagramController = TextEditingController(text: m.instagram ?? "");
    notesController = TextEditingController(text: m.notes ?? "");
  }

  Future<void> pickImage() async {
    if (isSaving || isDeleting) return; // ✅ MODIFIED

    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 50,
        minWidth: 500,
        minHeight: 500,
      );

      if (!mounted) return;

      setState(() {
        newImageBytes = Uint8List.fromList(compressed);
      });
    } catch (_) {
      setState(() {
        newImageBytes = bytes;
      });
    }
  }

  Future<String?> uploadImage() async {
    if (newImageBytes == null) return widget.member.photoUrl;

    try {
      final fileName = "${widget.member.id}.jpg";

      await supabase.storage.from('member-photos').uploadBinary(
            fileName,
            newImageBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final baseUrl = supabase.storage
          .from('member-photos')
          .getPublicUrl(fileName);

      return "$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}";
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChanges() async {
    if (isSaving || isDeleting) return; // ✅ MODIFIED

    FocusScope.of(context).unfocus();
    setState(() => isSaving = true);

    final photoUrl = await uploadImage();

    if (photoUrl == null) {
      setState(() => isSaving = false);
      return;
    }

    try {
      await supabase.from('members').update({
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
        'country': countryController.text.trim(),
        'instagram': instagramController.text.trim(),
        'notes': notesController.text.trim(),
        'photo_url': photoUrl,
      }).eq('id', widget.member.id);

      widget.member.firstName = firstNameController.text.trim();
      widget.member.lastName = lastNameController.text.trim();
      widget.member.phone = phoneController.text.trim();
      widget.member.email = emailController.text.trim();
      widget.member.address = addressController.text.trim();
      widget.member.country = countryController.text.trim();
      widget.member.instagram = instagramController.text.trim();
      widget.member.notes = notesController.text.trim();
      widget.member.photoUrl = photoUrl;

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> deleteMember() async { // ✅ ADDED
    if (isSaving || isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Member"),
        content: const Text(
          "This will permanently remove this member from your gym. Their purchase and check-in history will remain stored.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isDeleting = true);

    try {
      await supabase.from('members').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.member.id);

      if (!mounted) return;

      Navigator.pop(context, "deleted");
    } catch (e) {
      debugPrint("DELETE MEMBER ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not delete member")),
      );

      setState(() => isDeleting = false);
    }
  }

  Widget buildAvatar(String fallback) {
    if (newImageBytes != null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[300],
        backgroundImage: MemoryImage(newImageBytes!),
      );
    }

    final url = widget.member.photoUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[300],
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[300],
      child: Text(fallback),
    );
  }

  Widget input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !isSaving && !isDeleting, // ✅ MODIFIED
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter = firstNameController.text.isNotEmpty
        ? firstNameController.text[0].toUpperCase()
        : "?";

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Member")),
      body: AbsorbPointer(
        absorbing: isSaving || isDeleting, // ✅ MODIFIED
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  Stack( // ✅ ADDED
                    children: [
                      buildAvatar(firstLetter),
                      Positioned( // ✅ ADDED
                        bottom: 0,
                        right: 0,
                        child: GestureDetector( // ✅ ADDED
                          onTap: pickImage,
                          child: Container( // ✅ ADDED
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  input("First Name", firstNameController),
                  input("Last Name", lastNameController),
                  input("Phone", phoneController),
                  input("Email", emailController),

                  const Divider(),

                  input("Address", addressController),
                  input("Country", countryController),
                  input("Instagram", instagramController),
                  input("Notes", notesController),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving || isDeleting ? null : saveChanges, // ✅ MODIFIED
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Changes"),
                    ),
                  ),

                  const SizedBox(height: 12), // ✅ ADDED

                  SizedBox( // ✅ ADDED
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: isSaving || isDeleting ? null : deleteMember,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: isDeleting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Delete Member"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}