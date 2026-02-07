import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

class SidebarVM {
  const SidebarVM({
    required this.bases,
    required this.selectedBase,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
  });

  final List<Base> bases;
  final Base? selectedBase;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;

  bool get isEmpty => bases.isEmpty && !isLoading && !hasError;
  bool get hasBases => bases.isNotEmpty;
}
