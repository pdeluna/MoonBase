/// Native Firebase Storage retry budgets. Applied once at app bootstrap on
/// `FirebaseStorage.instance`, next to the single Firestore Settings
/// assignment. Do not set these anywhere else.
///
/// Measured 2026-08-12 on device: tapping a received photo in blackhole mode
/// took ~95 seconds before StorageException code -13030 ("The operation retry
/// limit has been exceeded"). That is the SDK default maxOperationRetryTime
/// of 2 minutes burning down through ExponentialBackoffSender on
/// GetDownloadUrlTask. Ninety-five seconds is past the point any user still
/// believes the app is working.
///
/// Images are client-compressed to roughly a megabyte, so 60s upload is
/// generous headroom for a slow uplink. Reads should fail fast because we
/// have a cache to fall back on.
///
/// SDK defaults: 2 minutes (operations), 10 minutes (upload), 10 minutes
/// (download).
///
/// Ordered before `kFirebaseMediaResolveTimeout` (20s Dart-side await on
/// getDownloadURL) on purpose — they bound different things (native retry
/// budget vs Dart Future.timeout) and **must not be set equal**. This 15s
/// cap is the expected terminator; the Dart timeout is a backstop if the
/// native layer never returns. Either can legitimately be absent (unit tests
/// stub getDownloadURL and never apply these native caps).
const Duration kFirebaseStorageMaxOperationRetry = Duration(seconds: 15);
const Duration kFirebaseStorageMaxDownloadRetry = Duration(seconds: 30);
const Duration kFirebaseStorageMaxUploadRetry = Duration(seconds: 60);
