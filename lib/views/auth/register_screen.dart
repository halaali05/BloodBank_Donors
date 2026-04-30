import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/register_controller.dart';
import '../../models/register_models.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/phone_auth_service.dart';
import '../../shared/utils/jordan_phone.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/dialog_helper.dart';
import '../../shared/widgets/auth/login_widgets.dart';
import '../../shared/widgets/auth/register_widgets.dart';
import '../dashboard/donor_dashboard_screen.dart';
import '../map_location_picker_screen.dart';

enum DonorGenderSelection { male, female }

/// **Register screen — email/password sign-up (donors and blood banks)**
///
/// ## Entry
/// Opened from **Create account** on the login screen. The user fills the form here;
/// behaviour splits by **role** (donor vs blood bank).
///
/// -----------------------------------------------------------------------------
/// ## Blood bank flow (hospital role)
/// 1. **Form** blood bank name, email, password, confirm password, pin location on map.
/// 2. **Create account** → [RegisterController.submitRegistration] → [AuthService.signUpBloodBank]:
///    - `FirebaseAuth.createUserWithEmailAndPassword`
///    - Callable **createPendingProfile** (`role: hospital`, location, coords) → `pending_profiles/{uid}`
///    - `User.sendEmailVerification()` (inbox verification email from Firebase).
/// 3. **UI** shows success/info, then **[AuthService.logout]** and pops — user completes
///    **email verification** later (tap link in inbox), then logs in.
/// 4. On login, [AuthService.completeProfileAfterVerification] triggers the callable and moves
///    `pending_profiles/{uid}` → `users/{uid}` when **`emailVerified`** is true (hospital
///    rule: email only — no SMS).
///
/// -----------------------------------------------------------------------------
/// ## Donor flow (dual verification — email inbox + SMS)
/// ### Phase A — Registration form (`_donorSmsStep == false`)
/// 1. **Form** full name, Jordan mobile, email, password, confirm password, gender,
///    governorate (from `_RegisterChoicesPanel`).
/// 2. A **donor notice** explains that activation needs **both** inbox and SMS afterward.
/// 3. **Create account** → [RegisterController.submitRegistration] → [AuthService.signUpDonor]:
///    - `createUserWithEmailAndPassword` (user stays **signed in** — no logout yet).
///    - Callable **createPendingProfile** (`role: donor`, fullName, gender, location, phone…)
///    - `sendEmailVerification()` → user receives Firebase **verification email**.
///
/// ### Phase B — Verification UI (`_donorSmsStep == true`)
/// Presented immediately after Phase A succeeds. Parallel UX: inbox + SMS happen together.
///
/// **Step 1 — Email (inbox)**
/// - User opens mail app, taps **verification link** in Firebase’s email → Firebase sets
///   `emailVerified` on the account.
/// - **Continue after verifying** taps through to
///   [AuthService.completeDonorOnboardingWhenReady] (via **`_tryFinalizeDonorOnboardingPipeline`**).
///
/// **Step 2 — Phone (SMS)**
/// - `_startDonorParallelPhoneVerification` calls
///   [PhoneAuthService.sendSmsOtpToLinkCurrentUser] (never a separate phone sign-in).
/// - Android may **auto-retrieve** the SMS → **`linkWithCredential`**.
/// - Otherwise OTP → [PhoneAuthService.verifyOtpAndLink].
///
/// ### Phase C — Activate profile and enter app
/// - **[AuthService.completeDonorOnboardingWhenReady]**: reload, require
///   `emailVerified` + **`providerId == phone`**, then **completeProfileAfterVerification**
///   callable.
/// - [RegisterScreen] then syncs FCM and opens [DonorDashboardScreen].
///
/// **Ordering:** Inbox vs SMS completion order does not matter; activation runs once both hold.
///
/// -----------------------------------------------------------------------------
/// ## Related
/// - [PhoneAuthService]: OTP **link** helpers only (no standalone phone account).
///
/// See also Cloud Function **completeProfileAfterVerification** in `functions/src/auth.js`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const double _fieldGap = 14;
  static const double _blockGap = 22;

  final RegisterController _registerController = RegisterController();
  final AuthService _authService = AuthService();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  UserType _type = UserType.donor;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsOtpController = TextEditingController();

  DonorGenderSelection? _donorGender;

  String? get _genderForApi {
    if (_donorGender == DonorGenderSelection.male) return 'male';
    if (_donorGender == DonorGenderSelection.female) return 'female';
    return null;
  }

  String? _selectedLocation;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  LatLng? _pickedLatLng;
  String? _pickedAddressLabel;

  bool _donorSmsStep = false;
  bool _smsOtpSent = false;
  bool _smsSending = false;
  bool _finalizeDonorBusy = false;
  String? _donorSignupMessage;

  /// Live validation under donor phone digits-only field.
  String? _donorPhoneError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_syncDonorPhoneDecorationError);
  }

  /// Updates error text shown under donor mobile when input is incomplete or blocked.
  void _syncDonorPhoneDecorationError() {
    if (!mounted || _donorSmsStep) return;
    if (_type != UserType.donor) {
      if (_donorPhoneError != null) setState(() => _donorPhoneError = null);
      return;
    }
    final err = JordanPhone.liveDigitsOnlyError(_phoneController.text);
    if (err != _donorPhoneError) setState(() => _donorPhoneError = err);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_syncDonorPhoneDecorationError);
    _nameController.dispose();
    _hospitalNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _smsOtpController.dispose();
    super.dispose();
  }

  Future<void> _startDonorParallelPhoneVerification() async {
    if (!_donorSmsStep || !mounted || _smsSending || _finalizeDonorBusy) return;
    final raw = _phoneController.text.trim();
    final phoneNorm = JordanPhone.normalize(raw);
    if (phoneNorm == null) {
      if (mounted) {
        setState(() {
          _donorPhoneError =
              JordanPhone.validationMessage(raw) ?? 'Invalid mobile number.';
        });
      }
      return;
    }

    setState(() {
      _smsSending = true;
    });

    try {
      await _phoneAuthService.sendSmsOtpToLinkCurrentUser(
        phoneNumber: phoneNorm,
        onCodeSent: () {
          if (!mounted) return;
          setState(() {
            _smsOtpSent = true;
            _smsSending = false;
          });
        },
        onAutoLinked: (_) async {
          if (!mounted) return;
          setState(() {
            _smsSending = false;
            _smsOtpSent = true;
            _finalizeDonorBusy = true;
          });
          await _tryFinalizeDonorOnboardingPipeline();
        },
        onVerificationFailed: (FirebaseAuthException exception) {
          if (!mounted) return;
          setState(() => _smsSending = false);
          final throttled = firebaseAuthIndicatesDeviceThrottle(exception);
          DialogHelper.showError(
            context: context,
            title: throttled
                ? 'Too many verification attempts'
                : 'SMS verification failed',
            message: throttled
                ? firebaseAuthDeviceThrottleUserMessage()
                : (exception.message ??
                      'Could not send the SMS verification code.'),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _smsSending = false);
      final throttled = firebaseAuthIndicatesDeviceThrottle(e);
      DialogHelper.showError(
        context: context,
        title: throttled
            ? 'Too many verification attempts'
            : 'SMS verification failed',
        message: throttled
            ? firebaseAuthDeviceThrottleUserMessage()
            : (e.message ?? 'Could not start phone verification.'),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _smsSending = false);
      DialogHelper.showError(
        context: context,
        title: 'SMS verification failed',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> _verifyDonorSignupSmsCode() async {
    if (_finalizeDonorBusy || _smsSending) return;
    final code = _smsOtpController.text;
    final otpErr = _registerController.validationErrorForSmsOtp(code);
    if (otpErr != null) {
      DialogHelper.showWarning(
        context: context,
        title: 'Missing code',
        message: otpErr,
      );
      return;
    }

    setState(() => _finalizeDonorBusy = true);
    try {
      await _phoneAuthService.verifyOtpAndLink(smsCode: code.trim());
      if (!mounted) return;
      await _tryFinalizeDonorOnboardingPipeline();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _finalizeDonorBusy = false);
      final throttled = firebaseAuthIndicatesDeviceThrottle(e);
      final msg = throttled
          ? firebaseAuthDeviceThrottleUserMessage()
          : (e.code == 'credential-already-in-use'
                ? 'This phone number is already linked to another account.'
                : (e.message ?? 'Please check the code and try again.'));
      DialogHelper.showError(
        context: context,
        title: throttled
            ? 'Too many verification attempts'
            : (e.code == 'credential-already-in-use'
                  ? 'Phone already in use'
                  : 'Invalid verification code'),
        message: msg,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _finalizeDonorBusy = false);
      DialogHelper.showError(
        context: context,
        title: 'Verification failed',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Single donor completion path: [AuthService.completeDonorOnboardingWhenReady],
  /// then FCM and dashboard. Handles [DonorOnboardingIncomplete] with inline info.
  Future<void> _tryFinalizeDonorOnboardingPipeline() async {
    if (!mounted) return;
    try {
      await _authService.completeDonorOnboardingWhenReady();
    } on DonorOnboardingIncomplete catch (e) {
      if (!mounted) return;
      setState(() => _finalizeDonorBusy = false);
      await DialogHelper.showInfo(
        context: context,
        title: e.dialogTitle,
        message: e.message,
      );
      return;
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _finalizeDonorBusy = false);
      DialogHelper.showWarning(
        context: context,
        title: 'Session issue',
        message: e.message,
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _finalizeDonorBusy = false);
      DialogHelper.showError(
        context: context,
        title: 'Could not activate profile',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }

    try {
      await FCMService.instance.ensureTokenSynced(
        attempts: 5,
        delay: const Duration(seconds: 1),
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _tryContinueAfterEmailLinkOnly() async {
    if (_finalizeDonorBusy || _smsSending) return;

    if (_authService.currentUser == null) {
      DialogHelper.showWarning(
        context: context,
        title: 'Session expired',
        message: 'Please sign up again or log in.',
      );
      return;
    }

    setState(() => _finalizeDonorBusy = true);
    await _tryFinalizeDonorOnboardingPipeline();
  }

  Future<void> _openMapPicker() async {
    if (_isLoading) return;
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) =>
            MapLocationPickerScreen(initialGovernorate: _selectedLocation),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickedLatLng = result.coordinates;
      _pickedAddressLabel = result.displayAddress;
      final match = AppTheme.governorateCoordinates.keys.firstWhere(
        (g) => result.displayAddress.contains(g),
        orElse: () => '',
      );
      if (match.isNotEmpty) _selectedLocation = match;
    });
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await _registerController.submitRegistration(
        userType: _type,
        email: _emailController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        donorFullName: _type == UserType.donor ? _nameController.text : null,
        donorGender: _type == UserType.donor ? _genderForApi : null,
        donorPhoneRaw: _type == UserType.donor ? _phoneController.text : null,
        bloodBankName: _type == UserType.bloodBank
            ? _hospitalNameController.text
            : null,
        locationGovernorateLabel: _selectedLocation,
        bloodBankHasMapPin: _pickedLatLng != null,
        exactLatitude: _type == UserType.bloodBank
            ? _pickedLatLng?.latitude
            : null,
        exactLongitude: _type == UserType.bloodBank
            ? _pickedLatLng?.longitude
            : null,
      );

      if (!mounted) return;

      if (!result.success) {
        final missing = result.errorTitle == 'Missing information';
        if (missing) {
          DialogHelper.showWarning(
            context: context,
            title: result.errorTitle ?? 'Missing information',
            message: result.errorMessage ?? '',
          );
        } else {
          DialogHelper.showError(
            context: context,
            title: result.errorTitle ?? 'Sign up failed',
            message: result.errorMessage ?? 'Something went wrong.',
          );
        }
        return;
      }

      if (_type == UserType.donor) {
        setState(() {
          _isLoading = false;
          _donorSmsStep = true;
          _smsOtpSent = false;
          _donorSignupMessage =
              result.message ??
              'We emailed you a verification link. We are also sending an SMS code to your phone.';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startDonorParallelPhoneVerification();
        });
        return;
      }

      if (result.emailVerified) {
        await DialogHelper.showSuccess(
          context: context,
          title: 'Account created',
          message: result.message ?? '',
        );
      } else {
        await DialogHelper.showInfo(
          context: context,
          title: 'Verification email sent',
          message: result.message ?? '',
        );
      }
      if (!mounted) return;
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      DialogHelper.showError(
        context: context,
        title: 'Error',
        message: 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: LoginFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _donorSmsStep ? 'Verify your details' : 'Create account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _donorSmsStep
                        ? 'Use Step 1 and Step 2 below. You need both finished before activation.'
                        : 'Enter your details, then choose your role and location below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (!_donorSmsStep) ...[
                    if (_type == UserType.donor) ...[
                      const _DonorRegisterFlowCallout(),
                      const SizedBox(height: 16),
                    ],
                    if (_type == UserType.donor) ...[
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: AppTheme.outlinedInputDecoration(
                          label: 'Full name',
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: _fieldGap),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                          const JordanMobileLocalTenDigitClampFormatter(),
                          const JordanMobilePrefixFormatter(),
                        ],
                        decoration: AppTheme.outlinedInputDecoration(
                          label: 'Jordan mobile (079 · 078 · 077)',
                          icon: Icons.phone_android_outlined,
                        ).copyWith(errorText: _donorPhoneError),
                      ),
                      const SizedBox(height: _fieldGap),
                    ],
                    if (_type == UserType.bloodBank) ...[
                      TextField(
                        controller: _hospitalNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: AppTheme.outlinedInputDecoration(
                          label: 'Blood bank name',
                          icon: Icons.local_hospital_outlined,
                        ),
                      ),
                      const SizedBox(height: _fieldGap),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: AppTheme.outlinedInputDecoration(
                        label: 'Email',
                        icon: Icons.mail_outline,
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                    PasswordField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      useOutlinedInput: true,
                      onToggleVisibility: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: _fieldGap),
                    ConfirmPasswordField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      useOutlinedInput: true,
                      onToggleVisibility: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                    const SizedBox(height: _blockGap),
                    _RegisterChoicesPanel(
                      userType: _type,
                      onUserTypeChanged: (isDonor) {
                        final nextType = isDonor
                            ? UserType.donor
                            : UserType.bloodBank;
                        if (nextType == _type) return;
                        setState(() {
                          _type = nextType;
                          if (nextType != UserType.donor) {
                            _donorPhoneError = null;
                          }
                        });
                        _syncDonorPhoneDecorationError();
                      },
                      donorGender: _donorGender,
                      onDonorGenderChanged: (g) {
                        if (_donorGender == g) return;
                        setState(() => _donorGender = g);
                      },
                      selectedLocation: _selectedLocation,
                      onLocationChanged: (v) {
                        if (_selectedLocation == v) return;
                        setState(() => _selectedLocation = v);
                      },
                      bloodBankAddressLabel: _pickedAddressLabel,
                      onBloodBankMapTap: _openMapPicker,
                    ),
                  ] else ...[
                    _DonorDualVerificationPhase(
                      signupMessage: _donorSignupMessage,
                      smsOtpSent: _smsOtpSent,
                      smsSending: _smsSending,
                      finalizeBusy: _finalizeDonorBusy,
                      isLoading: _isLoading,
                      otpController: _smsOtpController,
                      onContinueAfterEmail: _tryContinueAfterEmailLinkOnly,
                    ),
                  ],
                  const SizedBox(height: _blockGap),
                  if (!_donorSmsStep)
                    PrimaryButton(
                      text: 'Create account',
                      onPressed: _handleSubmit,
                      isLoading: _isLoading,
                    )
                  else
                    PrimaryButton(
                      text: !_smsOtpSent
                          ? (_smsSending
                                ? 'Sending SMS verification…'
                                : 'Send SMS verification')
                          : 'Verify SMS code',
                      onPressed: () async {
                        if (!_smsOtpSent) {
                          await _startDonorParallelPhoneVerification();
                        } else {
                          await _verifyDonorSignupSmsCode();
                        }
                      },
                      isLoading:
                          _finalizeDonorBusy ||
                          _isLoading ||
                          (_smsSending && !_smsOtpSent),
                    ),
                  const SizedBox(height: _fieldGap),
                  if (_donorSmsStep && _smsOtpSent)
                    LinkButton(
                      text: 'Resend SMS code',
                      onPressed:
                          (_smsSending || _finalizeDonorBusy || _isLoading)
                          ? null
                          : () => _startDonorParallelPhoneVerification(),
                    ),
                  if (!_donorSmsStep)
                    LoginLink(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonorRegisterFlowCallout extends StatelessWidget {
  const _DonorRegisterFlowCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.deepRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.deepRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.deepRed.withValues(alpha: 0.9),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'As a donor, after you tap Create account we activate you only '
              'when both steps finish: verifying your inbox link and the SMS '
              'code.',
              style: TextStyle(
                fontSize: 12.8,
                height: 1.4,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorDualVerificationPhase extends StatelessWidget {
  const _DonorDualVerificationPhase({
    required this.signupMessage,
    required this.smsOtpSent,
    required this.smsSending,
    required this.finalizeBusy,
    required this.isLoading,
    required this.otpController,
    required this.onContinueAfterEmail,
  });

  final String? signupMessage;
  final bool smsOtpSent;
  final bool smsSending;
  final bool finalizeBusy;
  final bool isLoading;
  final TextEditingController otpController;
  final VoidCallback onContinueAfterEmail;

  @override
  Widget build(BuildContext context) {
    final busy = smsSending || finalizeBusy || isLoading;

    Widget smsStatusChild;
    if (smsSending && !smsOtpSent) {
      smsStatusChild = Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.deepRed.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sending your SMS verification…',
              style: TextStyle(fontSize: 12.8, color: Colors.grey[700]),
            ),
          ),
        ],
      );
    } else if (!smsOtpSent) {
      smsStatusChild = Text(
        'Waiting for SMS. Tap Send SMS verification if nothing arrived.',
        style: TextStyle(fontSize: 12.8, color: Colors.grey[700], height: 1.35),
      );
    } else {
      smsStatusChild = Text(
        'Enter the code from the text message.',
        style: TextStyle(fontSize: 12.8, color: Colors.grey[700], height: 1.35),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Complete both steps',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Email and SMS are both required before you can use the app.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: Colors.grey[600],
          ),
        ),
        if (signupMessage != null && signupMessage!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            signupMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.35,
              fontSize: 12.8,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _VerificationStepCard(
          stepIndex: 1,
          icon: Icons.mark_email_read_outlined,
          title: 'Verify your email',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Open the message we sent and tap the verification link.',
                style: TextStyle(
                  fontSize: 12.8,
                  color: Colors.grey[700],
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              LinkButton(
                text: 'I opened the link — check and continue',
                onPressed: busy ? null : onContinueAfterEmail,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 2,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.deepRed.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _VerificationStepCard(
          stepIndex: 2,
          icon: Icons.sms_outlined,
          title: 'Verify your phone (SMS)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              smsStatusChild,
              if (smsOtpSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: otpController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: AppTheme.outlinedInputDecoration(
                    label: 'SMS code',
                    icon: Icons.lock_outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VerificationStepCard extends StatelessWidget {
  const _VerificationStepCard({
    required this.stepIndex,
    required this.icon,
    required this.title,
    required this.child,
  });

  final int stepIndex;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.deepRed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepIndex',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.deepRed,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.deepRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterFormStyles {
  _RegisterFormStyles._();

  static TextStyle get sectionLabel => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Colors.grey[700],
    letterSpacing: 0.2,
  );
}

/// Role, gender (donors), and location at the bottom of the form.
class _RegisterChoicesPanel extends StatelessWidget {
  final UserType userType;
  final ValueChanged<bool> onUserTypeChanged;
  final DonorGenderSelection? donorGender;
  final ValueChanged<DonorGenderSelection?> onDonorGenderChanged;
  final String? selectedLocation;
  final ValueChanged<String?> onLocationChanged;
  final String? bloodBankAddressLabel;
  final VoidCallback onBloodBankMapTap;

  const _RegisterChoicesPanel({
    required this.userType,
    required this.onUserTypeChanged,
    required this.donorGender,
    required this.onDonorGenderChanged,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.bloodBankAddressLabel,
    required this.onBloodBankMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDonor = userType == UserType.donor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('I am signing up as', style: _RegisterFormStyles.sectionLabel),
          const SizedBox(height: 8),
          UserTypeToggle(
            isDonor: userType == UserType.donor,
            onChanged: onUserTypeChanged,
          ),
          if (isDonor) ...[
            const SizedBox(height: 18),
            Text('Gender', style: _RegisterFormStyles.sectionLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _GenderPill(
                    label: 'Male',
                    selected: donorGender == DonorGenderSelection.male,
                    onTap: () =>
                        onDonorGenderChanged(DonorGenderSelection.male),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GenderPill(
                    label: 'Female',
                    selected: donorGender == DonorGenderSelection.female,
                    onTap: () =>
                        onDonorGenderChanged(DonorGenderSelection.female),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Governorate', style: _RegisterFormStyles.sectionLabel),
            const SizedBox(height: 8),
            LocationDropdown(
              selectedLocation: selectedLocation,
              useOutlinedInput: true,
              onChanged: onLocationChanged,
            ),
          ] else ...[
            const SizedBox(height: 18),
            Text('Pin on map', style: _RegisterFormStyles.sectionLabel),
            const SizedBox(height: 8),
            _BloodBankLocationButton(
              addressLabel: bloodBankAddressLabel,
              onTap: onBloodBankMapTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.deepRed : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.deepRed : const Color(0xFFD5DCE8),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _BloodBankLocationButton extends StatelessWidget {
  final String? addressLabel;
  final VoidCallback onTap;

  const _BloodBankLocationButton({
    required this.addressLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPick = addressLabel != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: hasPick ? const Color(0xFFFFF5F5) : AppTheme.fieldFill,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            border: Border.all(
              color: hasPick ? AppTheme.deepRed : const Color(0xffd0d4f0),
              width: hasPick ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasPick ? Icons.location_on : Icons.add_location_alt_outlined,
                color: hasPick ? AppTheme.deepRed : Colors.grey[600],
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasPick ? addressLabel! : 'Open map to drop a pin',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasPick ? AppTheme.deepRed : Colors.grey[700],
                    fontWeight: hasPick ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              Icon(
                Icons.map_outlined,
                color: AppTheme.deepRed.withValues(alpha: 0.75),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
