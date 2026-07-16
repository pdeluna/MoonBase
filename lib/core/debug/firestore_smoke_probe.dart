import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Result of a Firestore write-then-read connectivity probe.
class FirestoreSmokeProbeResult {
  const FirestoreSmokeProbeResult({
    required this.ok,
    required this.docPath,
    this.errorCode,
    this.message,
  });

  final bool ok;
  final String docPath;
  final String? errorCode;
  final String? message;

  @override
  String toString() {
    if (ok) return 'FirestoreSmokeProbeResult(ok, path=$docPath)';
    return 'FirestoreSmokeProbeResult(fail, code=$errorCode, message=$message)';
  }
}

/// Writes a MoonBase-shaped sample doc to `_smoke_tests/{runId}` then reads it back.
///
/// Debug / connectivity proof only — not part of the production data layer.
Future<FirestoreSmokeProbeResult> runFirestoreSmokeProbe() async {
  const collection = '_smoke_tests';

  if (Firebase.apps.isEmpty) {
    const result = FirestoreSmokeProbeResult(
      ok: false,
      docPath: '',
      errorCode: 'not-initialized',
      message: 'Firebase.initializeApp has not completed successfully',
    );
    debugPrint('❌ FIRESTORE SMOKE: $result');
    return result;
  }

  final runId = const Uuid().v4();
  final docPath = '$collection/$runId';
  final docRef = FirebaseFirestore.instance.collection(collection).doc(runId);

  try {
    await docRef.set({
      'kind': 'smoke',
      'probe': 'write-then-read',
      'sample': {
        'baseId': 'b_smoke',
        'userId': 'user_smoke',
        'content': 'Firestore connectivity smoke test',
        'syncStatus': 'synced',
      },
      'writtenAt': FieldValue.serverTimestamp(),
      'projectId': 'moonbase-aaff7',
      'platform': defaultTargetPlatform.name,
    });

    final snap = await docRef.get();
    if (!snap.exists) {
      final result = FirestoreSmokeProbeResult(
        ok: false,
        docPath: docPath,
        errorCode: 'not-found',
        message: 'Write succeeded but document was missing on read',
      );
      debugPrint('❌ FIRESTORE SMOKE: $result');
      return result;
    }

    final data = snap.data();
    final sample = data?['sample'];
    final sampleMap = sample is Map ? Map<String, dynamic>.from(sample) : null;
    final content = sampleMap?['content'];

    if (data?['kind'] != 'smoke' ||
        content != 'Firestore connectivity smoke test' ||
        data?['writtenAt'] == null) {
      final result = FirestoreSmokeProbeResult(
        ok: false,
        docPath: docPath,
        errorCode: 'mismatch',
        message: 'Read-back fields did not match expected smoke payload',
      );
      debugPrint('❌ FIRESTORE SMOKE: $result');
      return result;
    }

    final result = FirestoreSmokeProbeResult(ok: true, docPath: docPath);
    debugPrint('✅ FIRESTORE SMOKE: Wrote/read $docPath');
    return result;
  } on FirebaseException catch (e) {
    final result = FirestoreSmokeProbeResult(
      ok: false,
      docPath: docPath,
      errorCode: e.code,
      message: e.message,
    );
    debugPrint('❌ FIRESTORE SMOKE: $result');
    return result;
  } catch (e) {
    final result = FirestoreSmokeProbeResult(
      ok: false,
      docPath: docPath,
      errorCode: 'unknown',
      message: e.toString(),
    );
    debugPrint('❌ FIRESTORE SMOKE: $result');
    return result;
  }
}
