import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../main.dart' show themeNotifier;
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool loading = true;
  bool saving = false;
  bool isLoggingOut = false;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final avatarController = TextEditingController();
  final emailController = TextEditingController();

  // ✅ NEW
  String selectedCurrency = "USD";
  final currencies = ["USD", "IDR", "EUR", "AUD", "GBP"];

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      emailController.text = user.email ?? "";

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        nameController.text = data['full_name'] ?? "";
        phoneController.text = data['phone'] ?? "";
        avatarController.text = data['avatar_url'] ?? "";
        selectedCurrency = data['currency'] ?? "USD"; // ✅ NEW
      }

      if (!mounted) return;

      setState(() {
        profile = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("PROFILE LOAD ERROR: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // 🔥 WARNING SYSTEM
  void showCurrencyWarning(String newCurrency) {
    if (newCurrency == selectedCurrency) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder( // ✅ ADDED
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Change Currency?"),
        content: const Text(
          "Changing currency will affect how revenue is displayed.\n\n"
          "It will NOT convert existing amounts.\n\n"
          "Only change this if you are sure.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final user = supabase.auth.currentUser;
              if (user == null) return;

              await supabase.from('profiles').update({
                'currency': newCurrency,
              }).eq('id', user.id);

              if (!mounted) return;

              setState(() {
                selectedCurrency = newCurrency;
              });
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> pickAndUploadImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);

      if (file == null) {
        debugPrint("NO IMAGE SELECTED");
        return;
      }

      final originalBytes = await file.readAsBytes(); // ✅ MODIFIED

      final compressed = await FlutterImageCompress.compressWithList( // ✅ ADDED
        originalBytes,
        quality: 60,
        minWidth: 800,
        minHeight: 800,
      );

      final bytes = compressed; // ✅ ADDED

      final filePath = "${user.id}/avatar.jpg";

      debugPrint("UPLOADING AVATAR...");

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          supabase.storage.from('avatars').getPublicUrl(filePath);

      final cacheBustedUrl =
          "$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}";

      debugPrint("UPLOAD SUCCESS: $cacheBustedUrl");

      if (!mounted) return;

      setState(() {
        avatarController.text = cacheBustedUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avatar updated")),
      );
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  Future<void> saveProfile() async {
    if (saving) return;

    setState(() => saving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final updates = {
        'id': user.id,
        'full_name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'avatar_url': avatarController.text.trim(),
      };

      await supabase.from('profiles').upsert(updates);

      final newEmail = emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await supabase.auth.updateUser(
          UserAttributes(email: newEmail),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
    } catch (e) {
      debugPrint("SAVE ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save")),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> logout() async {
    if (isLoggingOut) return;

    setState(() => isLoggingOut = true);

    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("LOGOUT ERROR: $e");
      if (!mounted) return;
      setState(() => isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final avatarUrl = avatarController.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent, // ✅ ADDED
        elevation: 0, // ✅ ADDED
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ ADDED
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Container( // ✅ ADDED
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: pickAndUploadImage,
                    child: avatarUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(avatarUrl),
                          )
                        : const CircleAvatar(
                            radius: 40,
                            child: Icon(Icons.camera_alt),
                          ),
                  ),

                  const SizedBox(height: 8),
                  const Text("Tap to upload photo"),

                  const SizedBox(height: 20),

                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Full Name"),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "Phone"),
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Currency",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  DropdownButton<String>(
                    value: selectedCurrency,
                    isExpanded: true,
                    items: currencies.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        showCurrencyWarning(value);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dark mode toggle
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return Card(
                  child: SwitchListTile(
                    title: const Text('Dark Mode'),
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                    ),
                    value: isDark,
                    onChanged: (val) async {
                      themeNotifier.value =
                          val ? ThemeMode.dark : ThemeMode.light;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                          'theme_mode', val ? 'dark' : 'light');
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saving ? null : saveProfile,
                child: saving
                    ? const SizedBox( // ✅ MODIFIED
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Save Profile"),
              ),
            ),

            const SizedBox(height: 12), // ✅ MODIFIED

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton( // ✅ MODIFIED
                onPressed: isLoggingOut ? null : logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: isLoggingOut
                    ? const SizedBox( // ✅ MODIFIED
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}