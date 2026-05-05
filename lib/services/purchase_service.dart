import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // Must match the product ID in App Store Connect
  static const _productId = 'gymos.pro.monthly';
  static const _proKey = 'is_pro';

  final ValueNotifier<bool> isProNotifier = ValueNotifier(false);
  bool get isPro => isProNotifier.value;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];

  ProductDetails? get monthlyProduct =>
      _products.isEmpty ? null : _products.first;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isProNotifier.value = prefs.getBool(_proKey) ?? false;

    if (!await InAppPurchase.instance.isAvailable()) {
      debugPrint('IAP not available on this device');
      return;
    }

    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (e) => debugPrint('IAP stream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final response =
        await InAppPurchase.instance.queryProductDetails({_productId});
    if (response.error != null) {
      debugPrint('Product query error: ${response.error}');
      return;
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Product not found in App Store: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  Future<void> buyMonthly() async {
    if (_products.isEmpty) await _loadProducts();
    if (_products.isEmpty) {
      throw Exception(
          'Product not available — check App Store Connect for $_productId');
    }
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: _products.first),
    );
  }

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setPro(true);
          await InAppPurchase.instance.completePurchase(p);
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
          await InAppPurchase.instance.completePurchase(p);
        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled');
        case PurchaseStatus.pending:
          debugPrint('Purchase pending');
      }
    }
  }

  Future<void> _setPro(bool value) async {
    isProNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, value);
  }

  void unlockProFake() {
    debugPrint('FAKE PRO UNLOCKED (debug only)');
    isProNotifier.value = true;
  }

  void dispose() {
    _sub?.cancel();
  }
}
