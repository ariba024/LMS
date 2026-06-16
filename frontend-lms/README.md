# Arresto LMS

A modern, mobile-first **Safety Training Learning Management System** built with Flutter Web.

Designed for construction and industrial workplaces to deliver fall-protection, harness, and working-at-heights training to field workers — and manage compliance from a central admin dashboard.

---

## Features

### Learner Portal
- **Dashboard** — progress overview, XP, enrolled courses, upcoming deadlines
- **Course Catalog** — browse and enroll in safety courses
- **My Courses** — track enrolled courses and resume where you left off
- **Lesson Player** — simulated video player with scrub bar, play/pause, knowledge-check MCQ overlay, notes with timestamps, resources and transcript tabs, AI learning companion sidebar
- **Assessments** — take and review quizzes per course
- **Certificates** — download completion certificates
- **Resources** — downloadable PDFs, checklists, and reference guides
- **Arresto AI** — AI-powered safety learning assistant

### Admin Portal
- **Dashboard** — platform-wide stats, learner activity, completion rates
- **All Courses** — manage courses (grid/table view, search, filter by status)
- **Course Generator** — AI-assisted course creation wizard
- **Learners** — manage and view individual learner progress
- **Analytics** — charts and reports for compliance tracking
- **Support** — help-desk ticket management
- **Settings** — platform configuration

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.44+ (Web) |
| Language | Dart 3.12+ |
| State Management | Riverpod 2.x |
| Navigation | GoRouter 13.x |
| UI | Material 3 + Google Fonts (Inter) |
| Charts | fl_chart |
| HTTP Client | Dio |

---

## Prerequisites

Install these before running the project:

1. **Flutter SDK** — version `3.10.0` or higher
   - Download: https://docs.flutter.dev/get-started/install
   - Verify: `flutter --version`

2. **Dart SDK** — included with Flutter (no separate install needed)

3. **Chrome browser** — required for Flutter web development mode

4. **Python 3** — for serving the production build locally
   - Verify: `python --version`

---

## Getting Started

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd arresto_lms
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run in development mode (with hot reload)

```bash
flutter run -d chrome
```

The app opens in Chrome. Press `r` in the terminal to hot-reload, `R` to hot-restart.

### 4. Build for production (web)

```bash
flutter build web --release --pwa-strategy=none
```

> `--pwa-strategy=none` disables the PWA service worker to prevent stale-cache issues after re-deploying.

Built files are placed in `build/web/`.

### 5. Serve the production build locally

```bash
cd build/web
python -m http.server 5500
```

Open **http://localhost:5500** in your browser.

> **Tip:** Always open in an incognito/private window the first time to avoid browser cache conflicts.

---

## Environment Variables & API Keys

> **No API keys are hardcoded in this repository.** All current data is mocked.

When integrating a real backend (Firebase, Supabase, custom API), create the file:

```
lib/config/env.dart
```

Example contents:

```dart
class Env {
  static const apiBaseUrl     = String.fromEnvironment('API_BASE_URL',     defaultValue: 'https://api.example.com');
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
}
```

Pass values at build time — **never hardcode them in source files:**

```bash
flutter build web --release --pwa-strategy=none \
  --dart-define=API_BASE_URL=https://your-api.com \
  --dart-define=FIREBASE_API_KEY=your-key-here
```

**`lib/config/env.dart` is listed in `.gitignore` — it will never be committed.**

---

## Project Structure

```
lib/
├── core/
│   ├── router/          # GoRouter route definitions
│   ├── theme/           # Colors, typography, spacing design tokens
│   └── widgets/         # Shared UI components (cards, buttons, chips, avatars)
├── data/
│   ├── models/          # Data models (Course, Lesson, User, Notification, etc.)
│   └── providers/       # Riverpod providers + mock state
└── features/
    ├── shared/
    │   ├── shell/        # LearnerShell, AdminShell, AppHeader (bell, profile dropdown)
    │   ├── notifications/
    │   └── arresto_ai/
    ├── learner/
    │   ├── dashboard/
    │   ├── catalog/
    │   ├── my_courses/
    │   ├── lesson_player/   # Video player, MCQ overlay, notes, sidebar
    │   ├── assessments/
    │   ├── assessment/      # Quiz flow (intro → quiz → result → review)
    │   ├── certificates/
    │   ├── resources/
    │   ├── arresto_ai/
    │   └── profile/
    └── admin/
        ├── dashboard/
        ├── courses/
        ├── generator/
        ├── learners/
        ├── analytics/
        ├── support/
        └── settings/
```

---

## App Routes

| Route | Screen |
|---|---|
| `/learner` | Learner Dashboard |
| `/learner/catalog` | Course Catalog |
| `/learner/my-courses` | My Courses |
| `/learner/assessments` | Assessments |
| `/learner/lesson/:courseId/:lessonId` | Lesson Player |
| `/learner/certificates` | Certificates |
| `/learner/resources` | Resources |
| `/learner/ai` | Arresto AI Chat |
| `/learner/profile` | Profile |
| `/admin` | Admin Dashboard |
| `/admin/courses` | All Courses |
| `/admin/generator` | Course Generator |
| `/admin/learners` | Learner Management |
| `/admin/analytics` | Analytics |
| `/admin/support` | Support Tickets |
| `/admin/settings` | Settings |

---

## Switching Between Learner and Admin

Use the **Learner / Admin** toggle in the top header bar to switch portals.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| App shows old version after rebuild | Open in incognito window or hard-refresh (`Ctrl + Shift + R`) |
| `GoException: no routes for location` | Service worker is serving old JS. Rebuild with `--pwa-strategy=none` |
| Port 5500 already in use (Windows) | `Get-Process python* \| Stop-Process -Force` then re-run the server |
| Port 5500 already in use (Mac/Linux) | `lsof -ti:5500 \| xargs kill -9` then re-run the server |
| `flutter pub get` fails | Run `flutter upgrade` first, then retry |
| Build fails on iOS ephemeral dir (Windows) | `Remove-Item -Recurse -Force ios\Flutter\ephemeral` then rebuild |

---

## License

Private — internal use only. All rights reserved © Arresto Safety Systems.
