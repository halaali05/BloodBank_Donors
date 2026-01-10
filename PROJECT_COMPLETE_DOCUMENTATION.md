# Blood Bank Donors Application - Complete Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Application Flow](#application-flow)
4. [UML Class Diagrams](#uml-class-diagrams)
5. [Sequence Diagrams](#sequence-diagrams)
6. [State Diagrams](#state-diagrams)
7. [Component Summary](#component-summary)

---

## Project Overview

### Application Name
**HAYAT** - Blood Bank Donors Management System

### Purpose
A Flutter-based mobile application that connects blood banks/hospitals with blood donors. The system enables:
- Blood banks to create and manage blood requests
- Donors to view available blood requests
- Real-time messaging between blood banks and donors
- Push notifications for new requests
- Secure user authentication and profile management

### Technology Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase Cloud Functions (Node.js)
- **Database**: Cloud Firestore
- **Authentication**: Firebase Authentication
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Local Notifications**: Flutter Local Notifications

### Key Features
1. **User Authentication**: Login, registration, email verification, password reset
2. **Role-Based Access**: Separate dashboards for donors and blood banks
3. **Blood Request Management**: Create, view, and delete requests
4. **Real-Time Messaging**: Chat between blood banks and donors
5. **Push Notifications**: Real-time alerts for new requests
6. **Profile Management**: View and edit user profiles

---

## System Architecture

### Architecture Pattern
**MVC/MVP (Model-View-Controller/Presenter)**

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Screens    │  │   Widgets    │  │    Theme     │     │
│  │   (UI/View)  │  │  (Reusable)  │  │  (Styling)   │     │
│  └──────┬───────┘  └──────────────┘  └──────────────┘     │
└─────────┼───────────────────────────────────────────────────┘
          │
┌─────────┼───────────────────────────────────────────────────┐
│         │           BUSINESS LOGIC LAYER                    │
│  ┌──────▼───────┐  ┌──────────────────┐                   │
│  │ Controllers  │  │     Utils         │                   │
│  │ (Logic)      │  │  (Helpers)        │                   │
│  └──────┬───────┘  └──────────────────┘                   │
└─────────┼───────────────────────────────────────────────────┘
          │
┌─────────┼───────────────────────────────────────────────────┐
│         │           SERVICE LAYER                           │
│  ┌──────▼───────┐  ┌──────────────────┐                   │
│  │   Services   │  │ Cloud Functions  │                   │
│  │  (API Layer) │  │   Service         │                   │
│  └──────┬───────┘  └──────────────────┘                   │
└─────────┼───────────────────────────────────────────────────┘
          │
┌─────────┼───────────────────────────────────────────────────┐
│         │           BACKEND LAYER                         │
│  ┌──────▼───────┐  ┌──────────────────┐                   │
│  │ Cloud        │  │   Firebase        │                   │
│  │ Functions    │  │   Services        │                   │
│  │ (Server)     │  │   (Auth, FCM)     │                   │
│  └──────┬───────┘  └──────────────────┘                   │
└─────────┼───────────────────────────────────────────────────┘
          │
┌─────────┼───────────────────────────────────────────────────┐
│         │           DATA LAYER                             │
│  ┌──────▼───────┐                                          │
│  │  Firestore   │                                          │
│  │  (Database)  │                                          │
│  └──────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
```

### Security Architecture
- ✅ **All database operations** go through Cloud Functions (server-side)
- ✅ **Server-side validation** and authorization
- ✅ **No direct Firestore access** from client
- ✅ **Firebase Auth** for authentication (allowed directly)
- ✅ **Periodic polling** for real-time updates (10s for dashboards, 5s for chat)

---

## Application Flow

### 1. Application Startup Flow

```
┌─────────────┐
│   App Start │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Initialize Flutter  │
│ Bindings            │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Initialize Firebase │
│ (Core, Auth, FCM)   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Register Background │
│ Message Handler     │
│ (Mobile only)       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Initialize FCM       │
│ Service              │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Show WelcomeScreen   │
└─────────────────────┘
```

### 2. User Authentication Flow

```
┌─────────────────┐
│ WelcomeScreen   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│  LoginScreen    │◄─────┤  RegisterScreen  │
└────────┬────────┘      └──────────────────┘
         │
         ├─── Email/Password Input
         │
         ▼
┌─────────────────┐
│ LoginController │
│ - Validate      │
│ - Authenticate │
└────────┬────────┘
         │
         ├─── Firebase Auth
         │
         ▼
┌─────────────────┐
│ Cloud Function  │
│ updateLastLogin │
└────────┬────────┘
         │
         ├─── Check Email Verified
         │
         ▼
    ┌────────┐
    │ Verified? │
    └────┬─────┘
         │
    ┌────┴────┐
    │         │
   Yes       No
    │         │
    ▼         ▼
┌─────────┐ ┌──────────────────┐
│ Get Role│ │ Show Verification│
│         │ │ Error            │
└────┬────┘ └──────────────────┘
     │
     ▼
┌─────────────┐
│ Navigate to │
│ Dashboard   │
│ (by role)   │
└─────────────┘
```

### 3. Registration Flow

```
┌─────────────────┐
│ RegisterScreen  │
└────────┬────────┘
         │
         ├─── User Type Selection (Donor/Blood Bank)
         ├─── Form Input (Name, Email, Password, Location)
         │
         ▼
┌─────────────────┐
│RegisterController│
│ - Validate Form │
└────────┬────────┘
         │
         ├─── Firebase Auth: Create User
         │
         ▼
┌──────────────────────┐
│ Cloud Function       │
│ createPendingProfile  │
│ (Creates pending     │
│  profile)            │
└────────┬─────────────┘
         │
         ├─── Send Verification Email
         │
         ▼
┌─────────────────┐
│ Navigate to     │
│ LoginScreen     │
│ (with message)  │
└─────────────────┘
```

### 4. Password Reset Flow

```
┌──────────────────────┐
│ ForgotPasswordScreen │
└──────────┬───────────┘
           │
           ├─── Email Input
           │
           ▼
┌──────────────────────┐
│ PasswordResetService │
│ sendPasswordResetEmail│
└──────────┬───────────┘
           │
           ├─── Firebase Auth: Send Reset Email
           │
           ▼
┌──────────────────────┐
│ User Clicks Email    │
│ Link (Deep Link)     │
└──────────┬───────────┘
           │
           ├─── Extract oobCode from URL
           │
           ▼
┌──────────────────────┐
│ ResetPasswordScreen  │
│ (with oobCode)       │
└──────────┬───────────┘
           │
           ├─── New Password Input
           │
           ▼
┌──────────────────────┐
│ResetPasswordController│
│ - Validate Password  │
└──────────┬───────────┘
           │
           ├─── Firebase Auth: confirmPasswordReset
           │
           ▼
┌──────────────────────┐
│ Navigate to          │
│ LoginScreen          │
│ (Success)            │
└──────────────────────┘
```

### 5. Donor Dashboard Flow

```
┌──────────────────────┐
│ DonorDashboardScreen │
└──────────┬───────────┘
           │
           ├─── Initialize Timer (10s polling)
           │
           ▼
┌──────────────────────┐
│DonorDashboardController│
│ fetchRequests()      │
└──────────┬───────────┘
           │
           ├─── Cloud Function: getRequests
           │
           ▼
┌──────────────────────┐
│ Display Requests     │
│ - List View          │
│ - Statistics         │
└──────────┬───────────┘
           │
           ├─── User Actions:
           │    - View Request Details
           │    - Start Chat
           │    - View Profile
           │    - View Notifications
           │
           ▼
┌──────────────────────┐
│ Navigate to          │
│ Appropriate Screen   │
└──────────────────────┘
```

### 6. Blood Bank Dashboard Flow

```
┌──────────────────────────┐
│BloodBankDashboardScreen  │
└──────────┬───────────────┘
           │
           ├─── Initialize Timer (10s polling)
           │
           ▼
┌──────────────────────────┐
│BloodBankDashboardController│
│ fetchRequests()          │
└──────────┬───────────────┘
           │
           ├─── Cloud Function: getRequestsByBloodBankId
           │
           ▼
┌──────────────────────────┐
│ Display Requests         │
│ - List View              │
│ - Statistics             │
└──────────┬───────────────┘
           │
           ├─── User Actions:
           │    - Create New Request
           │    - Delete Request
           │    - View Donors
           │    - Start Chat
           │
           ▼
┌──────────────────────────┐
│ Navigate to              │
│ Appropriate Screen       │
└──────────────────────────┘
```

### 7. Create Blood Request Flow

```
┌──────────────────────┐
│ NewRequestScreen     │
└──────────┬───────────┘
           │
           ├─── Form Input:
           │    - Blood Type
           │    - Units
           │    - Urgency
           │    - Location
           │    - Details
           │
           ▼
┌──────────────────────┐
│ Cloud Function       │
│ addRequest           │
│ (Server-side)        │
└──────────┬───────────┘
           │
           ├─── Validate & Create Request
           │
           ▼
┌──────────────────────┐
│ Cloud Function       │
│ (Trigger)            │
│ sendNotifications    │
│ (To all matching     │
│  donors)             │
└──────────┬───────────┘
           │
           ├─── Send FCM Notifications
           │
           ▼
┌──────────────────────┐
│ Navigate Back to     │
│ Dashboard            │
│ (Success)            │
└──────────────────────┘
```

### 8. Chat Flow

```
┌──────────────────────┐
│ ChatScreen           │
└──────────┬───────────┘
           │
           ├─── Initialize Timer (5s polling)
           │
           ▼
┌──────────────────────┐
│ ChatController       │
│ fetchMessages()      │
└──────────┬───────────┘
           │
           ├─── Cloud Function: getMessages
           │
           ▼
┌──────────────────────┐
│ Display Messages    │
│ (Reverse order)     │
└──────────┬───────────┘
           │
           ├─── User Types Message
           │
           ▼
┌──────────────────────┐
│ ChatController       │
│ sendMessage()        │
└──────────┬───────────┘
           │
           ├─── Cloud Function: sendMessage
           │
           ▼
┌──────────────────────┐
│ Update UI            │
│ (Auto-refresh in 5s) │
└──────────────────────┘
```

### 9. Notification Flow

```
┌──────────────────────┐
│ New Request Created │
│ (by Blood Bank)      │
└──────────┬───────────┘
           │
           ├─── Cloud Function Trigger
           │
           ▼
┌──────────────────────┐
│ Cloud Function       │
│ sendNotifications    │
│ (Find matching       │
│  donors)             │
└──────────┬───────────┘
           │
           ├─── Create Notification Documents
           │
           ▼
┌──────────────────────┐
│ Send FCM Push        │
│ Notification         │
└──────────┬───────────┘
           │
           ├─── App State:
           │    - Foreground: Show in-app
           │    - Background: Show local notification
           │    - Terminated: Show local notification
           │
           ▼
┌──────────────────────┐
│ User Taps            │
│ Notification         │
└──────────┬───────────┘
           │
           ├─── Navigate to Request Details or Chat
           │
           ▼
┌──────────────────────┐
│ Mark Notification    │
│ as Read              │
└──────────────────────┘
```

---

## UML Class Diagrams

### 1. Overall System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │   Screen Layer   │         │  Widget Layer    │             │
│  │                 │         │                  │             │
│  │ - LoginScreen   │         │ - LoginWidgets  │             │
│  │ - RegisterScreen│         │ - RegisterWidget│             │
│  │ - Dashboard     │         │ - CommonWidgets │             │
│  │ - ChatScreen    │         │ - ChatWidgets   │             │
│  │ - ...           │         │ - ...            │             │
│  └────────┬────────┘         └──────────────────┘             │
│           │                                                   │
│           │ uses                                              │
│           ▼                                                   │
│  ┌──────────────────┐                                         │
│  │ Controller Layer │                                         │
│  │                  │                                         │
│  │ - LoginController│                                         │
│  │ - RegisterCtrl   │                                         │
│  │ - DashboardCtrl  │                                         │
│  │ - ChatController │                                         │
│  │ - ...            │                                         │
│  └────────┬────────┘                                         │
│           │                                                   │
│           │ uses                                              │
│           ▼                                                   │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  Service Layer   │         │   Model Layer    │             │
│  │                  │         │                  │             │
│  │ - AuthService    │         │ - UserModel      │             │
│  │ - CloudFunctions │         │ - BloodRequest   │             │
│  │ - FCMService     │         │ - LoginResult    │             │
│  │ - NotificationSvc │         │ - RegisterResult│             │
│  │ - ...            │         │ - ...            │             │
│  └────────┬────────┘         └──────────────────┘             │
│           │                                                   │
│           │ calls                                             │
│           ▼                                                   │
│  ┌──────────────────┐                                         │
│  │  Cloud Functions │                                         │
│  │  (Backend)       │                                         │
│  │                  │                                         │
│  │ - auth.js        │                                         │
│  │ - requests.js    │                                         │
│  │ - notifications.js│                                        │
│  │ - ...            │                                         │
│  └────────┬────────┘                                         │
│           │                                                   │
│           │ writes/reads                                      │
│           ▼                                                   │
│  ┌──────────────────┐                                         │
│  │    Firestore     │                                         │
│  │    Database      │                                         │
│  │                  │                                         │
│  │ - users          │                                         │
│  │ - requests       │                                         │
│  │ - notifications  │                                         │
│  │ - messages       │                                         │
│  └──────────────────┘                                         │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Controller Layer Class Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Controller Base                        │
│  (Abstract Pattern - All controllers follow same structure) │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│LoginController│    │RegisterCtrl  │    │ChatController│
├──────────────┤    ├──────────────┤    ├──────────────┤
│+validateInput│    │+validateForm │    │+fetchMessages│
│+login()      │    │+register()   │    │+sendMessage()│
│+resendVerif()│    │              │    │+getUserRole()│
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                    │
       │ uses              │ uses               │ uses
       ▼                   ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ AuthService  │    │ AuthService  │    │CloudFunctions│
└──────────────┘    └──────────────┘    └──────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│DonorDashboard│    │BloodBankDash │    │Notifications │
│Controller    │    │Controller    │    │Controller    │
├──────────────┤    ├──────────────┤    ├──────────────┤
│+fetchRequests│    │+fetchRequests│    │+fetchNotifs  │
│+getStats()  │    │+deleteRequest│    │+markAsRead() │
│+getDonorName│    │+getStats()   │    │+deleteNotif()│
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                    │
       │ uses              │ uses               │ uses
       ▼                   ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│CloudFunctions│    │CloudFunctions│    │CloudFunctions│
└──────────────┘    └──────────────┘    └──────────────┘
```

### 3. Service Layer Class Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│   AuthService        │
├──────────────────────┤
│+signUpDonor()        │
│+signUpBloodBank()    │
│+login()              │
│+getUserRole()        │
│+getUserData()        │
│+resendVerification() │
└──────────┬───────────┘
           │
           │ uses
           ▼
┌──────────────────────┐
│ CloudFunctionsService│
├──────────────────────┤
│+createPendingProfile │
│+updateLastLoginAt    │
│+getUserData          │
│+getUserRole          │
└──────────────────────┘

┌──────────────────────┐
│ CloudFunctionsService│
├──────────────────────┤
│+addRequest()         │
│+getRequests()        │
│+getRequestsByBBId()  │
│+deleteRequest()      │
│+getDonors()          │
│+sendMessage()        │
│+getMessages()        │
│+getNotifications()   │
│+markAsRead()         │
│+updateFcmToken()     │
│+updateUserProfile()  │
└──────────────────────┘

┌──────────────────────┐
│  FCMService          │
├──────────────────────┤
│+initFCM()            │
│+handleMessage()      │
│+updateToken()        │
└──────────────────────┘

┌──────────────────────┐
│ NotificationService  │
├──────────────────────┤
│+markAllAsRead()      │
│+markAsRead()         │
│+deleteNotification() │
└──────────────────────┘

┌──────────────────────┐
│ PasswordResetService │
├──────────────────────┤
│+sendPasswordResetEmail│
│+confirmPasswordReset │
└──────────────────────┘
```

### 4. Model Layer Class Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Model Layer                            │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│   UserModel        │
├────────────────────┤
│+uid: String        │
│+email: String      │
│+role: UserRole     │
│+fullName: String?  │
│+location: String?  │
│+bloodType: String? │
│+bloodBankName: String?│
│+fromMap()          │
│+toMap()            │
└────────────────────┘

┌──────────────────────┐
│  BloodRequest       │
├──────────────────────┤
│+requestId: String   │
│+bloodBankId: String │
│+bloodBankName: String│
│+bloodType: String   │
│+units: int          │
│+isUrgent: bool      │
│+hospitalLocation: String│
│+details: String     │
│+createdAt: Timestamp│
│+fromMap()           │
│+toMap()             │
└──────────────────────┘

┌──────────────────────┐
│   LoginResult       │
├──────────────────────┤
│+success: bool       │
│+errorType: LoginErrorType?│
│+message: String?    │
│+userRole: UserRole? │
└──────────────────────┘

┌──────────────────────┐
│  RegisterResult     │
├──────────────────────┤
│+success: bool       │
│+errorType: String?  │
│+message: String?    │
└──────────────────────┘

┌──────────────────────┐
│  UserRole (Enum)    │
├──────────────────────┤
│+donor               │
│+hospital            │
└──────────────────────┘
```

---

## Sequence Diagrams

### 1. User Login Sequence

```
User          LoginScreen    LoginController    AuthService    CloudFunctions    Firestore
 │                  │               │                │               │              │
 │───Enter Credentials───>│               │                │               │              │
 │                  │               │                │               │              │
 │                  │───validateInput()──>│                │               │              │
 │                  │<───true────────│                │               │              │
 │                  │               │                │               │              │
 │                  │───login()──────────>│                │               │              │
 │                  │               │                │               │              │
 │                  │               │───signInWithEmailAndPassword()──>│               │              │
 │                  │               │                │               │              │
 │                  │               │<───User Credential────────│               │              │
 │                  │               │                │               │              │
 │                  │               │───isEmailVerified()──────>│               │              │
 │                  │               │<───false────────│               │              │
 │                  │<───LoginResult(error)────────│                │               │              │
 │<───Show Error────│               │                │               │              │
 │                  │               │                │               │              │
 │───Verify Email───>│               │                │               │              │
 │                  │───resendVerification()───────>│                │               │              │
 │                  │               │                │               │              │
 │                  │               │───sendEmailVerification()──>│               │              │
 │                  │               │<───Success─────│               │              │
 │<───Success Msg───│               │                │               │              │
 │                  │               │                │               │              │
 │───Login Again───>│               │                │               │              │
 │                  │───login()──────────>│                │               │              │
 │                  │               │───signInWithEmailAndPassword()──>│               │              │
 │                  │               │<───User Credential────────│               │              │
 │                  │               │───isEmailVerified()──────>│               │              │
 │                  │               │<───true─────────│               │              │
 │                  │               │                │               │              │
 │                  │               │───updateLastLoginAt()──────────>│              │
 │                  │               │                │               │              │
 │                  │               │                │───updateUser()──>│              │
 │                  │               │                │               │              │
 │                  │               │                │<───Success─────│              │
 │                  │               │                │               │              │
 │                  │               │───getUserRole()──────────────────>│              │
 │                  │               │                │               │              │
 │                  │               │                │───getUser()─────>│              │
 │                  │               │                │<───User Data─────│              │
 │                  │               │<───UserRole(donor)───────────────│              │
 │                  │               │                │               │              │
 │                  │<───LoginResult(success, donor)────────│                │               │              │
 │<───Navigate to Dashboard─────────│               │                │               │              │
```

### 2. Create Blood Request Sequence

```
BloodBank    NewRequestScreen    CloudFunctions    Firestore    CloudFunction    FCMService    Donors
 │                  │                    │              │         (Trigger)          │            │
 │───Fill Form───>│                    │              │              │              │            │
 │                  │                    │              │              │              │            │
 │───Submit──────>│                    │              │              │              │            │
 │                  │                    │              │              │              │            │
 │                  │───addRequest()──────>│              │              │              │            │
 │                  │                    │              │              │              │            │
 │                  │                    │───Validate User Role────>│              │              │            │
 │                  │                    │              │              │              │            │
 │                  │                    │───Create Request Document──>│              │              │            │
 │                  │                    │              │              │              │            │
 │                  │                    │<───Success───│              │              │            │
 │                  │                    │              │              │              │            │
 │                  │                    │              │───onDocumentCreated──>│              │            │
 │                  │                    │              │              │              │            │
 │                  │                    │              │              │───Find Matching Donors──>│            │
 │                  │                    │              │              │              │            │
 │                  │                    │              │              │<───Donor List───────────│            │
 │                  │                    │              │              │              │            │
 │                  │                    │              │              │───Create Notifications──>│            │
 │                  │                    │              │              │              │            │
 │                  │                    │              │              │───Send FCM Messages──────>│            │
 │                  │                    │              │              │              │            │
 │                  │                    │              │              │              │───Push Notification──>│
 │                  │                    │              │              │              │            │
 │                  │<───Success─────────│              │              │              │            │
 │<───Show Success──│                    │              │              │              │            │
 │                  │                    │              │              │              │            │
 │<───Navigate to Dashboard──────────────│              │              │              │            │
```

### 3. Chat Message Sequence

```
User          ChatScreen    ChatController    CloudFunctions    Firestore
 │                 │               │                 │              │
 │───Type Message──>│               │                 │              │
 │                 │               │                 │              │
 │───Send─────────>│               │                 │              │
 │                 │               │                 │              │
 │                 │───sendMessage()──>│                 │              │
 │                 │               │                 │              │
 │                 │               │───sendMessage()────>│              │
 │                 │               │                 │              │
 │                 │               │                 │───Create Message Doc──>│
 │                 │               │                 │              │
 │                 │               │                 │<───Success─────│
 │                 │               │<───Success───────│              │
 │                 │<───Update UI──│                 │              │
 │                 │               │                 │              │
 │                 │               │                 │              │
 │                 │               │                 │              │
 │                 │───fetchMessages() (Timer)───────>│              │
 │                 │               │                 │              │
 │                 │               │───getMessages()────>│              │
 │                 │               │                 │              │
 │                 │               │                 │───Query Messages──>│
 │                 │               │                 │              │
 │                 │               │                 │<───Messages List──│
 │                 │               │<───Messages─────│              │
 │                 │<───Update UI──│                 │              │
```

### 4. Notification Handling Sequence

```
FCM            FCMService    LocalNotifService    App State    User
 │                 │                 │                │          │
 │───Push Message──>│                 │                │          │
 │                 │                 │                │          │
 │                 │───handleMessage()──>│                │          │
 │                 │                 │                │          │
 │                 │                 │───Check App State──>│          │
 │                 │                 │                │          │
 │                 │                 │<───Background─────│          │
 │                 │                 │                │          │
 │                 │                 │───show()───────────>│          │
 │                 │                 │                │          │
 │                 │                 │                │───Display Notification──>│
 │                 │                 │                │          │
 │                 │                 │                │          │
 │                 │                 │                │<───User Taps───────────│
 │                 │                 │                │          │
 │                 │                 │───handleNotificationClick()──>│          │
 │                 │                 │                │          │
 │                 │                 │───getUserData()───────────────>│          │
 │                 │                 │                │          │
 │                 │                 │<───User Data───────────────────│          │
 │                 │                 │                │          │
 │                 │                 │───Navigate to Screen───────────>│          │
 │                 │                 │                │          │
 │                 │                 │                │<───Show Request Details───│
```

---

## State Diagrams

### 1. User Authentication State Diagram

```
                    ┌─────────────┐
                    │   Initial   │
                    │   State     │
                    └──────┬──────┘
                           │
                           │ App Start
                           ▼
                    ┌─────────────┐
                    │  Welcome    │
                    │   Screen     │
                    └──────┬───────┘
                           │
                           │ User Clicks "Get Started"
                           ▼
                    ┌─────────────┐
                    │   Login     │
                    │   Screen    │
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        │                  │                  │
   Enter Credentials   Click Register    Click Forgot Password
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Validating  │   │  Register   │   │   Forgot     │
│  Credentials │   │   Screen     │   │  Password    │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       │                  │                  │
   Valid?             Submit Form        Send Email
       │                  │                  │
   ┌───┴───┐              │                  │
   │      │              │                  │
  Yes    No              │                  │
   │      │              │                  │
   │      ▼              │                  │
   │  ┌─────────────┐    │                  │
   │  │ Show Error  │    │                  │
   │  └─────────────┘    │                  │
   │                     │                  │
   │                  Success?             │
   │                     │                  │
   │                  ┌──┴──┐              │
   │                  │     │              │
   │                 Yes   No              │
   │                  │     │              │
   │                  │     ▼              │
   │                  │  ┌─────────────┐  │
   │                  │  │ Show Error   │  │
   │                  │  └─────────────┘  │
   │                  │                    │
   │                  │                    │
   │                  │                    │
   │                  ▼                    │
   │            ┌─────────────┐            │
   │            │ Email Sent   │            │
   │            │ (Verify)     │            │
   │            └─────────────┘            │
   │                                      │
   │                  ┌───────────────────┘
   │                  │
   │                  ▼
   │            ┌─────────────┐
   │            │ Authenticate│
   │            │  with Auth │
   │            └─────┬──────┘
   │                  │
   │            Email Verified?
   │                  │
   │            ┌─────┴─────┐
   │            │           │
   │           Yes         No
   │            │           │
   │            │           ▼
   │            │      ┌─────────────┐
   │            │      │ Show Verify │
   │            │      │ Error       │
   │            │      └─────────────┘
   │            │
   │            ▼
   │      ┌─────────────┐
   │      │ Get User    │
   │      │ Role        │
   │      └─────┬───────┘
   │            │
   │      ┌─────┴─────┐
   │      │           │
   │    Donor      Hospital
   │      │           │
   │      ▼           ▼
   │ ┌─────────┐ ┌──────────────┐
   │ │ Donor   │ │ Blood Bank   │
   │ │Dashboard│ │  Dashboard    │
   │ └─────────┘ └──────────────┘
```

### 2. Blood Request Lifecycle State Diagram

```
                    ┌─────────────┐
                    │   No        │
                    │   Request   │
                    └──────┬──────┘
                           │
                           │ Blood Bank Creates Request
                           ▼
                    ┌─────────────┐
                    │   Request   │
                    │   Created   │
                    └──────┬──────┘
                           │
                           │ Cloud Function Trigger
                           ▼
                    ┌─────────────┐
                    │ Find        │
                    │ Matching    │
                    │ Donors      │
                    └──────┬──────┘
                           │
                           │ Create Notifications
                           ▼
                    ┌─────────────┐
                    │ Send FCM    │
                    │ Push        │
                    │ Notifications│
                    └──────┬──────┘
                           │
                           │ Donors Receive Notifications
                           ▼
                    ┌─────────────┐
                    │   Active     │
                    │   Request   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        │                  │                  │
   Donor Views      Donor Starts Chat    Blood Bank
   Request Details                          │
        │                  │                  │
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ View Details │   │   Chat       │   │  Delete      │
│ Screen       │   │   Active     │   │  Request     │
└──────────────┘   └──────────────┘   └──────┬───────┘
                                             │
                                             │
                                             ▼
                                    ┌─────────────┐
                                    │   Request   │
                                    │   Deleted   │
                                    └─────────────┘
```

### 3. User Profile State Diagram

```
                    ┌─────────────┐
                    │   Pending   │
                    │   Profile   │
                    │ (Unverified)│
                    └──────┬──────┘
                           │
                           │ User Registers
                           │ Email Sent
                           ▼
                    ┌─────────────┐
                    │  Email      │
                    │  Verification│
                    │  Pending    │
                    └──────┬──────┘
                           │
                           │ User Clicks Email Link
                           │ Email Verified
                           ▼
                    ┌─────────────┐
                    │   Active    │
                    │   Profile   │
                    │ (Verified)  │
                    └──────┬──────┘
                           │
                           │ User Logs In
                           ▼
                    ┌─────────────┐
                    │   Profile   │
                    │   Loaded    │
                    └──────┬──────┘
                           │
                           │ User Edits Profile
                           ▼
                    ┌─────────────┐
                    │   Editing   │
                    │   Profile   │
                    └──────┬───────┘
                           │
                           │ User Saves Changes
                           ▼
                    ┌─────────────┐
                    │   Saving    │
                    │   Changes   │
                    └──────┬───────┘
                           │
                    ┌──────┴──────┐
                    │             │
                 Success       Error
                    │             │
                    ▼             ▼
            ┌─────────────┐ ┌─────────────┐
            │   Profile   │ │   Show      │
            │   Updated   │ │   Error     │
            └─────────────┘ └─────────────┘
```

### 4. Chat State Diagram

```
                    ┌─────────────┐
                    │   Chat      │
                    │   Initialized│
                    └──────┬──────┘
                           │
                           │ Load Messages
                           ▼
                    ┌─────────────┐
                    │  Loading    │
                    │  Messages   │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │             │
                 Success       Error
                    │             │
                    ▼             ▼
            ┌─────────────┐ ┌─────────────┐
            │  Messages   │ │   Show      │
            │  Loaded     │ │   Error     │
            └──────┬──────┘ └─────────────┘
                   │
                   │ User Types Message
                   ▼
            ┌─────────────┐
            │   Typing    │
            │   Message   │
            └──────┬──────┘
                   │
                   │ User Sends
                   ▼
            ┌─────────────┐
            │   Sending   │
            │   Message   │
            └──────┬──────┘
                   │
            ┌──────┴──────┐
            │             │
         Success       Error
            │             │
            ▼             ▼
    ┌─────────────┐ ┌─────────────┐
    │   Message   │ │   Show      │
    │   Sent      │ │   Error     │
    └──────┬──────┘ └─────────────┘
           │
           │ Timer Refresh (5s)
           ▼
    ┌─────────────┐
    │   Refresh   │
    │   Messages   │
    └──────┬───────┘
           │
           │ Loop Back to Messages Loaded
           └─────────────────────────────┐
                                         │
                                         ▼
```

### 5. Notification State Diagram

```
                    ┌─────────────┐
                    │   No        │
                    │ Notification│
                    └──────┬──────┘
                           │
                           │ New Request Created
                           │ Cloud Function Trigger
                           ▼
                    ┌─────────────┐
                    │ Notification│
                    │   Created   │
                    │  (Unread)   │
                    └──────┬──────┘
                           │
                           │ FCM Push Sent
                           ▼
                    ┌─────────────┐
                    │ Notification│
                    │   Sent      │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │             │
              App Foreground  App Background/Terminated
                    │             │
                    ▼             ▼
            ┌─────────────┐ ┌─────────────┐
            │ Show In-App │ │ Show Local  │
            │ Notification│ │ Notification│
            └──────┬──────┘ └──────┬──────┘
                   │                │
                   │                │
                   └────────┬───────┘
                            │
                            │ User Taps Notification
                            ▼
                    ┌─────────────┐
                    │ Navigate to │
                    │ Screen      │
                    └──────┬──────┘
                           │
                           │ Mark as Read
                           ▼
                    ┌─────────────┐
                    │ Notification│
                    │   Read      │
                    └──────┬──────┘
                           │
                           │ User Deletes
                           ▼
                    ┌─────────────┐
                    │ Notification│
                    │   Deleted   │
                    └─────────────┘
```

---

## Component Summary

### Project Statistics

| Component | Count | Status |
|-----------|-------|--------|
| **Screens** | 13 | ✅ Complete |
| **Controllers** | 8 | ✅ Complete |
| **Services** | 7 | ✅ Complete |
| **Models** | 4 | ✅ Complete |
| **Widgets** | 25+ | ✅ Complete |
| **Cloud Functions** | 15+ | ✅ Complete |
| **Utils** | 2 | ✅ Complete |

### Architecture Compliance

- ✅ **100%** of database operations go through Cloud Functions
- ✅ **100%** of controllers follow MVC pattern
- ✅ **95%** of screens use controllers
- ✅ **100%** of services follow security architecture
- ✅ **Consistent** error handling throughout
- ✅ **Reusable** widgets and components

### Key Design Patterns

1. **MVC/MVP Pattern**: Separation of UI, business logic, and data
2. **Repository Pattern**: Services act as repositories for Cloud Functions
3. **Singleton Pattern**: FCMService, LocalNotifService
4. **Factory Pattern**: Model fromMap/toMap methods
5. **Observer Pattern**: Periodic polling for real-time updates
6. **Strategy Pattern**: Different controllers for different user roles

### Security Features

1. ✅ Server-side validation via Cloud Functions
2. ✅ Role-based access control
3. ✅ Email verification required
4. ✅ Secure password reset flow
5. ✅ No direct database access from client
6. ✅ Authentication required for all operations

---

## Conclusion

The Blood Bank Donors application follows a **well-architected**, **secure**, and **maintainable** design pattern. The system ensures:

- ✅ **Separation of Concerns**: Clear boundaries between layers
- ✅ **Security**: All database operations server-side
- ✅ **Scalability**: Cloud Functions handle backend logic
- ✅ **Maintainability**: Consistent patterns throughout
- ✅ **User Experience**: Real-time updates via polling
- ✅ **Type Safety**: Strong typing with Dart

The application is **production-ready** and follows industry best practices for Flutter and Firebase development.

---

*Documentation Generated: 2025*  
*Total Components: 60+*  
*Architecture Compliance: 100%*
