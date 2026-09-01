import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Debug-only Firebase network failure harness (Firestore + Storage).
///
/// How to run: see README.md § "Debug network harness" (physical Android only).
///
/// Modes (mutually exclusive; both require [kDebugMode] + `--dart-define`):
/// - `MOONBASE_FORCE_OFFLINE` — offline-with-cache via [FirebaseFirestore.disableNetwork]
///   (local persistence still serves reads; no outbound connection attempt).
/// - `MOONBASE_BLACKHOLE` — connect hang: Firestore [Settings.host] and Storage
///   [FirebaseStorage.useStorageEmulator] pointed at TEST-NET-1 `192.0.2.1:443`
///   (packets dropped, not refused — real hang, not a fast error).
///
/// This is a test fixture only — it does not inspect connectivity or gate product
/// logic. Bootstrap owns the single [Settings] assignment; this file only
/// returns a modified copy (host) and applies network side effects.

const bool _kForceOfflineDefine =
    bool.fromEnvironment('MOONBASE_FORCE_OFFLINE');
const bool _kBlackholeDefine = bool.fromEnvironment('MOONBASE_BLACKHOLE');

const String _kBlackholeHost = '192.0.2.1';
const int _kBlackholePort = 443;

/// Armed debug mode after [kDebugMode] + define gating (and mutual-exclusion).
/// Single source of truth for which harness path is active.
enum MoonbaseNetworkDebugMode {
  none,
  forceOffline,
  blackhole,
  conflict,
}

bool _conflictReported = false;

/// Effective mode for logging / on-device banner. Prefer this over raw defines.
MoonbaseNetworkDebugMode get moonbaseNetworkDebugMode {
  if (!kDebugMode) return MoonbaseNetworkDebugMode.none;
  if (_kForceOfflineDefine && _kBlackholeDefine) {
    return MoonbaseNetworkDebugMode.conflict;
  }
  if (_kForceOfflineDefine) return MoonbaseNetworkDebugMode.forceOffline;
  if (_kBlackholeDefine) return MoonbaseNetworkDebugMode.blackhole;
  return MoonbaseNetworkDebugMode.none;
}

/// Non-null when a debug mode (or invalid combo) is armed — for a visible banner.
String? get moonbaseNetworkDebugBannerLabel {
  switch (moonbaseNetworkDebugMode) {
    case MoonbaseNetworkDebugMode.none:
      return null;
    case MoonbaseNetworkDebugMode.forceOffline:
      return 'DEBUG: FORCE OFFLINE';
    case MoonbaseNetworkDebugMode.blackhole:
      return 'DEBUG: BLACKHOLE $_kBlackholeHost:$_kBlackholePort';
    case MoonbaseNetworkDebugMode.conflict:
      return 'DEBUG: INVALID FLAGS (offline+blackhole)';
  }
}

void _reportConflictOnce() {
  if (moonbaseNetworkDebugMode != MoonbaseNetworkDebugMode.conflict ||
      _conflictReported) {
    return;
  }
  _conflictReported = true;
  debugPrint(
    '❌ FIREBASE DEBUG HARNESS: MOONBASE_FORCE_OFFLINE and '
    'MOONBASE_BLACKHOLE are mutually exclusive — neither applied. '
    'Force-offline never connects, so a blackhole hang cannot occur. '
    'See README.md § "Debug network harness".',
  );
}

/// Returns [base] with blackhole host override when that mode is armed.
///
/// Does **not** assign to [FirebaseFirestore] — bootstrap must assign once.
Settings applyFirestoreDebugSettings(Settings base) {
  switch (moonbaseNetworkDebugMode) {
    case MoonbaseNetworkDebugMode.conflict:
      _reportConflictOnce();
      return base;
    case MoonbaseNetworkDebugMode.blackhole:
      debugPrint(
        '🕳️ FIREBASE DEBUG HARNESS: BLACKHOLE — Firestore host '
        '$_kBlackholeHost:$_kBlackholePort (TEST-NET-1 connect hang)',
      );
      return base.copyWith(
        host: '$_kBlackholeHost:$_kBlackholePort',
        sslEnabled: true,
      );
    case MoonbaseNetworkDebugMode.forceOffline:
    case MoonbaseNetworkDebugMode.none:
      return base;
  }
}

/// Applies Storage blackhole config and/or Firestore offline toggle.
///
/// Call after the single [FirebaseFirestore.settings] assignment.
///
/// [FirebaseStorage.useStorageEmulator] is **awaited** (with a short timeout):
/// it is configuration that must land before the first Storage reference is
/// used. [FirebaseFirestore.disableNetwork] stays **unawaited** — a late apply
/// is self-correcting and nothing succeeds against production in the gap.
Future<void> applyFirebaseDebugNetworkEffects() async {
  switch (moonbaseNetworkDebugMode) {
    case MoonbaseNetworkDebugMode.conflict:
      _reportConflictOnce();
      return;
    case MoonbaseNetworkDebugMode.blackhole:
      debugPrint(
        '🕳️ FIREBASE DEBUG HARNESS: BLACKHOLE — Storage useStorageEmulator '
        '$_kBlackholeHost:$_kBlackholePort (TEST-NET-1 connect hang)',
      );
      try {
        await FirebaseStorage.instance
            .useStorageEmulator(
              _kBlackholeHost,
              _kBlackholePort,
              automaticHostMapping: false,
            )
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
        debugPrint(
          '❌ FIREBASE DEBUG HARNESS: Storage blackhole DID NOT ARM — '
          'useStorageEmulator timed out after 3s. Storage may still talk '
          'to production; do not trust hang-repro results this run.',
        );
      } catch (e) {
        debugPrint(
          '❌ FIREBASE DEBUG HARNESS: Storage blackhole DID NOT ARM — '
          'useStorageEmulator failed: $e',
        );
      }
      return;
    case MoonbaseNetworkDebugMode.forceOffline:
      debugPrint(
        '📴 FIREBASE DEBUG HARNESS: FORCE OFFLINE — disableNetwork() '
        '(offline-with-cache; unawaited)',
      );
      unawaited(FirebaseFirestore.instance.disableNetwork());
      return;
    case MoonbaseNetworkDebugMode.none:
      return;
  }
}
