# 2.5D Isometric Financial Farming Game

## Phase 1: Project Scaffolding & Core Engine ✅
- [x] Scaffold Flutter project with proper folder structure
- [x] Set up CustomPainter-based 2.5D isometric rendering engine
  - [x] [gridToScreen](file:///c:/Users/User/Desktop/Project/BorneoHack/mobile-games/lib/engine/isometric_engine.dart#20-28) / [screenToGrid](file:///c:/Users/User/Desktop/Project/BorneoHack/mobile-games/lib/engine/isometric_engine.dart#29-38) math functions
  - [x] Isometric tile rendering with `canvas.drawRect()` / `canvas.drawPath()`
  - [x] Touch input → tile selection via [screenToGrid](file:///c:/Users/User/Desktop/Project/BorneoHack/mobile-games/lib/engine/isometric_engine.dart#29-38)
  - [x] Camera pan/zoom (pinch + drag) via `onScaleUpdate`
- [x] Create pixel-art drawing utilities (code-based, no external images)
  - [x] Crop sprites (wheat, rice, corn — 4 growth stages)
  - [x] Building sprites (bank, merchant shop, farmhouse)
  - [x] Tree sprite + decorative elements
- [x] Dynamic sky background ([SkyPainter](file:///c:/Users/User/Desktop/Project/BorneoHack/mobile-games/lib/engine/sky_painter.dart#15-282))
  - [x] Clear day: blue gradient + sun + drifting clouds
  - [x] Rain/flood: dark sky + rain particle overlay
  - [x] Storm: near-black sky + lightning flashes
  - [x] Drought: orange tint + heat shimmer
- [x] Force landscape orientation + immersive sticky UI
- [x] Unit tests for isometric math (roundtrip verification)

## Phase 2: Firebase Integration ✅
- [x] `.env.local` with Firebase API key, Gemini API key, Google Cloud key
- [x] Set up Firebase project in console (`borneo-hackwknd-richi`)
  - [x] (Skipped google-services.json as native config isn't strictly required for Dart-only initialized Auth/Firestore)
  - [x] Add `firebase_options.dart` (Initialized cleanly via `flutter_dotenv` instead of CLI)
- [x] Implement Firebase Auth (email/password registration via `LoginScreen` and `AuthService`)
- [x] GPS-based country detection → simulated currency assignment (service ready and injected during registration)
- [x] Firestore schema designed (in initial implementation plan)
- [x] Implement Firestore CRUD service (`FirestoreService` read/write player profiles)

## Phase 3: Cloud Functions Backend ✅
- [x] Credit Score algorithm (4-factor: frequency, consistency, avg amount, on-time)
- [x] Weather API disaster check (OpenWeather integration)
- [x] BNPL penalty calculations (RM10 admin + RM23 late fee)
- [x] Loan evaluation logic (credit score ≥600, 5% monthly interest)
- [x] Insurance payout calculations (severity-based)
- [x] Deploy Cloud Functions to Firebase (`firebase deploy --only functions`)
- [x] Configure API keys in Cloud Functions env via local dotenv

## Phase 4: Game Systems & Integrations ✅
- [x] Farming core loop (plant → grow → harvest → sell)
- [x] Cash flow management (Cash + Bank dual payment methods)
- [x] Bank screen — register, deposit/withdraw, loan application, insurance
- [x] Merchant screen — equipment catalog, Buy Now + BNPL (3x/6x installments)
- [x] Active BNPL plan tracking with overdue warnings
- [x] Disaster triggering mechanism (destroy uninsured crops)
- [x] Day advancement system (crops grow per day)
- [x] Connect Bank/Merchant to actual Cloud Functions via `CloudFunctionsService`
- [x] BNPL auto-deduction on `advanceDay()` via Cloud Function with penalty if overdue

## Phase 5: Social & UX ✅
- [x] One-time tutorial popup (landscape-safe, scrollable)
- [x] Financial Advisor NPC warnings (loan risk, BNPL overcommitment, insurance)
- [x] HUD with player profile (name, country flag, credit score, weather status)
- [x] Landscape-optimized HUD layout
- [x] Leaderboard Screen — Regional rankings pulled from Cloud Firestore
- [x] Gemini AI Coaching — Contextual advice using `google_generative_ai` SDK
- [x] Disaster animations — Simulated via Cloud Function triggers overriding screen painters
