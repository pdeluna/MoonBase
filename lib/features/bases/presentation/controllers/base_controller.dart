import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/base.dart';
import '../providers/base_providers.dart';
import '../../domain/usecases/list_bases.dart';
import '../../domain/usecases/create_base.dart';
import '../../domain/usecases/join_base.dart';


class BaseState {
  final AsyncValue<List<Base>> bases;
  const BaseState({this.bases = const AsyncValue.data(const [])});

  BaseState copyWith({AsyncValue<List<Base>>? bases}) => BaseState(bases: bases ?? this.bases);
}

class BaseController extends StateNotifier<BaseState> {
  final ListBases _listBases;
  final CreateBase _createBase;
  final JoinBase _joinBase;

  BaseController(this._listBases, this._createBase, this._joinBase) : super(const BaseState());

  Future<void> load(String userId) async {
    state = state.copyWith(bases: const AsyncValue.loading());
    final res = await _listBases(ListBasesParams(userId));
    state = res.match(
      (f) => state.copyWith(bases: AsyncValue.error(f, StackTrace.current)),
      (list) => state.copyWith(bases: AsyncValue.data(list)),
    );
  }

  Future<void> create(String name, String ownerUserId) async {
    final res = await _createBase(CreateBaseParams(name: name, ownerUserId: ownerUserId));
    res.match(
      (_) => state = state, // no-op on failure; UI reads error if you bubble it
      (_) => load(ownerUserId),
    );
  }

  Future<void> join(String inviteCode, String userId) async {
    final res = await _joinBase(JoinBaseParams(inviteCode: inviteCode, userId: userId));
    res.match(
      (_) => state = state,
      (_) => load(userId),
    );
  }
}

final baseControllerProvider = StateNotifierProvider<BaseController, BaseState>((ref) {
  return BaseController(
    ref.read(listBasesUseCaseProvider),
    ref.read(createBaseUseCaseProvider),
    ref.read(joinBaseUseCaseProvider),
  );
});
