# GYMOS

Simple gym management app for front desk staff.

## What it does

- Add members
- Sell memberships
- Check in members
- Track activity and purchases

Built for speed and simplicity.

---

## Tech Stack

- Flutter (mobile + web)
- Supabase (database + auth + realtime)

---

## Project Structure

lib/
  models/ → data models
  screens/ → UI screens
  utils/ → helpers
  main.dart → app entry

---

## Core Flow

1. Add Member
2. Sell Membership
3. Check In Member
4. View Member Details

---

## Important Notes

- This is an MVP
- Optimized for tablet + desktop front desk use
- UI is being standardized via a global theme system

---

## Setup Instructions

1. Install Flutter
2. Run: flutter pub get
3. Flutter run

---

## Supabase

- Project connected via `main.dart`
- Uses:
  - members table
  - renewals table
  - check_ins table

---

## Current Status

- Core functionality complete
- UI cleanup in progress

---

## Next Steps

- Global UI theme system
- Standardized components
- Improve dashboard
- Improve check-in speed

---

## Owner

Hector Sanchez
