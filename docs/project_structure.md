# Blood Bank Donors — folders and files overview

This document summarizes what each major area of the repository is for. Paths are relative to the project root unless noted.

---

## Root (Flutter app + backend)

| Item | Purpose |
|------|---------|
| **`lib/`** | Dart/Flutter application source (UI, controllers, models, services). |
| **`functions/`** | Firebase Cloud Functions (Node.js): secure API to Firestore/Auth, callable from the app. |
| **`test/`** | Unit and widget tests mirroring `lib/` structure. |
| **`integration_test/`** | Integration tests (e.g. backend smoke tests). |
| **`android/`, `ios/`, `web/`** | Platform projects and native configuration (Firebase, icons, permissions). |
| **`assets/`** | Static images and docs bundled in the app (`pubspec.yaml` declares what is included). |
| **`docs/`** | Project documentation (this file, UML, etc.). |
| **`pubspec.yaml`** | Flutter dependencies, app version, asset list. |
| **`firebase_options.dart`** (generated under `lib/` when using FlutterFire) | Firebase project keys per platform. |

---

## `lib/` — Flutter application

### Entry and architecture

| File / folder | Purpose |
|---------------|---------|
| **`main.dart`** | App entry: Firebase init, global `navigatorKey`, FCM background handler, `MaterialApp`, initial route. |
| **`app_layers.dart`** | Short architecture note: MVC-style layers and where push/notification services fit. |
| **`firebase_options.dart`** | Generated Firebase configuration (when present). |

### `lib/models/`

Data shapes and enums used across the app (Firestore/JSON-friendly). Examples: user profile, blood requests, login/register result types, donor medical report, chat/response entries.

### `lib/controllers/`

Business logic without building widgets: validation, orchestration, navigation *choices* (some still return target screens). Examples: `login_controller`, `register_controller`, dashboard controllers, chat, admin, password reset.

### `lib/views/`

Full screens, grouped by feature where possible:

| Subfolder | Typical content |
|-----------|-----------------|
| **`auth/`** | Login, register, password reset flows. |
| **`onboarding/`** | Welcome / first screen (mobile vs web variant). |
| **`dashboard/`** | Donor and blood bank home dashboards. |
| **`admin/`** | Admin dashboard and tabs (requests, donors, stats). |
| **`donor_management/`** | Blood bank tools: donor lists, appointments, reports. |
| **`donor_profile/`** | Donor profile, history, restrictions, account slices. |
| **Root-level screens** | Chat, notifications, maps, requests, contacts, stats, new request, detail screens, etc. |

### `lib/services/`

Integration with Firebase and the outside world:

| Area | Files (conceptually) |
|------|----------------------|
| **Auth & profile** | `auth_service.dart`, `phone_auth_service.dart`, `password_reset_service.dart`. |
| **Backend API** | `cloud_functions_service.dart` — HTTPS callables (profile, requests, FCM token, etc.). |
| **Push & notifications** | `fcm_service.dart`, `fcm_cloud_sync_service.dart`, `fcm_foreground_handler.dart`, `local_notif_service.dart`, `notification_navigation_service.dart` (see also `lib/notifications/` for web UI). |
| **App data** | `requests_service.dart`, `notification_service.dart` (in-app notification list behavior, if distinct from FCM). |

### `lib/notifications/`

Web-only **browser** notification UI for foreground FCM (conditional `dart:html` import). Not a network “service”: stub on mobile/desktop, real implementation on Web. Imported by `fcm_foreground_handler.dart`.

| File | Role |
|------|------|
| `web_foreground_notification.dart` | Public API + conditional export |
| `web_foreground_notification_stub.dart` | No-op on non-web |
| `web_foreground_notification_web.dart` | `Notification` API + click → URL with `notificationData` |

### `lib/shared/` — theme, widgets, utils, constants

Everything reusable across features that is **not** a full screen or a service lives here:

| Subfolder | Purpose |
|-----------|---------|
| **`shared/theme/`** | `AppTheme`, colors, typography, shared input decoration. |
| **`shared/widgets/`** | Reusable components (`auth/`, `chat/`, `common/`, `dashboard/`, `notifications/`). |
| **`shared/utils/`** | Jordan phone helpers, dialogs, blood compatibility, file picking (IO/web), eligibility copy, password-reset link parsing. |
| **`shared/constants/`** | Static strings (e.g. donor cooldown messages). |

Imports use `../shared/...` from `lib/views`, `lib/controllers`, and `lib/services` as appropriate. Widgets under `shared/widgets/` that reference `lib/models` or `lib/views` use one extra `../` (for example `../../../models/`).


## `functions/` — Cloud Functions

| File / folder | Purpose |
|---------------|---------|
| **`index.js`** | Exports all callable/scheduled functions for deployment. |
| **`callable_config.js`** | Shared options for HTTPS callables (region, invoker, etc.). |
| **`src/auth.js`** | User profile lifecycle: pending profiles, completion after verification, roles, FCM token field, phone→email resolution for login, etc. |
| **`src/requests.js`** | Blood requests lifecycle, donor responses, related reads. |
| **`src/notifications.js`** | In-app notifications/messages where applicable. |
| **`src/utils.js`** | Shared validation (e.g. Jordan phone), error mapping. |
| **`donor_management_functions.js`** | Medical reports, appointments, donation history APIs for banks/donors. |
| **`donation_schedule.js`** | Shared donation-schedule helpers used by functions. |
| **`scripts/`** | Maintenance scripts (e.g. data cleanup); use with care in production. |

---

## `test/`

Mirrors important parts of `lib/`:

- **`controllers_test/`** — Controller behavior with mocks.
- **`models_test/`** — Parsing and model invariants.
- **`services_test/`** — Auth, password reset, requests, notifications, web stubs.
- **`utils_test/`** — e.g. Jordan phone rules.
- **`widget_test.dart`** — Default Flutter widget smoke test.

---

## `docs/`

Design and reference material (e.g. UML diagrams). **`project_structure.md`** (this file) describes layout; it is not a substitute for reading `app_layers.dart` for layering rules.

---

## How the pieces connect (short)

1. **Screens (`views`)** call **controllers** and **services**.
2. **Services** talk to **Firebase Auth** and **Cloud Functions** (`cloud_functions_service.dart`); functions talk to **Firestore** and **Admin SDK** server-side.
3. **FCM** delivers pushes; the app shows **local** or **web** notifications and uses **notification_navigation_service** for taps.
4. **Models** carry data between layers and from JSON/maps returned by callables.
