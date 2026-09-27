import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

class SidebarVM {
  const SidebarVM({
    required this.bases,
    required this.selectedBase,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    this.error,
  });

  final List<Base> bases;
  final Base? selectedBase;
  final bool isLoading;
  final bool hasError;

  /// Plain user copy for [error] (from `userMessage`); null when no error.
  final String? errorMessage;

  /// The raw error (normally a `Failure`) so surfaces can branch on type —
  /// e.g. network vs. everything else — instead of parsing [errorMessage].
  final Object? error;

  bool get isEmpty => bases.isEmpty && !isLoading && !hasError;
  bool get hasBases => bases.isNotEmpty;
}
