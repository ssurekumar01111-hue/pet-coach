# PET Coach

**Your AI Physical Test Coach for Government Recruitment**

PET Coach is a mobile app for candidates preparing for Indian government recruitment Physical Efficiency Tests (PET) — UP Home Guard, UP Police, SSC GD, Delhi Police, CRPF, CISF, BSF, and Army Agniveer. Unlike generic running apps, it understands official PET distance/time standards, tracks training in real time using dual-signal (accelerometer + GPS) movement detection, and acts as an AI coach throughout preparation.

Built for **OpenAI Build Week**, using **OpenAI Codex** and **GPT-5.6**.

Designed and developed with OpenAI Codex using GPT-5.6 Terra, while supporting both Gemini Flash-Lite (default) and GPT-5.6 as interchangeable AI coaching providers.

## Why I built this

I'm a Flutter/Firebase developer based in Uttar Pradesh, and PET recruitment is a genuinely big deal here — every year, large numbers of candidates train for UP Home Guard, UP Police, CRPF, and similar exams, and the physical test is often the part that trips people up, not the written one. Every running app out there treats a 4.8km run like a 4.8km run — none of them know what "qualifying" actually means for a specific exam, or reliably tell walking and running apart when someone's pace sits right at the edge.

That gap is what I set out to close with this build.

---

## The problem

Existing running apps (Strava, Nike Run Club, Garmin) are built for general fitness. PET candidates need something narrower and more specific: exam-exact distance/time limits, reliable walk-vs-run detection at real-world paces, and honest feedback on whether they'd actually qualify today — not just a pace chart. No mainstream app targets this audience.

## Who it's for

UP Home Guard · UP Police · SSC GD · Delhi Police · CRPF · CISF · BSF · Army Agniveer candidates.

> Distance/time standards for CRPF, CISF, and BSF are marked `approximate` in the app, since official figures vary by trade/post and change per notification cycle. Users are shown a disclaimer and pointed to verify against the current official notification.

---

## Features

### Core training loop
- **Exam Selection** — pick your target recruitment body; standards pulled from Firestore
- **Continuous Running Tracker** — live pace, distance, and elapsed time
- **Dual-signal Walk/Run Detection** — accelerometer step cadence as the primary signal, with GPS speed as a secondary veto on running transitions. Built specifically to solve GPS drift causing false "running" readings while stationary (see [Testing & Validation](#testing--validation))
- **PET Qualification Predictor** — a **deterministic**, server-computed pass/fail (pure arithmetic against the exam's official distance/time), shown as the qualification banner — independent of the LLM, so it can never hallucinate a result. The AI Coach's narrative feedback is separate and advisory only
- **AI Coach** — post-run feedback and next-session target, generated via Gemini (current default) or GPT-5.6 (selectable per-request)
- **Voice Coach** — live spoken pace/distance cues every 500m during a run, plus text-to-speech readout of AI feedback afterward
- **Recovery Monitor** — a deterministic (non-LLM) rest recommendation based on run intensity vs. recent history
- **Progress Timeline** — session history with a pace trend chart and qualification rate

### AI-driven planning
- **Personalized Training Plans** — 7-day adaptive plan generated from recent session history
- **Adaptive Daily Target** — a fresh "what to do today" recommendation, factoring in yesterday's recovery score
- **Qualification Readiness** — a trend-based readiness percentage and estimated qualification timeline (requires 3+ sessions)
- **Pace Optimization** — deterministic per-kilometer split analysis against target pace, computed client-side from GPS data (no LLM call)
- **Injury Risk (Load Check)** — a cautious, pattern-based training-load signal with a mandatory non-diagnostic disclaimer

### Platform
- **Phone number authentication** (Firebase Auth) with OTP verification
- **Offline-first tracking** — sessions cache locally (Hive) and sync automatically once connectivity returns
- **Leaderboards** — per-exam rankings, gated on the deterministic qualification result only (not the LLM's)
- **Hydration Reminders**, **Stretching Guidance**, **Profile & Cloud Sync**

---

## Tech stack

| Layer | Technology |
|---|---|
| App | Flutter (GetX architecture) |
| Auth | Firebase Phone Authentication |
| Data | Cloud Firestore |
| Backend | Firebase Cloud Functions (TypeScript, Node 20) |
| AI | Gemini 3.1 Flash Lite (default coaching model) and GPT-5.6 (`gpt-5.6-luna`, OpenAI Responses API — selectable as an alternate provider) — swappable behind one shared interface |
| Location | `geolocator` (GPS) + device pedometer (step cadence) |
| Voice | `flutter_tts` |
| Offline storage | Hive |
| Charts | `fl_chart` |

---

## Architecture

```
Flutter App (GetX)
  Auth → Exam Selection → Tracker → Session Summary
                              │
                    ┌─────────────────────┐
                    │ GpsMovementFilter    │  EMA smoothing, jump rejection
                    │ StepCadenceDetector  │  accelerometer-based primary signal
                    │ MovementSegmentRec.  │  fused walk/run segments
                    └─────────────────────┘
                              │
                       Firestore + Hive (offline queue)
                              │
              Cloud Functions (5 callables, TypeScript)
                              │
              ┌───────────────┴───────────────┐
              │                                │
     Deterministic layer                AI Provider layer
   (qualification, recovery,          (GPT-5.6 / Gemini,
    pure arithmetic — cannot          schema-validated,
    be overridden by the LLM)          rate-limited)
```

**Design principle:** anything that determines pass/fail or a public leaderboard ranking is computed **deterministically, server-side**, independent of the LLM. The AI is used for coaching narrative, planning, and pattern-based insight — never as the source of truth for qualification.

---

## Setup

### Prerequisites
- Flutter SDK
- A Firebase project (Blaze plan, required for Cloud Functions)
- An OpenAI API key and/or Gemini API key

### 1. Clone and install
```bash
git clone <this-repo-url>
cd project-pet-coach-ai-flutter-mobile
flutter pub get
```

### 2. Firebase project setup
```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```
This generates `lib/firebase_options.dart`. In the Firebase Console, enable:
- **Authentication → Phone** (add a test phone number + fixed OTP for local dev — see [Judge Testing](#judge--reviewer-testing) below)
- **Firestore Database**
- **Cloud Functions** (requires Blaze plan)

### 3. Set Cloud Function secrets
```bash
firebase functions:secrets:set OPENAI_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
```

### 4. Deploy backend
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
firebase deploy --only firestore:rules,firestore:indexes
```

### 5. Seed exam standards
```bash
npm run seed:exam-configs
```

### 6. Run the app
```bash
flutter run
```

---

## Judge / reviewer testing
**Quickest way to try it:** download the signed APK from [Releases](https://github.com/ssurekumar01111-hue/pet-coach/releases/latest) and install it directly — no build required.

Sign-in uses phone number + OTP. To test without a real SIM, use the Firebase test number configured in this project's Authentication console:

- **Test phone:** `+91 9999999999`
- **Test OTP:** `123456`

This bypasses real SMS entirely — enter the number, then the fixed code, and you're in.

---

## AI / Codex collaboration

I built PET Coach end-to-end with OpenAI Codex using GPT-5.6 Terra. The project evolved in one continuous development session, so the same context carried from the initial architecture decisions through feature implementation, debugging, field testing, and final refinements. Here's roughly how the collaboration went:

- **Scaffolding & architecture** — Codex generated the initial GetX module structure, Firestore data models, and Cloud Functions skeleton from a written spec; I made the product and structural decisions (which features, what data model, GetX vs. alternatives).
- **The AI provider layer** — Codex implemented the provider abstraction, schema validation, token limits, and Firestore transaction-based rate limiting. The architecture supports both Gemini and GPT-5.6 behind a shared provider interface, with Gemini Flash-Lite serving as the default coaching model in the current build.
- **The most difficult engineering problem — walk/run detection** — this went through several real, field-tested iterations with Codex:
  1. Initial GPS-speed-only detection worked, but real-device field testing (sitting stationary) revealed GPS drift was causing false "running" readings.
  2. Codex implemented accuracy-radius GPS filtering — insufficient on its own, since GPS-reported accuracy is often optimistic.
  3. After researching modern approaches to low-speed movement detection, I redesigned the tracker around accelerometer-based step cadence as the primary signal, with GPS acting as a secondary validation layer — Codex implemented this dual-signal system, including a debounce mechanism.
  4. Further field testing found the debounce had a bug (firing on 1/2 confirmations, not 2/2) and that cadence alone still produced false positives during normal walking (arm/phone motion mistaken for running steps) — fixed with a GPS-speed veto specifically gating cadence-triggered "running" transitions.
  5. Each round was verified against real on-device field-test logs (GPS accuracy, cadence, transition timestamps), not just code review — see [Testing & Validation](#testing--validation).
- **Security hardening** — a self-directed repository audit surfaced a real Firestore integrity gap (clients could write AI/qualification result fields directly, undermining the deterministic-qualification guarantee); Codex implemented the rules fix.
- **UI/UX** — Codex built three distinct visual-direction previews (tactical, athletic, SaaS-style) for live on-device comparison; the athletic direction was chosen for practical reasons (outdoor sunlight readability) and implemented as the app-wide design system.

I'll be honest — a good chunk of this build was me finding something broken through real testing, describing exactly what I saw, and going back and forth with Codex until the fix actually held up against a fresh test, not just a green checkmark. That loop is most of what "how we built it" actually means here.

**Codex Session ID:** `019f6557-42bb-77f3-8caf-b329d6259968`

---

## Testing & validation

I didn't trust this to "probably work" — the walk/run detector especially, since it's the whole point of the app. I tested it on my own phone, outdoors, sitting still, walking, and running, and pulled real diagnostic logs after each round rather than going on gut feel. That process caught several real bugs I wouldn't have found any other way:

| Test | Finding | Fix |
|---|---|---|
| Sitting stationary indoors | GPS drift (39–100m accuracy) falsely triggered "running" | Multi-layer fix: accuracy-radius filtering → EMA smoothing → accelerometer step-cadence as primary signal |
| Real walking, arm/phone movement | Cadence briefly spiked to 160–180 spm, falsely flipping to "running" while GPS showed walking-pace speed | GPS-speed veto (≥1.9 m/s required) specifically gating cadence-triggered running transitions |
| Debounce logic | Transitions were firing after 1/2 confirmations instead of the required 2/2 | Fixed confirmation-counting bug, verified via field-test logs showing exact `confirmed=2/2` gating |
| Paused-run duration | Stored session duration included paused time, corrupting pace/recovery calculations | Persist actual stopwatch-tracked active duration, not a raw timestamp delta |

Debug-only, on-device field-test logging (GPS accuracy, cadence, walk/run transitions, voice cue timing, battery drain) was built specifically to support this iterative process — logs can be shared directly from the device via the Profile screen, without needing a tethered connection.

---

## Why this isn't just another running app

| | Generic running apps | PET Coach |
|---|---|---|
| **Built for** | General fitness, races, recreational runners | Indian government PET candidates specifically |
| **Shows** | Pace, distance, calories | Deterministic qualification against official PET standards |
| **Coaching** | Generic training advice | Exam-specific, tied to the recruitment body you actually selected |
| **Movement detection** | Treats all fast movement as running | Dual-signal (step cadence + GPS veto) to separate walking from running at PET training speeds |
| **Progress tracking** | Fitness metrics | Exam readiness, qualification trend, recovery, daily targets |
| **Goals** | One-size-fits-all | Exam-specific standards per recruitment body |
| **Focus** | Athletic performance | Passing a specific, real physical test |

I'd sum up the whole design philosophy in one line: **fitness apps optimize training, PET Coach optimizes qualification.** That's why the qualification result and leaderboard eligibility are computed with deterministic server-side logic — not an LLM — while everything else that benefits from AI (coaching tone, plans, explanations) actually gets it.

---

## Known limitations & roadmap

PET Coach was built during the OpenAI Build Week hackathon, so there are still a few areas I'd improve before calling it production-ready:

**Before any public release:**
- Background GPS tracking is not implemented — the app must stay in the foreground during a run. `ACCESS_BACKGROUND_LOCATION` is currently declared but unused and should be either implemented properly (foreground service + persistent notification) or removed.
- iOS Firebase configuration is incomplete — this build targets Android only.
- No privacy policy, account deletion flow, or data export — required before any Play Store listing given the app collects location and phone number data.
- PET Qualification Predictor is calibrated on assumed pace patterns, not validated against real, official exam results.

**Roadmap:**
- Smartwatch/heart-rate integration (deferred — no test hardware available during this build)
- Human coach dashboard for overseeing multiple candidates (deferred — requires a second account-role architecture, not scoped for this build)
- CI/CD, crash reporting, analytics, dark mode, onboarding flow
- Firebase App Check and stricter Firestore field-level schema enforcement

---

## License

MIT License — see [LICENSE](LICENSE) for details.