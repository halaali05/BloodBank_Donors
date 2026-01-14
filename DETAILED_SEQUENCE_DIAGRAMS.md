# Detailed Sequence Diagrams - Actual Implementation

This document contains detailed sequence diagrams for the major features, showing actual method calls and class interactions as implemented in the codebase.

---

## Diagram 1: User Registration Flow

### Feature: User Sign Up (Donor or Blood Bank)

This diagram shows the complete registration flow with actual method calls from the implementation.

```mermaid
sequenceDiagram
    participant User
    participant RegisterScreen
    participant RegisterController
    participant AuthService
    participant CloudFunctionsService
    participant FirebaseAuth
    participant CloudFunctions
    participant Firestore

    User->>RegisterScreen: Enter registration form<br/>(email, password, name/location)
    RegisterScreen->>RegisterController: validateForm(userType, email, password,<br/>confirmPassword, name/bloodBankName, location)
    
    alt Validation fails
        RegisterController-->>RegisterScreen: Returns validation error string
        RegisterScreen->>User: DialogHelper.showWarning()<br/>"Missing information"
    else Validation succeeds
        RegisterController-->>RegisterScreen: Returns null (valid)
        RegisterScreen->>RegisterController: register(userType, email, password,<br/>name/bloodBankName, location)
        
        alt UserType == donor
            RegisterController->>AuthService: signUpDonor(fullName, email,<br/>password, location)
        else UserType == bloodBank
            RegisterController->>AuthService: signUpBloodBank(bloodBankName, email,<br/>password, location)
        end
        
        Note over AuthService,FirebaseAuth: Step 1: Create Firebase Auth Account
        AuthService->>FirebaseAuth: createUserWithEmailAndPassword(email, password)
        FirebaseAuth-->>AuthService: UserCredential {user, uid, email, emailVerified: false}
        
        AuthService->>FirebaseAuth: cred.user!.reload()
        FirebaseAuth-->>AuthService: User reloaded
        AuthService->>FirebaseAuth: cred.user!.getIdToken(true)
        FirebaseAuth-->>AuthService: ID token (for Cloud Function auth)
        
        Note over AuthService,Firestore: Step 2: Create Pending Profile
        AuthService->>CloudFunctionsService: createPendingProfile(role, fullName/bloodBankName, location)
        CloudFunctionsService->>CloudFunctions: httpsCallable('createPendingProfile').call(callData)
        
        Note over CloudFunctions: Validates auth token<br/>Checks email verification
        CloudFunctions->>FirebaseAuth: admin.auth().getUser(uid)
        FirebaseAuth-->>CloudFunctions: UserRecord {emailVerified: false}
        
        CloudFunctions->>Firestore: db.collection('pending_profiles').doc(uid).set(payload)
        Note over Firestore: Document created:<br/>- role<br/>- fullName/bloodBankName<br/>- location<br/>- createdAt
        Firestore-->>CloudFunctions: Document saved
        
        CloudFunctions-->>CloudFunctionsService: {ok: true, emailVerified: false, message}
        CloudFunctionsService-->>AuthService: {emailVerified: false, message}
        
        Note over AuthService,FirebaseAuth: Step 3: Send Email Verification
        AuthService->>FirebaseAuth: cred.user!.reload()
        AuthService->>FirebaseAuth: cred.user!.sendEmailVerification()
        FirebaseAuth-->>AuthService: Email sent
        
        AuthService-->>RegisterController: {emailVerified: false, message}
        RegisterController-->>RegisterScreen: RegisterResult(success: true,<br/>emailVerified: false, message)
        
        Note over RegisterScreen,FirebaseAuth: Step 4: Logout
        RegisterScreen->>AuthService: logout()
        AuthService->>FirebaseAuth: signOut()
        FirebaseAuth-->>AuthService: User signed out
        
        RegisterScreen->>User: DialogHelper.showInfo()<br/>"Verification email sent"<br/>Navigator.pop() → LoginScreen
    end
```

### Actual Method Calls Sequence:

1. **RegisterScreen._handleSubmit()**
   - Calls: `RegisterController.validateForm()`
   - Calls: `RegisterController.register()`

2. **RegisterController.register()**
   - Calls: `AuthService.signUpDonor()` or `AuthService.signUpBloodBank()`

3. **AuthService.signUpDonor()/signUpBloodBank()**
   - Calls: `FirebaseAuth.createUserWithEmailAndPassword()`
   - Calls: `user.reload()` and `user.getIdToken(true)`
   - Calls: `CloudFunctionsService.createPendingProfile()`
   - Calls: `user.sendEmailVerification()`

4. **CloudFunctionsService.createPendingProfile()**
   - Calls: `FirebaseFunctions.httpsCallable('createPendingProfile').call()`

5. **Cloud Function: createPendingProfile**
   - Calls: `admin.auth().getUser(uid)`
   - Calls: `db.collection('pending_profiles').doc(uid).set()`

---

## Diagram 2: User Login Flow

### Feature: User Authentication & Profile Activation

This diagram shows the complete login flow with actual method calls, including email verification check and profile activation.

```mermaid
sequenceDiagram
    participant User
    participant LoginScreen
    participant LoginController
    participant AuthService
    participant CloudFunctionsService
    participant FirebaseAuth
    participant CloudFunctions
    participant Firestore
    participant Dashboard

    Note over User,FirebaseAuth: Prerequisite: Email Verification
    User->>FirebaseAuth: Click verification link in email
    FirebaseAuth->>FirebaseAuth: Verify email & set emailVerified = true
    
    User->>LoginScreen: Enter email & password
    LoginScreen->>LoginController: validateInput(email, password)
    
    alt Validation fails
        LoginController-->>LoginScreen: Returns false
        LoginScreen->>User: DialogHelper.showWarning()<br/>"Missing information"
    else Validation succeeds
        LoginController-->>LoginScreen: Returns true
        LoginScreen->>LoginController: login(email, password)
        
        Note over LoginController,FirebaseAuth: Step 1: Authenticate
        LoginController->>AuthService: login(email, password)
        AuthService->>FirebaseAuth: signInWithEmailAndPassword(email, password)
        FirebaseAuth-->>AuthService: User authenticated
        
        Note over AuthService,CloudFunctions: Step 2: Update Last Login (Async)
        AuthService->>CloudFunctionsService: updateLastLoginAt() (fire-and-forget)
        CloudFunctionsService->>CloudFunctions: httpsCallable('updateLastLoginAt').call()
        CloudFunctions->>Firestore: db.collection('users').doc(uid).set({lastLoginAt}, merge: true)
        
        AuthService-->>LoginController: Login successful
        
        Note over LoginController,FirebaseAuth: Step 3: Check Email Verification
        LoginController->>AuthService: isEmailVerified()
        AuthService->>FirebaseAuth: currentUser (get cached user)
        AuthService->>FirebaseAuth: user.reload() (get fresh data)
        FirebaseAuth-->>AuthService: UserRecord {emailVerified: true}
        AuthService->>FirebaseAuth: currentUser?.emailVerified
        FirebaseAuth-->>AuthService: true/false
        AuthService-->>LoginController: boolean (isVerified)
        
        alt Email not verified
            LoginController->>AuthService: logout()
            AuthService->>FirebaseAuth: signOut()
            LoginController-->>LoginScreen: LoginResult(success: false,<br/>errorType: emailNotVerified)
            LoginScreen->>User: DialogHelper.showWarning()<br/>"Please verify your email"
        else Email verified
            Note over LoginController,FirebaseAuth: Step 4: Get User Object
            LoginController->>AuthService: currentUser (getter property)
            AuthService-->>LoginController: User? (cached user object)
            
            Note over LoginController,Firestore: Step 5: Profile Activation & Get Data
            LoginController->>AuthService: completeProfileAfterVerification()<br/>(async, non-blocking, timeout: 1s)
            AuthService->>CloudFunctionsService: completeProfileAfterVerification()
            CloudFunctionsService->>CloudFunctions: httpsCallable('completeProfileAfterVerification').call()
            
            CloudFunctions->>FirebaseAuth: admin.auth().getUser(uid)
            FirebaseAuth-->>CloudFunctions: UserRecord {emailVerified: true}
            CloudFunctions->>Firestore: db.collection('pending_profiles').doc(uid).get()
            Firestore-->>CloudFunctions: Pending profile data
            CloudFunctions->>Firestore: db.runTransaction()<br/>- Move to users/{uid}<br/>- Delete pending_profiles/{uid}
            Firestore-->>CloudFunctions: Transaction completed
            
            par Profile activation runs in background
                Note over CloudFunctions: Profile activation continues
            and Get user data (awaited)
                LoginController->>AuthService: getUserData(user.uid)
                AuthService->>CloudFunctionsService: getUserData(uid: user.uid)
                CloudFunctionsService->>CloudFunctions: httpsCallable('getUserData').call({uid})
                CloudFunctions->>Firestore: db.collection('users').doc(uid).get()
                Firestore-->>CloudFunctions: User document
                CloudFunctions-->>CloudFunctionsService: User data (normalized)
                CloudFunctionsService-->>AuthService: User data map
                AuthService->>AuthService: User.fromMap(data, uid)
                AuthService-->>LoginController: User model
            end
            
            alt User data not found (after retry)
                LoginController->>AuthService: logout()
                LoginController-->>LoginScreen: LoginResult(success: false,<br/>errorType: profileNotReady)
                LoginScreen->>User: DialogHelper.showInfo()<br/>"Profile not ready"
            else User data found
                alt userData.role == UserRole.donor
                    LoginController-->>LoginScreen: LoginResult(success: true,<br/>navigationRoute: DonorDashboardScreen())
                else userData.role == UserRole.hospital
                    LoginController-->>LoginScreen: LoginResult(success: true,<br/>navigationRoute: BloodBankDashboardScreen())
                end
                
                LoginScreen->>Dashboard: Navigator.pushAndRemoveUntil()<br/>(navigationRoute, (route) => false)
                Dashboard->>User: Display dashboard
            end
        end
    end
```

### Actual Method Calls Sequence:

1. **LoginScreen._handleLogin()**
   - Calls: `LoginController.validateInput()`
   - Calls: `LoginController.login()`

2. **LoginController.login()**
   - Calls: `AuthService.login()`
   - Calls: `AuthService.isEmailVerified()`
   - Calls: `AuthService.currentUser` (getter)
   - Calls: `AuthService.completeProfileAfterVerification()` (async)
   - Calls: `AuthService.getUserData(uid)` (with retry loop)

3. **AuthService.login()**
   - Calls: `FirebaseAuth.signInWithEmailAndPassword()`
   - Calls: `CloudFunctionsService.updateLastLoginAt()` (async)

4. **AuthService.isEmailVerified()**
   - Gets: `_auth.currentUser`
   - Calls: `user.reload()`
   - Returns: `_auth.currentUser?.emailVerified ?? false`

5. **AuthService.completeProfileAfterVerification()**
   - Calls: `CloudFunctionsService.completeProfileAfterVerification()`

6. **AuthService.getUserData()**
   - Calls: `CloudFunctionsService.getUserData()`
   - Creates: `User.fromMap(data, uid)`

---

## Diagram 3: Create Blood Request Flow

### Feature: Blood Bank Creates Blood Request

This diagram shows the complete flow of creating a blood request, including automatic notification triggering.

```mermaid
sequenceDiagram
    participant Hospital
    participant NewRequestScreen
    participant NewRequestController
    participant RequestsService
    participant CloudFunctionsService
    participant FirebaseFunctions
    participant CloudFunctions
    participant Firestore
    participant Donors

    Hospital->>NewRequestScreen: Fill form & submit
    NewRequestScreen->>NewRequestScreen: _submit()
    NewRequestScreen->>NewRequestController: createRequest(...)
    
    NewRequestController->>NewRequestController: validateRequest()<br/>validateLocation()<br/>validateAuthentication()
    
    alt Validation fails
        NewRequestController-->>NewRequestScreen: {success: false, errorMessage}
        NewRequestScreen->>Hospital: Show error message
    else Validation succeeds
        NewRequestController->>NewRequestController: Create BloodRequest model
        NewRequestController->>RequestsService: _requestsService.addRequest(request)
        RequestsService->>CloudFunctionsService: _cloudFunctions.addRequest(...)
        CloudFunctionsService->>FirebaseFunctions: httpsCallable('addRequest').call(data)
        FirebaseFunctions->>CloudFunctions: addRequest(request)
        
        CloudFunctions->>CloudFunctions: requireAuth(request)
        CloudFunctions->>Firestore: db.collection('users').doc(uid).get()
        Firestore-->>CloudFunctions: User document
        
        alt Not hospital
            CloudFunctions-->>FirebaseFunctions: HttpsError('permission-denied')
            FirebaseFunctions-->>CloudFunctionsService: FirebaseFunctionsException
            CloudFunctionsService-->>RequestsService: Exception
            RequestsService-->>NewRequestController: Exception
            NewRequestController->>NewRequestController: Handle error & format message
            NewRequestController-->>NewRequestScreen: {success: false, errorMessage}
            NewRequestScreen->>Hospital: Show error
        else Is hospital
            CloudFunctions->>Firestore: db.collection('requests').doc(requestId).set(data)
            Firestore-->>CloudFunctions: Document created
            CloudFunctions-->>FirebaseFunctions: {ok: true}
            FirebaseFunctions-->>CloudFunctionsService: Success response
            CloudFunctionsService-->>RequestsService: Success
            RequestsService-->>NewRequestController: Success
            NewRequestController-->>NewRequestScreen: {success: true}
            
            Note over Firestore,CloudFunctions: Auto-triggered on document creation
            Firestore->>CloudFunctions: onDocumentCreated('requests/{requestId}')<br/>→ sendRequestMessageToDonors()
            
            CloudFunctions->>Firestore: db.collection('users').where('role', '==', 'donor').get()
            Firestore-->>CloudFunctions: Donors snapshot
            
            CloudFunctions->>CloudFunctions: Filter donors with fcmToken
            
            par For each active donor
                CloudFunctions->>Firestore: Create notification<br/>(notifications/{donorId}/user_notifications)
                CloudFunctions->>Firestore: Create message<br/>(requests/{requestId}/messages)
            end
            
            CloudFunctions->>CloudFunctions: admin.messaging().sendAll(tokens)
            CloudFunctions->>Donors: FCM push notification
            
            NewRequestScreen->>Hospital: Show success & navigate back
        end
    end
```

### Actual Method Calls:

1. **NewRequestScreen._submit()** (`lib/screens/new_request_screen.dart`)
   - Calls: `_controller.createRequest(...)` - delegates to controller

2. **NewRequestController.createRequest()** (`lib/controllers/new_request_controller.dart`)
   - Validates: `validateRequest()` → `validateLocation()`, `validateAuthentication()`
   - Creates: `BloodRequest` model from parameters
   - Calls: `_requestsService.addRequest(request)`
   - Returns: `{success: bool, errorMessage?: string}`

3. **RequestsService.addRequest()** (`lib/services/requests_service.dart`)
   - Calls: `_cloudFunctions.addRequest(...)` with request parameters

4. **CloudFunctionsService.addRequest()** (`lib/services/cloud_functions_service.dart`)
   - Calls: `_functions.httpsCallable('addRequest').call(data)`

2. **addRequest** (`functions/src/requests.js`)
   - `requireAuth(request)` → extracts uid
   - `db.collection('users').doc(uid).get()` → validate role === 'hospital'
   - `db.collection('requests').doc(requestId).set(data)` → create request

3. **sendRequestMessageToDonors** (`functions/src/requests.js`)
   - Triggered: `onDocumentCreated('requests/{requestId}')`
   - `db.collection('users').where('role', '==', 'donor').get()` → get all donors
   - Filter: Donors with `fcmToken` (active users)
   - Create notifications: `notifications/{donorId}/user_notifications`
   - Create messages: `requests/{requestId}/messages`
   - `admin.messaging().sendAll(tokens)` → send FCM push notifications

---

## Summary of Actual Classes and Methods

### Registration Flow:
- **RegisterScreen**: `_handleSubmit()`
- **RegisterController**: `validateForm()`, `register()`
- **AuthService**: `signUpDonor()`, `signUpBloodBank()`, `logout()`
- **CloudFunctionsService**: `createPendingProfile()`
- **Cloud Function**: `createPendingProfile` → `admin.auth().getUser()`, `db.collection('pending_profiles').doc().set()`

### Login Flow:
- **LoginScreen**: `_handleLogin()`
- **LoginController**: `validateInput()`, `login()`
- **AuthService**: `login()`, `isEmailVerified()`, `currentUser`, `completeProfileAfterVerification()`, `getUserData()`, `logout()`
- **CloudFunctionsService**: `updateLastLoginAt()`, `completeProfileAfterVerification()`, `getUserData()`
- **Cloud Functions**: `updateLastLoginAt`, `completeProfileAfterVerification`, `getUserData`

### Create Request Flow:
- **NewRequestScreen** (`lib/screens/new_request_screen.dart`): `_submit()`
- **FirebaseFunctions**: `instanceFor(region: 'us-central1').httpsCallable('addRequest').call()`
- **addRequest** (`functions/src/requests.js`): `requireAuth()`, `db.collection('users').doc().get()`, `db.collection('requests').doc().set()`
- **sendRequestMessageToDonors** (`functions/src/requests.js`): `onDocumentCreated()`, `db.collection('users').where().get()`, `admin.messaging().sendAll()`

---

*Detailed Sequence Diagrams Generated: 2025*  
*Shows Actual Implementation with Real Method Calls*
