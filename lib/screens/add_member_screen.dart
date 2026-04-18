import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final supabase = Supabase.instance.client;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final countryController = TextEditingController();
  final instagramController = TextEditingController();
  final notesController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  Uint8List? imageBytes;
  bool isSaving = false;

  String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return;

    final resized = img.copyResize(image, width: 600);
    final compressed = img.encodeJpg(resized, quality: 60);

    setState(() {
      imageBytes = Uint8List.fromList(compressed);
    });
  }

  Future<String?> uploadImage(String memberId) async {
    if (imageBytes == null) return null;

    try {
      final fileName = "$memberId.jpg";

      await supabase.storage.from('member-photos').uploadBinary(
            fileName,
            imageBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return supabase.storage
          .from('member-photos')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      return null;
    }
  }

  void showError(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool isValidPhone(String phone) {
    return phone.length >= 8 && RegExp(r'^[0-9+]+$').hasMatch(phone);
  }

  Future<void> saveMember() async {
    if (isSaving) return;

    FocusScope.of(context).unfocus();

    final user = supabase.auth.currentUser;

    if (user == null) {
      showError("Not logged in");
      return;
    }

    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();

    if (first.isEmpty || last.isEmpty) {
      showError("First and last name required");
      return;
    }

    if (!isValidPhone(phone)) {
      showError("Invalid phone");
      return;
    }

    if (!isValidEmail(email)) {
      showError("Invalid email");
      return;
    }

    setState(() => isSaving = true);

    try {
      final inserted = await supabase
          .from('members')
          .insert({
            'gym_id': user.id,
            'first_name': capitalize(first),
            'last_name': capitalize(last),
            'phone': phone,
            'email': email,
            'address': addressController.text.trim(),
            'country': countryController.text.trim(),
            'instagram': instagramController.text.trim(),
            'notes': notesController.text.trim(),

            // ✅ CLEAN DEFAULT STATE (NO MEMBERSHIP)
            'expiry_date': DateTime.now().toIso8601String(),
            'paused_until': null,
            'remaining_days_on_pause': null,
            'is_cancelled': false,
            'membership_type': null,
          })
          .select()
          .single();

      final String memberId = inserted['id'].toString();

      if (imageBytes != null) {
        final photoUrl = await uploadImage(memberId);

        if (photoUrl != null) {
          await supabase.from('members').update({
            'photo_url': photoUrl,
          }).eq('id', memberId);
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("SAVE ERROR: $e");
      showError("Save failed");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  ImageProvider? getImage() {
    if (imageBytes != null) {
      return MemoryImage(imageBytes!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter = firstNameController.text.isNotEmpty
        ? firstNameController.text[0].toUpperCase()
        : "?";

    return Scaffold(
      appBar: AppBar(title: const Text("Add Member")),
      body: AbsorbPointer(
        absorbing: isSaving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: getImage(),
                        child: getImage() == null
                            ? Text(
                                firstLetter,
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _input("First Name", firstNameController),
                  _input("Last Name", lastNameController),
                  _input("Phone", phoneController),
                  _input("Email", emailController),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),
                  _input("Address", addressController),
                  _input("Country", countryController),
                  _input("Instagram", instagramController),
                  _input("Notes", notesController),

                  const SizedBox(height: 30),

                  // ✅ ONLY ACTION
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: saveMember,
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Member"),
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

  Widget _input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}