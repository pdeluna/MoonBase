import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/list_bases.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';
import 'package:moonbase_skeleton/core/ids.dart';


class BaseState {
  const BaseState({this.bases = const AsyncValue.data([])});

  final AsyncValue<List<Base>> bases;

  BaseState copyWith({AsyncValue<List<Base>>? bases}) => BaseState(bases: bases ?? this.bases);
}

class BaseController extends StateNotifier<BaseState> {
  BaseController(this._listBases, this._createBase, this._joinBase) : super(const BaseState());

  final ListBases _listBases;
  final CreateBase _createBase;
  final JoinBase _joinBase;

  Future<void> load(String userId) async {
    state = state.copyWith(bases: const AsyncValue.loading());
    final res = await _listBases(ListBasesParams(userId.uid));
    state = res.match(
      (f) => state.copyWith(bases: AsyncValue.error(f, StackTrace.current)),
      (list) => state.copyWith(bases: AsyncValue.data(list)),
    );
  }

  Future<void> create(String name, String ownerUserId) async {
    final res = await _createBase(CreateBaseParams(name: name, ownerUserId: ownerUserId.uid));
    res.match(
      (_) => state = state, // no-op on failure; UI reads error if you bubble it
      (_) => load(ownerUserId),
    );
  }

  Future<void> join(String inviteCode, String userId) async {
    final res = await _joinBase(JoinBaseParams(inviteCode: inviteCode, userId: userId.uid));
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
