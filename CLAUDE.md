# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the App

**Always use VS Code's ▶ play button** (or F5) to run the app — do not run `flutter run` as a background process or through Claude's tool system, as it requires a live TTY and will silently hang.

For Chrome (fast UI iteration, no IAP or camera):
- Change the device to Chrome in the VS Code status bar, then press F5.

For real device (IAP + scanner testing):
- Plug iPhone in via **USB cable** (not wireless — wireless builds are significantly slower).
- Press F5. First build takes 5–10 min due to MLKit/mobile_scanner; subsequent hot reloads are instant.

If a build fails with "database is locked" or "concurrent builds":
```bash
pkill -9 xcodebuild
rm ~/Documents/flutter/bin/cache/lockfile  # if flutter itself is locked
```
Then press ▶ again.

## Architecture

The app is a Flutter gym management tool backed by Supabase. It targets iOS primarily (bundle ID `com.thetrainingnotebook.gymos`).

**Startup flow:** `main()` → initializes Supabase + `PurchaseService` → `AuthGate` listens to Supabase auth stream → routes to `LoginScreen` or loads all members from Supabase and passes them down to `HomeScreen`.

**State model:** There is no state management package. Member data is loaded once at the `AuthGate`/`_GymAppState` level in `main.dart` and passed down as a `List<Member>` prop. Mutations (add/edit/delete/check-in) call `onUpdate()` which re-fetches from Supabase and rebuilds from the top.

**Pro gating:** `PurchaseService` is a singleton with a `ValueNotifier<bool> isProNotifier`. Dashboard and Sales screens are gated — `HomeScreen` wraps those buttons in a `ValueListenableBuilder` and navigates to `PaywallScreen` if `!isPro`. In `kDebugMode` a 🔓 button in the AppBar calls `unlockProFake()` to bypass the gate without a real purchase.

**IAP:** Uses `in_app_purchase` package. Product ID is `gymos.pro.monthly` (matches App Store Connect). Pro state is persisted in `SharedPreferences`. To test real IAP, use a Sandbox Apple ID configured in App Store Connect → Users & Access → Sandbox Testers.

## Key Files

- [lib/main.dart](lib/main.dart) — App entry, Supabase init, AuthGate, member fetch/state, `MembersShell`
- [lib/services/purchase_service.dart](lib/services/purchase_service.dart) — Singleton IAP service, pro state
- [lib/screens/paywall_screen.dart](lib/screens/paywall_screen.dart) — Pro paywall, auto-pops on successful purchase
- [lib/screens/home_screen.dart](lib/screens/home_screen.dart) — Main nav hub, pro-gated buttons
- [lib/screens/check_in_screen.dart](lib/screens/check_in_screen.dart) — QR scanner + member lookup
- [lib/theme/app_theme.dart](lib/theme/app_theme.dart) — All colors via `AppColors`, single `AppTheme.light()`

## Supabase Tables

- `members` — core member records
- `renewals` — payment/renewal history (used by Sales screen)
- `profiles` — gym owner profile (name, avatar, currency preference)
- `check_ins` — stored on the `Member` model as `List<DateTime> checkIns`
- Storage bucket `avatars` — member and profile photos

## Conventions

- Screens receive data as constructor props; they do not fetch independently (except `SalesScreen`, `DashboardScreen`, and `ProfileScreen` which fetch their own data).
- Currency display goes through `CurrencyUtils.format(amount, currency)` — currency is stored per-profile in Supabase.
- `mobile_scanner: 3.2.0` is pinned — do not upgrade without testing; MLKit dependencies have arm64 simulator compatibility issues on iOS 26+.
- `path_provider_foundation: 2.5.1` is pinned in `dependency_overrides` — do not remove.
