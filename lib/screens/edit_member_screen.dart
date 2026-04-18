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
    if (isSaving) return;

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
    if (isSaving) return;

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

  Widget buildAvatar(String fallback) {
    if (newImageBytes != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(newImageBytes!),
      );
    }

    final url = widget.member.photoUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }

    return CircleAvatar(
      radius: 50,
      child: Text(fallback),
    );
  }

  Widget input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !isSaving,
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
        absorbing: isSaving,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  buildAvatar(firstLetter),
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

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveChanges,
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Changes"),
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