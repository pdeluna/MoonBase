// Smallest complete example of use-case test pattern
// Every other use-case test are variations of this test
// To test the use case alone we need something to hand it in place of a real repository
// In this case we use a MockBaseRepository
// We then mock the repository to return a specific result
// We then call the use case with the same parameters as the real use case
// We then check that the result is a Right with the expected Base
// We then check that the repository was called with the correct parameters
// We then check that the repository was not called with any other parameters
// We then check that the repository was not called more than once  

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_base.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import '../../../../test_utils/mocks_bases.dart';

void main() {
  // Reuns once, before any test in this file
  // Teaches mocktail how to build placeholder BaseId / UserId values so that 
  // 'any(named: ...)' works on non-nullable ID types
  setUpAll(registerBasesFallbacks);

  test('CreateBase calls repo.createBase and returns Right(Base)', () async {
    // --------------------ARRANGE
    // Build the fake collaborator, inject it into the thing for testing
    // Use case takes a BaseRepository, it can't tell and doesn't care that it is a mock
    final repo = MockBaseRepository();
    final usecase = CreateBase(repo);

    // Program the mock: when someone calls createBase with ANY name and ANY ownerUserId, hand back this Right(base)
    // 
    // Three things to internalise:
    // 1. any(named: 'name') is a MATCHER, not a value -> I don't care what was passed 
    //    Mocktail rule: moment you use a matcher for one arg, you must use a matcher for all args
    // 2. Looose matchers in 'when', exact values in 'verify'
    //    Using 'any' here means the stub can't accidentally pass the test by matching arguments
    // 3. thenAnswer -> Takes a callback that runs at call time and produces a fresh Future each call. Use it for
    //    anything async. The '_' parameter is the Invocation (record of what was called and with what)
    //    Here we ignore it; we can read arguments off it when a stub needs to vary its response by input
   
    when(() => repo.createBase(name: any(named: 'name'), ownerUserId: any(named: 'ownerUserId')))
      .thenAnswer((_) async => Right(Base(id: 'b1'.bid, name: 'Home', ownerUserId: 'u1'.uid, createdAt: DateTime(2025, 1, 1))));
    // think of 'when' as a recording session
    // repo.createBase(...) executes no method body. Dart packages the call into an Invocation, and hands it to noSuchMethod

    // -------------ACT
    // One line. If the "act" section grows past one call, the test is probably testing a workflow rather than a unit
    final res = await usecase(CreateBaseParams(name: 'Home', ownerUserId: 'u1'.uid));


    // --------------------ASSERT
    // Assert in two passes: first the VALUE returned, then the INTERACTIONS that produced it
    // 
    // Value, part 1: which side of the Either did we land on?
    expect(res, isA<Right<Failure, Base>>());

    // Value, part 2: Unwrap it. match() forces you to handle both sides.
    // fail() in the left branch -> if we got here, the test is wrong. It converts a wrong-branch result into a clear fail message
    // instead of a silently skipped assertion block
    res.match((_) => fail('expected Right'), (b) {
      expect(b.id, 'b1'.bid);
      expect(b.name, 'Home');
      expect(b.ownerUserId, 'u1'.uid);
    });
    
    // Interactions. This is the half that proves the use case actually delegated instead of inventing a base
    // Note concrete values, not any() 
    // Stub was loose so it could match, verify is strict so it can prove what was forwarded.
    //
    // .called(1) -> checks that the stub was called exactly once
    verify(() => repo.createBase(name: 'Home', ownerUserId: 'u1'.uid)).called(1);

    // verify() calls because because it means "no interactions BEYOND those verified"
    verifyNoMoreInteractions(repo);
  });
}
