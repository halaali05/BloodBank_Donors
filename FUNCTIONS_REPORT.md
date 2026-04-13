# Functions Report - Blood Bank Donors Application

This document provides a comprehensive explanation of all Cloud Functions in the application, their purposes, and the sequence of using them in different workflows.

---

## Table of Contents

1. [Overview](#overview)
2. [Function Categories](#function-categories)
3. [Authentication Functions](#authentication-functions)
4. [Request Management Functions](#request-management-functions)
5. [Notification & Messaging Functions](#notification--messaging-functions)
6. [Scheduled Functions](#scheduled-functions)
7. [Function Usage Sequences](#function-usage-sequences)
8. [Security Architecture](#security-architecture)

---

## Overview

The application uses **Firebase Cloud Functions** as the backend API layer. All database operations (reads and writes) go through Cloud Functions for security and centralized business logic.

### Architecture Pattern
- **Client (Flutter)** → **Cloud Functions (Node.js)** → **Firestore Database**
- No direct Firestore access from client-side
- All functions require authentication
- Server-side validation and authorization

### Function Types
1. **Callable Functions** (`onCall`) - Called directly from client
2. **Trigger Functions** (`onDocumentCreated`) - Automatically triggered by Firestore events
3. **Scheduled Functions** (`onSchedule`) - Run on a schedule (cron jobs)

---

## Function Categories

### 1. Authentication Functions (`auth.js`)
Functions for user registration, login, profile management, and authentication.

### 2. Request Management Functions (`requests.js`)
Functions for creating, reading, and managing blood requests.

### 3. Notification & Messaging Functions (`notifications.js`)
Functions for notifications and chat messaging between users.

### 4. Scheduled Functions
Automated cleanup and maintenance tasks.

---

## Authentication Functions

### 1. `createPendingProfile`

**Purpose**: Creates a temporary profile in `pending_profiles` collection during registration (before email verification).

**Type**: Callable Function (`onCall`)

**When Called**: During user registration (sign up)

**Parameters**:
- `role` (required): "donor" or "hospital"
- `fullName` (required for donor): User's full name
- `bloodBankName` (required for hospital): Blood bank name
- `location` (required): User's location/governorate

**Returns**:
```javascript
{
  ok: true,
  emailVerified: boolean,
  message: string
}
```

**What It Does**:
1. Validates authentication token
2. Checks user's email verification status
3. Creates document in `pending_profiles/{uid}` collection
4. Returns email verification status

**Security**: Requires authentication, validates role

---

### 2. `completeProfileAfterVerification`

**Purpose**: Moves profile from `pending_profiles` to `users` collection after email verification.

**Type**: Callable Function (`onCall`)

**When Called**: On first login after email verification

**Parameters**: None (uses authenticated user's UID)

**Returns**:
```javascript
{
  ok: true,
  message: "Profile activated."
}
```

**What It Does**:
1. Verifies email is verified
2. Reads data from `pending_profiles/{uid}`
3. Creates document in `users/{uid}` with additional fields:
   - `email`: User's email
   - `emailVerified`: true
   - `emailVerifiedAt`: Timestamp
   - `activatedAt`: Timestamp
4. Deletes `pending_profiles/{uid}` document
5. Sets custom claims in Firebase Auth

**Security**: Requires authentication, requires email verification

---

### 3. `getUserData`

**Purpose**: Retrieves user profile data from `users` collection.

**Type**: Callable Function (`onCall`)

**When Called**: 
- During login (to get user role and data)
- When viewing profile
- When updating profile

**Parameters**:
- `uid` (optional): Target user UID (defaults to authenticated user)

**Returns**:
```javascript
{
  uid: string,
  role: string,
  fullName: string,
  location: string,
  email: string,
  emailVerified: boolean,
  createdAt: number,
  activatedAt: number,
  emailVerifiedAt: number,
  // ... other user fields
}
```

**What It Does**:
1. Validates authentication
2. Reads user document from `users/{uid}`
3. Normalizes timestamps to milliseconds
4. Returns user data

**Security**: Requires authentication, users can only access their own data

---

### 4. `getUserRole`

**Purpose**: Gets the user's role (donor or hospital).

**Type**: Callable Function (`onCall`)

**When Called**: During login to determine which dashboard to show

**Parameters**: None (uses authenticated user's UID)

**Returns**:
```javascript
{
  role: "donor" | "hospital"
}
```

**What It Does**:
1. Validates authentication
2. Reads user document from `users/{uid}`
3. Returns role field

**Security**: Requires authentication

---

### 5. `updateLastLoginAt`

**Purpose**: Updates the `lastLoginAt` timestamp for the authenticated user.

**Type**: Callable Function (`onCall`)

**When Called**: During login (asynchronously, non-blocking)

**Parameters**: None

**Returns**:
```javascript
{
  ok: true,
  message: "Last login time updated."
}
```

**What It Does**:
1. Validates authentication
2. Updates `lastLoginAt` field in `users/{uid}`
3. Only updates if user document exists (prevents creating documents before verification)

**Security**: Requires authentication

**Note**: Used to filter notifications to only logged-in users

---

### 6. `updateFcmToken`

**Purpose**: Updates the Firebase Cloud Messaging (FCM) token for push notifications.

**Type**: Callable Function (`onCall`)

**When Called**: 
- On app startup (when FCM token is obtained)
- When FCM token is refreshed

**Parameters**:
- `fcmToken` (required): FCM token string

**Returns**:
```javascript
{
  ok: true,
  message: "FCM token updated."
}
```

**What It Does**:
1. Validates authentication
2. Updates `fcmToken` and `lastLoginAt` in `users/{uid}`
3. Only updates if user document exists

**Security**: Requires authentication

---

### 7. `updateUserProfile`

**Purpose**: Updates user profile information (name).

**Type**: Callable Function (`onCall`)

**When Called**: When user edits their profile

**Parameters**:
- `name` (required): New name to set

**Returns**:
```javascript
{
  ok: true,
  message: "Profile updated successfully."
}
```

**What It Does**:
1. Validates authentication
2. Updates `name` and `fullName` in `users/{uid}`
3. Updates Firebase Auth display name
4. Sets `updatedAt` timestamp

**Security**: Requires authentication, users can only update their own profile

---

### 8. `cleanupUnverifiedUsers`

**Purpose**: Scheduled cleanup of unverified user accounts older than 2 days.

**Type**: Scheduled Function (`onSchedule`)

**When Called**: Daily at 3:00 AM (Asia/Amman timezone)

**Parameters**: None

**What It Does**:
1. Scans all Firebase Auth users
2. Finds users with `emailVerified: false` older than 2 days
3. Deletes:
   - `pending_profiles/{uid}` document
   - `users/{uid}` document (if exists)
   - Firebase Auth user account

**Security**: Server-side only, no client access

---

## Request Management Functions

### 1. `addRequest`

**Purpose**: Creates a new blood request (hospitals only).

**Type**: Callable Function (`onCall`)

**When Called**: When a blood bank creates a new blood request

**Parameters**:
- `requestId` (required): Unique request ID
- `bloodBankName` (required): Name of the blood bank
- `bloodType` (required): Required blood type (e.g., "A+", "O-")
- `units` (required): Number of units needed
- `isUrgent` (required): Whether request is urgent
- `hospitalLocation` (required): Hospital location
- `details` (optional): Additional details

**Returns**:
```javascript
{
  ok: true,
  message: "Request created and personalized messages sent to all matching donors."
}
```

**What It Does**:
1. Validates authentication
2. Verifies user is a hospital
3. Creates document in `requests/{requestId}` collection
4. Triggers `sendRequestMessageToDonors` automatically (Firestore trigger)

**Security**: Requires authentication, hospitals only

---

### 2. `getRequests`

**Purpose**: Gets paginated list of all blood requests (for donors).

**Type**: Callable Function (`onCall`)

**When Called**: When donors view the requests list

**Parameters**:
- `limit` (optional): Number of requests to return (default: 50, max: 100)
- `lastRequestId` (optional): Last request ID for pagination

**Returns**:
```javascript
{
  requests: Array<BloodRequest>,
  hasMore: boolean
}
```

**What It Does**:
1. Validates authentication
2. Queries `requests` collection ordered by `createdAt` (descending)
3. Returns paginated results
4. Normalizes timestamps to milliseconds

**Security**: Requires authentication

---

### 3. `getRequestsByBloodBankId`

**Purpose**: Gets all requests for a specific blood bank (hospitals only).

**Type**: Callable Function (`onCall`)

**When Called**: When a blood bank views their own requests

**Parameters**: None (uses authenticated user's UID)

**Returns**:
```javascript
{
  requests: Array<BloodRequest>,
  count: number
}
```

**What It Does**:
1. Validates authentication
2. Verifies user is a hospital
3. Queries `requests` collection where `bloodBankId == uid`
4. Returns all requests for that blood bank

**Security**: Requires authentication, hospitals only, can only see own requests

---

### 4. `getDonors`

**Purpose**: Gets list of all donors (hospitals only), optionally filtered by blood type.

**Type**: Callable Function (`onCall`)

**When Called**: When a blood bank wants to view donor list

**Parameters**:
- `bloodType` (optional): Filter by blood type

**Returns**:
```javascript
{
  ok: true,
  donors: Array<Donor>,
  count: number
}
```

**What It Does**:
1. Validates authentication
2. Verifies user is a hospital
3. Queries `users` collection where `role == "donor"`
4. Optionally filters by `bloodType`
5. Returns donor list with: id, fullName, location, bloodType, email

**Security**: Requires authentication, hospitals only

---

### 5. `deleteRequest`

**Purpose**: Deletes a blood request and all associated data (hospitals only, must own the request).

**Type**: Callable Function (`onCall`)

**When Called**: When a blood bank deletes one of their requests

**Parameters**:
- `requestId` (required): ID of request to delete

**Returns**:
```javascript
{
  ok: true,
  message: string,
  notificationsDeleted: number
}
```

**What It Does**:
1. Validates authentication
2. Verifies user is a hospital
3. Verifies user owns the request
4. Deletes all notifications related to the request
5. Deletes all messages in `requests/{requestId}/messages`
6. Deletes the request document

**Security**: Requires authentication, hospitals only, can only delete own requests

---

### 6. `sendRequestMessageToDonors`

**Purpose**: Automatically creates notifications and personalized messages when a new request is created.

**Type**: Trigger Function (`onDocumentCreated`)

**When Called**: Automatically triggered when a document is created in `requests/{requestId}`

**Parameters**: None (triggered by Firestore event)

**What It Does**:
1. Gets request data from trigger event
2. Queries all active donors (users with `fcmToken`)
3. Creates notification documents in `notifications/{donorId}/user_notifications`
4. Creates personalized messages in `requests/{requestId}/messages`
5. Sends FCM push notifications to all active donors

**Security**: Server-side only, no client access

**Note**: This is a background trigger, not called directly from client

---

## Notification & Messaging Functions

### 1. `getNotifications`

**Purpose**: Gets all notifications for the authenticated user.

**Type**: Callable Function (`onCall`)

**When Called**: When user opens notifications screen

**Parameters**: None

**Returns**:
```javascript
{
  notifications: Array<Notification>,
  count: number
}
```

**What It Does**:
1. Validates authentication
2. Queries `notifications/{uid}/user_notifications` collection
3. Orders by `createdAt` (descending)
4. Normalizes timestamps to milliseconds
5. Returns all notifications

**Security**: Requires authentication, users can only see their own notifications

---

### 2. `markNotificationAsRead`

**Purpose**: Marks a single notification as read.

**Type**: Callable Function (`onCall`)

**When Called**: When user taps on a notification

**Parameters**:
- `notificationId` (required): ID of notification to mark as read

**Returns**:
```javascript
{
  ok: true,
  message: "Notification marked as read."
}
```

**What It Does**:
1. Validates authentication
2. Updates notification document: `read: true`, `isRead: true`
3. Returns success

**Security**: Requires authentication, users can only mark their own notifications

---

### 3. `markNotificationsAsRead`

**Purpose**: Marks all unread notifications as read for the authenticated user.

**Type**: Callable Function (`onCall`)

**When Called**: When user taps "Mark all as read" button

**Parameters**: None

**Returns**:
```javascript
{
  ok: true,
  message: string,
  count: number
}
```

**What It Does**:
1. Validates authentication
2. Queries all notifications where `read == false`
3. Updates all in a batch
4. Returns count of marked notifications

**Security**: Requires authentication, users can only mark their own notifications

---

### 4. `deleteNotification`

**Purpose**: Deletes a specific notification.

**Type**: Callable Function (`onCall`)

**When Called**: When user deletes a notification

**Parameters**:
- `notificationId` (required): ID of notification to delete

**Returns**:
```javascript
{
  ok: true,
  message: "Notification deleted."
}
```

**What It Does**:
1. Validates authentication
2. Deletes notification document from `notifications/{uid}/user_notifications/{notificationId}`
3. Returns success

**Security**: Requires authentication, users can only delete their own notifications

---

### 5. `getMessages`

**Purpose**: Gets all messages for a specific request (with filtering based on user role).

**Type**: Callable Function (`onCall`)

**When Called**: When user opens chat for a request

**Parameters**:
- `requestId` (required): ID of the request
- `filterRecipientId` (optional): Filter messages for specific donor (blood banks only)

**Returns**:
```javascript
{
  messages: Array<Message>,
  count: number
}
```

**What It Does**:
1. Validates authentication
2. Verifies request exists
3. Gets user role
4. Queries messages from `requests/{requestId}/messages`
5. Filters messages based on:
   - **Donors**: See general messages OR messages with `recipientId == their uid`
   - **Blood Banks**: See all messages, or filtered by `filterRecipientId` for specific donor chat
6. Normalizes timestamps
7. Returns filtered messages

**Security**: Requires authentication, proper filtering ensures privacy

---

### 6. `sendMessage`

**Purpose**: Sends a message in a request chat.

**Type**: Callable Function (`onCall`)

**When Called**: When user sends a message in chat

**Parameters**:
- `requestId` (required): ID of the request
- `text` (required): Message text
- `recipientId` (optional): For direct messages to specific donor (blood banks only)

**Returns**:
```javascript
{
  ok: true,
  message: "Message sent successfully."
}
```

**What It Does**:
1. Validates authentication
2. Gets user role
3. Verifies request exists
4. Creates message document in `requests/{requestId}/messages`
5. Includes `recipientId` if provided (for personalized messages)
6. Returns success

**Security**: Requires authentication, proper recipientId ensures message privacy

---

### 7. `cleanupOrphanNotifications`

**Purpose**: Scheduled cleanup of notifications without valid `requestId`.

**Type**: Scheduled Function (`onSchedule`)

**When Called**: Daily at 5:35 AM (Asia/Amman timezone)

**Parameters**: None

**What It Does**:
1. Scans all users' notifications
2. Finds notifications where `requestId == null`
3. Deletes orphan notifications

**Security**: Server-side only

---

### 8. `cleanupOrphanMessages`

**Purpose**: Scheduled cleanup of messages for deleted requests.

**Type**: Scheduled Function (`onSchedule`)

**When Called**: Daily at 4:00 AM (Asia/Amman timezone)

**Parameters**: None

**What It Does**:
1. Scans all requests
2. Finds messages for non-existent requests
3. Deletes orphan messages

**Security**: Server-side only

---

## Function Usage Sequences

### Sequence 1: User Registration Flow

```
1. User fills registration form
2. Client calls: createPendingProfile()
   → Creates pending_profiles/{uid}
   → Returns emailVerified: false
3. Client calls: sendEmailVerification() (Firebase Auth)
4. User verifies email
5. User logs in
6. Client calls: completeProfileAfterVerification()
   → Moves pending_profiles/{uid} → users/{uid}
   → Deletes pending_profiles/{uid}
7. Client calls: getUserData()
   → Gets user profile
8. Client calls: getUserRole()
   → Gets user role for navigation
9. Client calls: updateLastLoginAt() (async)
   → Updates lastLoginAt timestamp
10. Client calls: updateFcmToken() (if FCM initialized)
    → Saves FCM token for push notifications
```

---

### Sequence 2: User Login Flow

```
1. User enters credentials
2. Client calls: signInWithEmailAndPassword() (Firebase Auth)
3. Client calls: isEmailVerified() (Firebase Auth)
   → If false: Show error, logout
4. Client calls: completeProfileAfterVerification() (non-blocking)
   → Moves pending profile to users if needed
5. Client calls: getUserData()
   → Gets user profile data
6. Client calls: getUserRole()
   → Determines dashboard (donor/hospital)
7. Client calls: updateLastLoginAt() (async)
   → Updates last login time
8. Client calls: updateFcmToken() (if FCM initialized)
   → Updates FCM token
9. Navigate to appropriate dashboard
```

---

### Sequence 3: Create Blood Request Flow

```
1. Blood bank fills request form
2. Client calls: addRequest()
   → Validates user is hospital
   → Creates requests/{requestId} document
   → Returns success
3. Firestore trigger: sendRequestMessageToDonors()
   → Automatically triggered
   → Queries active donors (with fcmToken)
   → Creates notifications/{donorId}/user_notifications
   → Creates requests/{requestId}/messages (personalized)
   → Sends FCM push notifications
4. Client shows success message
5. Navigate back to dashboard
```

---

### Sequence 4: View Requests Flow (Donor)

```
1. Donor opens requests screen
2. Client calls: getRequests(limit: 50)
   → Gets paginated list of requests
   → Returns requests array
3. Client displays requests
4. If user scrolls to bottom:
   Client calls: getRequests(limit: 50, lastRequestId: ...)
   → Gets next page
```

---

### Sequence 5: View Notifications Flow

```
1. User opens notifications screen
2. Client calls: getNotifications()
   → Gets all notifications for user
   → Returns notifications array
3. Client displays notifications
4. When user taps notification:
   Client calls: markNotificationAsRead(notificationId)
   → Marks notification as read
5. Navigate to request details
```

---

### Sequence 6: Chat/Messaging Flow

```
1. User opens chat for a request
2. Client calls: getMessages(requestId)
   → Gets messages for request
   → Filters based on user role
   → Returns messages array
3. Client displays messages
4. When user sends message:
   Client calls: sendMessage(requestId, text, recipientId?)
   → Creates message document
   → Returns success
5. Client refreshes messages (polling every 5 seconds)
   Client calls: getMessages(requestId)
   → Gets updated messages
```

---

### Sequence 7: Delete Request Flow

```
1. Blood bank taps delete on request
2. Client calls: deleteRequest(requestId)
   → Validates user is hospital
   → Validates user owns request
   → Deletes all notifications for request
   → Deletes all messages for request
   → Deletes request document
   → Returns success
3. Client refreshes requests list
4. Client calls: getRequestsByBloodBankId()
   → Gets updated list
```

---

## Security Architecture

### Authentication
- All functions require authentication via `requireAuth()`
- Extracts `uid` from Firebase Auth token
- Validates token signature and expiration

### Authorization
- Role-based access control:
  - `addRequest`, `getDonors`, `getRequestsByBloodBankId`, `deleteRequest`: Hospitals only
  - `getRequests`: All authenticated users
  - Profile functions: Users can only access their own data

### Data Validation
- Input validation via `nonEmptyString()` helper
- Type checking and sanitization
- Server-side validation (client validation is not trusted)

### Error Handling
- All errors converted to `HttpsError` via `toHttpsError()`
- Consistent error format
- Proper error messages for client

### Database Access
- No direct Firestore access from client
- All operations go through Cloud Functions
- Server-side queries with proper filtering
- Atomic transactions where needed

---

## Helper Functions (`utils.js`)

### `requireAuth(request)`
- Validates request has authentication
- Returns user's `uid`
- Throws `HttpsError` if not authenticated

### `nonEmptyString(value, fieldName)`
- Validates value is a non-empty string
- Trims whitespace
- Throws `HttpsError` if invalid

### `toHttpsError(error, fallbackMessage)`
- Converts any error to `HttpsError`
- Preserves error messages
- Provides fallback message if needed

---

## Summary

### Total Functions: 21

**Authentication Functions**: 8
- `createPendingProfile`
- `completeProfileAfterVerification`
- `getUserData`
- `getUserRole`
- `updateLastLoginAt`
- `updateFcmToken`
- `updateUserProfile`
- `cleanupUnverifiedUsers` (scheduled)

**Request Functions**: 6
- `addRequest`
- `getRequests`
- `getRequestsByBloodBankId`
- `getDonors`
- `deleteRequest`
- `sendRequestMessageToDonors` (trigger)

**Notification & Messaging Functions**: 7
- `getNotifications`
- `markNotificationAsRead`
- `markNotificationsAsRead`
- `deleteNotification`
- `getMessages`
- `sendMessage`
- `cleanupOrphanNotifications` (scheduled)
- `cleanupOrphanMessages` (scheduled)

### Function Types
- **Callable Functions**: 18 (called from client)
- **Trigger Functions**: 1 (automatic Firestore trigger)
- **Scheduled Functions**: 3 (automated cleanup)

---

*Report Generated: 2025*  
*Total Cloud Functions: 21*  
*Architecture: Server-Side Security Layer*
