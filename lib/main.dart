import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/member.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  if (savedTheme == 'dark') themeNotifier.value = ThemeMode.dark;
  if (savedTheme == 'light') themeNotifier.value = ThemeMode.light;

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  await Supabase.initialize(
    url: 'https://vvnzhdmmcduwtvipxyhq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2bnpoZG1tY2R1d3R2aXB4eWhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MTEyMDAsImV4cCI6MjA5MDQ4NzIwMH0.geIiZWVib11VOEyyhrO9Eg5SP9UGoiYD0E4rHipYK3E',
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );

  await PurchaseService().init(); // ✅ CRITICAL FOR IAP

  runApp(const GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;

  bool? _isLoggedIn;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    _initAuth();

    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      final loggedIn = data.session != null;

      debugPrint("AUTH CHANGE: event=${data.event} loggedIn=$loggedIn");

      if (!mounted) return;

      setState(() => _isLoggedIn = loggedIn);

      if (data.session != null) {
        supabase.realtime.setAuth(data.session!.accessToken);
        debugPrint("✅ REALTIME AUTH SET (AUTH CHANGE)");
      }
    });
  }

  Future<void> _initAuth() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final session = supabase.auth.currentSession;

    debugPrint("AUTH INIT: session=$session");

    if (!mounted) return;

    setState(() {
      _isLoggedIn = session != null;
    });

    if (session != null) {
      supabase.realtime.setAuth(session.accessToken);
      debugPrint("✅ REALTIME AUTH SET (INIT)");
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoggedIn == false) {
      return const LoginScreen();
    }

    return const MembersShell();
  }
}

class MembersShell extends StatefulWidget {
  const MembersShell({super.key});

  @override
  State<MembersShell> createState() => _MembersShellState();
}

class _MembersShellState extends State<MembersShell> {
  final supabase = Supabase.instance.client;

  List<Member> _members = [];
  bool _loading = true;
  String? _error;

  bool _isFetching = false;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();

    _fetchMembers();

    Future.delayed(const Duration(seconds: 2), () async {
      await supabase.auth.refreshSession();
      _setupRealtime();
    });
  }

  Future<void> _setupRealtime() async {
    final session = supabase.auth.currentSession;

    if (session == null || session.isExpired) {
      debugPrint("❌ REALTIME FAILED: no valid session");
      return;
    }

    supabase.realtime.setAuth(session.accessToken);
    debugPrint("✅ REALTIME AUTH CONFIRMED");

    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }

    _channel = supabase.channel('check_ins_channel');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'check_ins',
          callback: (payload) {
            final memberId = payload.newRecord['member_id'];

            final member = _members.firstWhere(
              (m) => m.id == memberId,
              orElse: () => Member(
                id: "0",
                firstName: "Someone",
                lastName: "",
                expiryDate: DateTime.now(),
                phone: "",
                email: "",
              ),
            );

            final name = member.id == "0"
                ? "Member"
                : "${member.firstName} ${member.lastName}";

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("🔥 $name just checked in"),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            _fetchMembers();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    if (_isFetching) return;

    _isFetching = true;

    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => _loading = false);
        _isFetching = false;
        return;
      }

      final data = await supabase
          .from('members')
          .select('*, check_ins(created_at)')
          .eq('gym_id', user.id)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final members = (data as List)
          .map((e) {
            try {
              final member = Member.fromJson(e);

              final checkInsRaw = e['check_ins'] as List? ?? [];

              member.checkIns = checkInsRaw
                  .map((c) => DateTime.parse(c['created_at']))
                  .toList();

              return member;
            } catch (_) {
              return null;
            }
          })
          .whereType<Member>()
          .toList();

      if (!mounted) return;

      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _deleteMember(Member member) async {
    try {
      await supabase
          .from('members')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', member.id);

      await _fetchMembers();
    } catch (e) {
      debugPrint("DELETE ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text("Error: $_error")),
      );
    }

    return HomeScreen(
      members: _members,
      onUpdate: _fetchMembers,
      onEditMember: (_) {},
      onDeleteMember: _deleteMember,
    );
  }
}
