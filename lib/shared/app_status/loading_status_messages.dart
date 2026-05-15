/// Short status lines for spinner + text loading UI.
class LoadingStatusMessages {
  LoadingStatusMessages._();

  static const String loadingData = 'Loading data…';
  static const String loadingPendingApprovals = 'Loading pending approvals…';
  static const String loadingAdminIssues = 'Loading issues…';
  static const String fetchingReports = 'Fetching reports…';
  static const String signingIn = 'Signing in…';
  static const String lookingUpAccount = 'Looking up your account…';
  static const String syncingData = 'Syncing data…';
  static const String checkingConnection = 'Checking connection…';
  static const String noInternet = 'No internet connection available';
  static const String genericError = 'Something went wrong, please try again';
  static const String failedToLoad = 'Failed to load data';
  static const String submittingReport = 'Submitting report…';
  static const String failedSubmitReport =
      'Failed to submit report, please try again';
  static const String issueSubmittedBrief =
      'Your issue was sent. Thank you.';

  /// Uses [ErrorMessageHelper]-style copy to guess offline vs generic failures.
  static bool looksLikeConnectivityIssue(String message) {
    final l = message.toLowerCase();
    return l.contains('network') ||
        l.contains('internet') ||
        l.contains('connection') ||
        l.contains('timeout') ||
        l.contains('host lookup') ||
        l.contains('socket');
  }
}
