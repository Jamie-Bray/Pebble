/// User-facing messages that double as machine-readable state markers.
///
/// Parts of the entitlement/backup flow persist plain error strings (in
/// `entitlementError` / `lastSyncError`) and later providers re-derive flow
/// state by substring-matching those strings. Until that moves to typed error
/// codes, every load-bearing phrase and every matcher lives in this one file,
/// so rewording a message updates the producer and the matcher together.
///
/// DO NOT reword these phrases anywhere else, and do not "polish" the copy in
/// this file without keeping the marker lists below in sync.
class EntitlementFlowMessages {
  const EntitlementFlowMessages._();

  /// Store purchase is verified locally but the Supabase mirror has not
  /// confirmed it yet. Produced by the RevenueCat purchase repository.
  static const awaitingServerVerification =
      'Premium is active locally. Pebble is waiting for secure purchase '
      'verification for this account.';

  /// The bounded post-purchase server mirror wait timed out.
  static const backupSetupFailed =
      'Premium is active, but backup could not be set up yet. Try again.';

  /// Same condition surfaced from the sync coordinator, pointing the user at
  /// the Account screen for the retry.
  static const backupSetupFailedFromAccount =
      'Premium is active, but backup could not be set up yet. '
      'Try again from Account.';

  static const _purchaseVerificationMarkers = [
    'backup could not be set up',
    'could not finish backup setup',
    'purchase verification',
  ];

  // These match LocalDataOwnershipGuard.userFacingMessage phrases.
  static const _accountSwitchMarkers = [
    'local data',
    'another account',
    'linked to this account',
    'without your choice',
  ];

  static const _unownedLocalDataMarker = 'not linked to this account';

  /// Premium is active but the server-side purchase mirror never confirmed.
  static bool looksPurchaseVerificationFailed(String? message) {
    return _containsAny(message, _purchaseVerificationMarkers);
  }

  /// Local data needs an explicit account-ownership choice before sync.
  static bool looksAccountSwitchBlocked(String? message) {
    return _containsAny(message, _accountSwitchMarkers);
  }

  /// The blocked local data has never belonged to any account (a lighter ask
  /// than data owned by a different account).
  static bool looksUnownedLocalData(String? message) {
    return _containsAny(message, const [_unownedLocalDataMarker]);
  }

  static bool _containsAny(String? message, List<String> markers) {
    if (message == null || message.isEmpty) {
      return false;
    }
    final normalized = message.toLowerCase();
    return markers.any(normalized.contains);
  }
}
