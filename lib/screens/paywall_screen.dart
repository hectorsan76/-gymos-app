import 'package:flutter/material.dart';
import '../services/purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _svc = PurchaseService();
  bool _loading = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _svc.isProNotifier.addListener(_onProChanged);
  }

  @override
  void dispose() {
    _svc.isProNotifier.removeListener(_onProChanged);
    super.dispose();
  }

  void _onProChanged() {
    if (_svc.isPro && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to GymOS Pro!')),
      );
    }
  }

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    try {
      await _svc.buyMonthly();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    try {
      await _svc.restorePurchases();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _svc.monthlyProduct;
    final price = product?.price ?? '\$9.99';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 44,
                  color: Color(0xFF2ECC71),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'GymOS Pro',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Run your gym like a pro',
                style: TextStyle(fontSize: 16, color: Colors.white60),
              ),

              const SizedBox(height: 36),

              ...[
                (Icons.bar_chart, 'Analytics Dashboard',
                    'Track revenue and member growth'),
                (Icons.receipt_long, 'Sales Reports',
                    'Full history of all payments'),
                (Icons.people, 'Unlimited Members',
                    'No cap on your roster'),
                (Icons.support_agent, 'Priority Support',
                    'Get help when you need it'),
              ].map((f) => _feature(f.$1, f.$2, f.$3)),

              const Spacer(),

              Text(
                '$price / month',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Cancel anytime in App Store settings',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _loading ? null : _subscribe,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Subscribe Now',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _restoring ? null : _restore,
                child: Text(
                  _restoring ? 'Restoring...' : 'Restore Purchases',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
