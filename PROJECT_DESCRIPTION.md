# Hayat - Blood Bank Donors Management System

## 📱 Project Overview

**Hayat** is a Flutter mobile application that connects blood donors with blood banks/hospitals. The app facilitates blood donation requests, donor management, and real-time communication between hospitals and donors.

### Key Features
- **Dual User Types**: Donors and Blood Banks/Hospitals
- **Secure Account Management**: Email verification required before account activation
- **Blood Request System**: Hospitals can create urgent blood requests
- **Real-time Notifications**: Donors receive notifications for urgent requests
- **Chat System**: Direct communication between donors and hospitals
- **Secure Backend**: All data operations go through Cloud Functions for security

---

## 🏗️ Architecture

### Technology Stack

**Frontend:**
- **Flutter** (Dart) - Cross-platform mobile app
- **Firebase Auth** - User authentication
- **Cloud Functions** - Secure API layer
- **Firestore** - NoSQL database (read-only from client)

**Backend:**
- **Firebase Cloud Functions** (Node.js) - Serverless backend
- **Firebase Admin SDK** - Server-side Firebase operations
- **Firestore** - Database storage
- **Firebase Authentication** - User management

### Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Frontend)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Screens    │  │   Services   │  │    Models    │     │
│  │              │  │              │  │              │     │
│  │ - Login      │  │ - Auth       │  │ - User       │     │
│  │ - Register   │  │ - Cloud      │  │ - Request    │     │
│  │ - Dashboard  │  │   Functions  │  │              │     │
│  │ - Requests   │  │ - Requests   │  │              │     │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘     │
└─────────┼─────────────────┼────────────────────────────────┘
          │                 │
          │ HTTP Callable   │
          │ Functions       │
          ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│           FIREBASE CLOUD FUNCTIONS (Backend)                │
│  ┌────────────────────────────────────────────────────┐   │
│  │  - createPendingProfile                             │   │
│  │  - completeProfileAfterVerification                 │   │
│  │  - getUserData / getUserRole                       │   │
│  │  - addRequest / getRequests                        │   │
│  │  - onEmailVerified (Trigger)                      │   │
│  └──────────────────┬─────────────────────────────────┘   │
└─────────────────────┼───────────────────────────────────────┘
                      │
                      │ Admin SDK
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    FIREBASE SERVICES                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Firebase   │  │  Firestore   │  │   Firebase   │     │
│  │     Auth     │  │   Database   │  │  Cloud Mess. │     │
│  │              │  │              │  │              │     │
│  │ - Users      │  │ - users      │  │ - Notif.    │     │
│  │ - Email      │  │ - pending_    │  │              │     │
│  │   Verify     │  │   profiles   │  │              │     │
│  │              │  │ - requests   │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Architecture

### Security Model

**Principle**: **No direct client-side writes to Firestore**

All write operations must go through Cloud Functions, which use the Firebase Admin SDK to bypass client-side security rules.

### Firestore Security Rules

```javascript
// Users can only READ their own data
match /users/{userId} {
  allow read: if isAuthenticated() && request.auth.uid == userId;
  allow write: if false; // Only Admin SDK (Cloud Functions)
}

// Same for pending_profiles, requests, notifications
// All writes blocked from client
```

### Data Flow Security

1. **Client** → Validates input
2. **Client** → Calls Cloud Function (authenticated)
3. **Cloud Function** → Validates authentication & data
4. **Cloud Function** → Uses Admin SDK to write to Firestore
5. **Cloud Function** → Returns result to client

---

## 👥 User Types & Roles

### 1. **Donor**
- **Profile**: Name, Blood Type, Location, Medical File
- **Capabilities**:
  - View blood requests
  - Receive notifications for urgent requests
  - Chat with hospitals
  - View personal dashboard

### 2. **Blood Bank/Hospital**
- **Profile**: Hospital Name, Location
- **Capabilities**:
  - Create blood requests
  - Mark requests as urgent
  - Chat with donors
  - View request dashboard
  - Manage notifications

---

## 📂 Project Structure

```
BloodBank_Donors/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/
│   │   ├── user_model.dart          # User data model
│   │   └── blood_request_model.dart # Request data model
│   ├── screens/
│   │   ├── login_screen.dart        # Login UI
│   │   ├── register_screen.dart    # Registration UI
│   │   ├── donor_dashboard_screen.dart
│   │   ├── blood_bank_dashboard_screen.dart
│   │   ├── new_request_screen.dart  # Create blood request
│   │   ├── notifications_screen.dart
│   │   └── chat_screen.dart
│   ├── services/
│   │   ├── auth_service.dart        # Authentication logic
│   │   ├── cloud_functions_service.dart # Cloud Functions client
│   │   ├── requests_service.dart    # Request management
│   │   └── notification_service.dart
│   └── stores/
│       └── requests_store.dart      # State management
│
├── functions/
│   ├── index.js                     # All Cloud Functions
│   └── package.json
│
├── firestore.rules                  # Security rules
└── firebase.json                    # Firebase config
```

---

## 🔄 Key Workflows

### 1. Account Registration Flow

```
User Fills Form
    ↓
Create Firebase Auth Account
    ↓
Reload User & Get ID Token
    ↓
Call createPendingProfile (Cloud Function)
    ↓
Save to pending_profiles/{uid} (NO email stored)
    ↓
Send Verification Email
    ↓
User Verifies Email
    ↓
onEmailVerified Trigger Fires
    ↓
Move pending_profiles → users/{uid}
    ↓
Add email from verified Auth user
    ↓
Account Activated ✅
```

**Key Points:**
- Email is **never** stored in Firestore until verified
- Data stored in `pending_profiles` temporarily
- Automatic profile completion via trigger
- Auth account deleted if any step fails

### 2. Blood Request Flow

```
Hospital Creates Request
    ↓
Call addRequest (Cloud Function)
    ↓
Validate: User is hospital
    ↓
Save to requests/{requestId}
    ↓
If Urgent:
    ↓
Get All Donors
    ↓
Create Notifications for Each Donor
    ↓
Return Success
```

### 3. Login Flow

```
User Enters Credentials
    ↓
Firebase Auth Login
    ↓
Check Email Verified
    ↓
If Verified but No Profile:
    Call completeProfileAfterVerification
    ↓
Get User Data (Cloud Function)
    ↓
Route by Role:
    - Donor → DonorDashboard
    - Hospital → BloodBankDashboard
```

---

## 🗄️ Database Structure

### Firestore Collections

#### `users/{uid}`
**Final user profiles** (only after email verification)
```javascript
{
  email: "user@example.com",        // From verified Auth user
  role: "donor" | "hospital",
  fullName: "John Doe",              // For donors
  bloodBankName: "City Hospital",    // For hospitals
  bloodType: "A+",                   // For donors
  location: "City, Country",
  medicalFileUrl: "...",            // Optional for donors
  emailVerified: true,
  emailVerifiedAt: Timestamp,
  activatedAt: Timestamp,
  createdAt: Timestamp
}
```

#### `pending_profiles/{uid}`
**Temporary profiles** (before email verification)
```javascript
{
  role: "donor" | "hospital",
  fullName: "John Doe",             // For donors
  bloodBankName: "City Hospital",   // For hospitals
  bloodType: "A+",                   // For donors
  location: "City, Country",
  medicalFileUrl: "...",            // Optional
  createdAt: Timestamp
  // NO email field - retrieved from Auth after verification
}
```

#### `requests/{requestId}`
**Blood donation requests**
```javascript
{
  bloodBankId: "uid",
  bloodBankName: "City Hospital",
  bloodType: "A+",
  units: 5,
  isUrgent: true,
  details: "Emergency surgery needed",
  hospitalLocation: "City, Country",
  createdAt: Timestamp
}
```

#### `notifications/{userId}/user_notifications/{notificationId}`
**User notifications**
```javascript
{
  title: "Urgent blood request: A+",
  body: "5 units needed at City Hospital",
  requestId: "request123",
  read: false,
  createdAt: Timestamp
}
```

---

## 🔧 Cloud Functions

### HTTP Callable Functions

#### `createPendingProfile`
- **Purpose**: Save user profile data before email verification
- **Auth**: Required (user must be signed in)
- **Writes**: `pending_profiles/{uid}`
- **Returns**: `{ ok, emailVerified, message }`

#### `completeProfileAfterVerification`
- **Purpose**: Move profile from `pending_profiles` to `users` after verification
- **Auth**: Required
- **Checks**: Email must be verified
- **Writes**: `users/{uid}`, deletes `pending_profiles/{uid}`
- **Returns**: `{ ok, message }`

#### `getUserData`
- **Purpose**: Get user profile data
- **Auth**: Required
- **Reads**: `users/{uid}`
- **Returns**: User data with normalized timestamps

#### `getUserRole`
- **Purpose**: Get user role for routing
- **Auth**: Required
- **Reads**: `users/{uid}`
- **Returns**: `{ role: "donor" | "hospital" }`

#### `addRequest`
- **Purpose**: Create a new blood request
- **Auth**: Required
- **Permission**: Only hospitals
- **Writes**: `requests/{requestId}`
- **Side Effect**: Creates notifications if urgent
- **Returns**: `{ ok, message }`

#### `getRequests`
- **Purpose**: Get blood requests with pagination
- **Auth**: Required
- **Reads**: `requests` collection
- **Returns**: `{ requests: [...], hasMore: boolean }`

### Event Triggers

#### `onEmailVerified`
- **Trigger**: Firebase Auth email verification
- **Action**: Automatically moves `pending_profiles/{uid}` → `users/{uid}`
- **Adds**: Email from verified Auth user

#### `cleanupOnUserDelete`
- **Trigger**: Firebase Auth user deletion
- **Action**: Cleans up `users/{uid}` and `pending_profiles/{uid}`

---

## 🎨 UI/UX Features

### Design System
- **Primary Color**: Red (#e60012) - Represents blood/life
- **Background**: Light gray (#f5f6fb)
- **Font**: Roboto
- **Material Design 3**: Modern UI components

### Key Screens

1. **Login Screen**
   - Email/password authentication
   - Link to registration
   - Forgot password option

2. **Registration Screen**
   - Toggle between Donor/Hospital
   - Form validation
   - Email verification prompt

3. **Donor Dashboard**
   - List of blood requests
   - Filter by blood type
   - Notification badge
   - Chat access

4. **Blood Bank Dashboard**
   - Create new request button
   - List of created requests
   - Notification management

5. **New Request Screen**
   - Blood type selector
   - Units input
   - Urgent toggle
   - Location & details

6. **Notifications Screen**
   - List of notifications
   - Mark as read
   - Link to requests

7. **Chat Screen**
   - Real-time messaging
   - Between donors and hospitals

---

## 🔒 Security Features

### 1. **Email Verification Required**
- No data stored in `users` collection until email verified
- Email retrieved from verified Auth user (not stored in `pending_profiles`)

### 2. **No Direct Client Writes**
- All writes go through Cloud Functions
- Firestore rules block all client writes
- Admin SDK bypasses rules for Cloud Functions

### 3. **Authentication Required**
- All Cloud Functions require authentication
- User can only access their own data
- Role-based permissions (hospitals only can create requests)

### 4. **Automatic Cleanup**
- Auth account deleted if registration fails
- Firestore data cleaned up on user deletion
- No orphaned accounts or data

### 5. **Input Validation**
- Client-side validation
- Server-side validation in Cloud Functions
- Type checking and sanitization

---

## 🚀 Deployment

### Prerequisites
- Firebase project created
- Flutter SDK installed
- Node.js installed (for Cloud Functions)

### Steps

1. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

2. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Build Flutter App**
   ```bash
   flutter build apk  # Android
   flutter build ios  # iOS
   ```

---

## 📊 Data Flow Examples

### Example 1: Donor Registration

```
1. User enters: name, email, password, bloodType, location
2. Flutter validates input
3. AuthService.signUpDonor() called
4. Firebase Auth creates account
5. User reloaded, ID token obtained
6. Cloud Function createPendingProfile called
7. Data saved to pending_profiles/{uid}
8. Verification email sent
9. User clicks email link
10. onEmailVerified trigger fires
11. Data moved to users/{uid} with email
12. Account activated ✅
```

### Example 2: Hospital Creates Urgent Request

```
1. Hospital fills request form
2. RequestsService.addRequest() called
3. Cloud Function addRequest called
4. Validates user is hospital
5. Saves to requests/{requestId}
6. If urgent:
   - Gets all donors from users collection
   - Creates notification for each donor
7. Returns success
8. Donors see notification in app
```

---

## 🛠️ Development Notes

### Error Handling
- Comprehensive error messages
- Automatic Auth account cleanup on failure
- Detailed logging for debugging
- User-friendly error dialogs

### State Management
- Services for business logic
- Models for data structure
- Stores for reactive state (requests)

### Testing
- Mock dependencies available
- Test utilities in dev_dependencies
- Cloud Functions can be tested locally

---

## 📝 Key Design Decisions

1. **Cloud Functions as Middleware**: All sensitive operations go through Cloud Functions for security
2. **Email Verification First**: No email stored until verified
3. **Pending Profiles**: Temporary storage during verification process
4. **Automatic Triggers**: Email verification triggers automatic profile completion
5. **Role-Based Access**: Different dashboards and permissions for donors vs hospitals
6. **Urgent Notifications**: Automatic notification system for urgent requests

---

## 🔮 Future Enhancements

Potential improvements:
- Push notifications (FCM)
- Donor eligibility tracking
- Appointment scheduling
- Blood donation history
- Rewards/points system
- Multi-language support
- Advanced search/filtering
- Analytics dashboard

---

## 📞 Support & Maintenance

- **Error Logging**: Cloud Functions log all errors
- **Monitoring**: Firebase Console for function metrics
- **Security**: Regular security rule reviews
- **Updates**: Version control for all functions

---

This architecture ensures **security**, **scalability**, and **maintainability** while providing a smooth user experience for both donors and blood banks.

