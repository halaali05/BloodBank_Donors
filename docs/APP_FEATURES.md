# HAYAH — How the app features work

This document describes what the **HAYAH** Flutter app does for **donors** and **blood banks (hospitals)**, and how the main flows fit together. It is based on the current `lib/` implementation (Firebase Auth, Cloud Messaging, and **HTTPS Callable Cloud Functions** as the primary data API — not direct Firestore reads/writes from the client).

---

## 1. Who the app is for

| Role | After login |
|------|-------------|
| **Donor** | `DonorDashboardScreen` — browse requests, respond, map, chat, profile, notifications |
| **Hospital / blood bank** | `BloodBankDashboardScreen` — create and manage requests, donor pipeline, stats, contacts |

Registration and login distinguish roles via the user profile returned from the backend (`UserRole.donor` vs `UserRole.hospital`).

---

## 2. Startup and navigation

1. **`WelcomeScreen`** — branding and **Get Started** → `LoginScreen`.
2. **`main.dart`** — initializes **Firebase**, registers the **FCM background handler** on mobile, initializes **local notifications** and **FCM** (mobile immediately; web FCM is initialized after `runApp` with error handling).
3. A **global `navigatorKey`** allows services (for example FCM tap handling) to navigate when there is no widget `BuildContext`.

---

## 3. Account creation and login

### Registration (`RegisterScreen`)

- **Donors** provide profile fields such as name, email, password, location, gender, phone, and optional map coordinates.
- **Blood banks** provide institution name, location, and optional coordinates.

**Flow (high level):**

1. Firebase **Auth** account is created (`AuthService`).
2. A Cloud Function **`createPendingProfile`** stores a **pending** profile for the new UID.
3. **Email verification** is sent from the client after the pending profile step succeeds.

Until email is verified and the profile is promoted to the live `users` collection, login may fail with “verify email” or “profile not ready” messages (`LoginController`).

### Login (`LoginScreen` + `LoginController`)

1. Sign in with Firebase Auth.
2. **Email must be verified** — otherwise the user is signed out and warned.
3. **`completeProfileAfterVerification`**** may be called (with a short timeout) to move data from pending to active profile — this can still be finishing on first login.
4. **`getUserData`** loads role and dashboard fields; if null after retries, the user sees **profile not ready** and should try again shortly.
5. On success, **FCM token is synced** to the server (`ensureTokenSynced`) so push targets the correct device, then navigation clears the stack to the appropriate dashboard.

### Password reset

Forgot-password and reset flows use dedicated screens and services (`forgot_password_screen`, `reset_password_screen`, `password_reset_service`) so users can recover access without staff intervention.

---

## 4. Donor dashboard

**Purpose:** Show open blood requests and let the donor indicate availability and communicate.

### Data loading

- Requests and profile are loaded via **`DonorDashboardController`** → Cloud Functions (for example **`getRequests`**, **`getUserData`**).
- The UI **polls about every 30 seconds** for requests, profile, and unread notification count (there is no Firestore snapshot stream in the client architecture).

### Tabs

- **List** — cards per request (`DonorRequestCard`) with blood type, urgency, hospital location, counts, and the donor’s own response state.
- **Map** — **`DonorMapScreen`**: requests as pins on a Jordan-centered map; can filter by the donor’s governorate or show all regions; tapping leads to details / respond behavior consistent with the list.

### “I can donate” (accept) vs decline

- The donor sends a **response** for a request id (**`submitDonorResponse`**) with a status such as **`accepted`** or **`rejected`** (implementation naming in UI: “I can donate” vs removed from that list).
- **Completed** requests do not accept new responses.
- **Post-donation cooldown** (see §5) can **block new `accepted`** responses on *other* requests until eligibility time passes, unless the donor **already** accepted that same request (so an existing commitment is not stranded). The map uses the same rule via `nextDonationEligibleAt`.

### Header actions

- **Notifications** → `NotificationsScreen`.
- **Profile** → `DonorProfileScreen` (return value can trigger profile refresh on the dashboard).
- **Logout** → clears session and returns to `LoginScreen`.

---

## 5. Donor eligibility and cooldown (`DonorEligibility`)

Eligibility is computed to stay aligned with server rules (see comments in `donor_eligibility.dart` referencing backend `requests.js`).

- **Interval by gender:** **90 days** (men) vs **120 days** (women), based on profile `gender`.
- **Cooldown end instant** is the **later** of:
  - `nextDonationEligibleAt` from the profile (explicit server/admin path), and  
  - `lastDonatedAt` + the gender-based day count.

**`DonorEligibilityScreen`** (from profile menu) explains:

- Whether the waiting period is **active** or the donor **can donate now**.
- **Eligible again on** — formatted end date/time.
- Rule length and gender label.
- While active: **days left** (calendar-based) and a **progress** bar over the wait window.

Blocking messages in the dashboard/map use **`DonorCooldownBlockedMessage`** and may deep-link style guidance when the server returns eligibility errors.

---

## 6. Donor profile (`DonorProfileScreen`)

**Purpose:** View/edit identity and health-related artifacts the app tracks.

- **Reads/writes** go through Cloud Functions (`getUserData`, `updateUserProfile`, history/report endpoints via `DonorProfileController`).
- **Polling about every 30 seconds** refreshes profile and donation history (same pattern as dashboard — no client Firestore subscriptions).
- **Editable** display name; **photo** upload to Firebase Storage with rules implied by server/auth design.
- **Sub-pages / areas** include:
  - **Eligibility** — screen above.
  - **Donation history** — past donations / reports list.
  - **Medical reports** — upload/manage reports (`DonorMedicalReport`).
  - **Donation restrictions** — informational content (assets/docs).
  - **Account** — account-related settings/info.

---

## 7. Blood bank dashboard

**Purpose:** Operate outgoing blood requests and downstream donor handling.

- Lists the blood bank’s requests (via **`BloodBankDashboardController`** / Cloud Functions), with **periodic refresh (~30 s)**.
- Actions typically include **creating** a request (`NewRequestScreen`), **opening donor management** for a request, **statistics**, **past donors**, and **logout**.
- **Delete request** confirms with the user, then calls backend deletion through the controller/service layer.

---

## 8. Creating a request (`NewRequestScreen`)

Blood banks specify request fields such as **blood type**, **units**, **urgent** flag, **details**, and **hospital location** (with map/coordinates where implemented). The client builds a **`BloodRequest`** model and submits it through **`RequestsService.addRequest`** → Cloud Function **`addRequest`**, which persists and makes the request visible to donors.

---

## 9. Donor management (blood bank) (`DonorManagementScreen`)

**Purpose:** Move donors through an operational **pipeline** for a single request.

- Loads **`getRequestDonorResponses`** for server-side **accepted** donor rows; falls back to embedded `acceptedDonors` on the request model if the call fails.
- **Tabbed UI** groups donors by process phase (for example accepted → scheduled → tested), with support for:
  - **Appointments** (`donor_management_appointment`)
  - **Medical report** capture/review (`donor_management_report_sheet`)
  - **Restricted** outcomes where a donor cannot proceed
- This is where the bank **operationalizes** responders who tapped “I can donate” on the donor side.

---

## 10. Request details (`RequestDetailsScreen`)

Opened with a **`requestId`** (for example from a notification). Loads a batch of requests via **`getRequests`**, finds the matching id, and shows full detail. From here the user can move into **chat** or other actions offered by the UI.

---

## 11. Chat (`ChatScreen` + `ChatController`)

- **Per-request** conversation: `ChatScreen(requestId: …)` ties messages to a specific blood request.
- Load/send logic is mediated by **`ChatController`** and Cloud Functions / backend contracts (participants, message list, send).

---

## 12. Contacts (`ContactsScreen`)

Used from the **blood bank** side to work with **donors who have participated in chat** for a given request: loads donors (optionally by **blood type**) and **filters to chat participants** for that `requestId`, so the list reflects people already engaged on that thread.

---

## 13. Notifications

### In-app (`NotificationsScreen`)

- Unread count on the donor app bar is refreshed on a timer and via **`getNotifications`** (through dashboard controller helpers).
- Opening items can route to **request details** or related screens depending on payload/type.

### Push (FCM + local notifications)

- **`FCMService`** requests permission, listens for **foreground** messages, **notification opens**, and **token refresh**, and syncs tokens with **`updateFcmToken`**.
- **Background** on Android/iOS uses **`firebaseMessagingBackgroundHandler`** in `main.dart`: initializes Firebase in the isolate, ensures local notification channel init, and shows a **local notification** with encoded **payload** (type, requestId, sender/recipient ids) for taps.
- **Urgent** styling can apply when payload indicates an urgent **request**.
- **Tap routing** maps payload types to **donor dashboard**, **blood bank dashboard**, **chat**, or **notifications**, depending on role and message shape.
- **Web** has special handling (delayed FCM init, optional `notificationData` query parameter for cold starts).

---

## 14. Statistics (`StatsScreen`)

Blood banks open an **Overview** that aggregates the **loaded request list**: filters by **year/month**, shows counts for **active**, **urgent**, **completed**, total **units**, and **accepted** donors summed over the filtered set. It is a **client-side summary** of the data already fetched for the dashboard (not a separate analytics backend in code reviewed here).

---

## 15. Past donors (`BloodBankPastDonorsScreen`)

Screen dedicated to reviewing **historical donor** records for the institution (loaded via services/controllers); useful for repeat donor outreach and auditing.

---

## 16. Security and architecture notes (for readers maintaining the app)

1. **No direct Firestore access** for sensitive aggregates in the reviewed paths — **Cloud Functions** enforce auth and validate inputs.
2. **Email verification** is mandatory before donor/hospital dashboards.
3. **FCM token** is stored server-side so campaigns and request alerts reach the device that last logged in.
4. **Cooldown** is enforced both in **UI** (early block) and must remain consistent with **server** validation on `submitDonorResponse` and related functions.

---

## 17. File map (quick reference)

| Area | Main entry points |
|------|-------------------|
| App shell | `lib/main.dart`, `lib/views/welcome_screen.dart` |
| Auth | `lib/views/login_screen.dart`, `lib/views/register_screen.dart`, `lib/services/auth_service.dart` |
| Donor home | `lib/views/donor_dashboard_screen.dart`, `lib/views/donor_map_screen.dart` |
| Blood bank home | `lib/views/blood_bank_dashboard_screen.dart`, `lib/views/new_request_screen.dart` |
| Eligibility | `lib/utils/donor_eligibility.dart`, `lib/views/donor_profile/donor_eligibility_screen.dart` |
| Profile | `lib/views/donor_profile/donor_profile_screen.dart` |
| Donor pipeline | `lib/views/donor_management/donor_management_screen.dart` |
| Push | `lib/services/fcm_service.dart`, `lib/services/local_notif_service.dart` |
| API surface | `lib/services/cloud_functions_service.dart` |

---

*If you extend the backend (new callable functions or Firestore shapes), update this document and the inline comments in `DonorEligibility` / controllers so donor-facing copy and server rules stay aligned.*
