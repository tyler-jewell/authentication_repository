// ignore_for_file: must_be_immutable
import 'package:authentication_repository/authentication_repository.dart';
import 'package:cache/cache.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'mock.dart';

const _mockFirebaseUserUid = 'mock-uid';
const _mockFirebaseUserEmail = 'mock-email';

mixin LegacyEquality {
  @override
  bool operator ==(dynamic other) => false;

  @override
  int get hashCode => 0;
}

class MockCacheClient extends Mock implements CacheClient {}

class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase_auth.User {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock
    with LegacyEquality
    implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockUserCredential extends Mock implements firebase_auth.UserCredential {}

class MockConfirmationResult extends Mock
    implements firebase_auth.ConfirmationResult {}

class FakeAuthCredential extends Fake implements firebase_auth.AuthCredential {}

class FakeAuthProvider extends Fake implements AuthProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseAuthMocks();

  TestWidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp();

  const email = 'test@gmail.com';
  const password = 't0ps3cret42';
  const phoneNumber = '+12178551977';
  const user = User(
    id: _mockFirebaseUserUid,
    email: _mockFirebaseUserEmail,
  );

  group('AuthenticationRepository', () {
    late CacheClient cache;
    late firebase_auth.FirebaseAuth firebaseAuth;
    late GoogleSignIn googleSignIn;
    late AuthenticationRepository authenticationRepository;

    setUpAll(() {
      registerFallbackValue(FakeAuthCredential());
      registerFallbackValue(FakeAuthProvider());
    });

    setUp(() {
      cache = MockCacheClient();
      firebaseAuth = MockFirebaseAuth();
      googleSignIn = MockGoogleSignIn();
      authenticationRepository = AuthenticationRepository(
        cache: cache,
        firebaseAuth: firebaseAuth,
        googleSignIn: googleSignIn,
      );
    });

    test('creates FirebaseAuth instance internally when not injected', () {
      expect(AuthenticationRepository.new, isNot(throwsException));
    });

    group('signInWithPhoneNumber', () {
      setUp(() {
        when(
          () => firebaseAuth.signInWithPhoneNumber(any()),
        ).thenAnswer((_) => Future.value(MockConfirmationResult()));
      });

      test('calls signInWithPhoneNumber', () async {
        await authenticationRepository.signInWithPhoneNumber(phoneNumber);
        verify(
          () => firebaseAuth.signInWithPhoneNumber(phoneNumber),
        ).called(1);
      });

      test('succeeds when createUserWithEmailAndPassword succeeds', () async {
        expect(
          authenticationRepository.signInWithPhoneNumber(phoneNumber),
          completes,
        );
      });

      test(
          'throws SignInWithPhoneNumberFailure '
          'when signInWithPhoneNumber throws', () async {
        when(
          () => firebaseAuth.signInWithPhoneNumber(any()),
        ).thenThrow(Exception());
        expect(
          authenticationRepository.signInWithPhoneNumber(phoneNumber),
          throwsA(isA<SignInWithPhoneNumberFailure>()),
        );
      });
    });

    group('signUpWithEmailAndPassword', () {
      setUp(() {
        when(
          () => firebaseAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls createUserWithEmailAndPassword', () async {
        await authenticationRepository.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
        verify(
          () => firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
      });

      test('succeeds when createUserWithEmailAndPassword succeeds', () async {
        expect(
          authenticationRepository.signUpWithEmailAndPassword(
            email: email,
            password: password,
          ),
          completes,
        );
      });

      test(
          'throws SignUpWithEmailAndPasswordFailure '
          'when createUserWithEmailAndPassword throws', () async {
        when(
          () => firebaseAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception());
        expect(
          authenticationRepository.signUpWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(isA<SignUpWithEmailAndPasswordFailure>()),
        );
      });
    });

    group('loginWithGoogle', () {
      const accessToken = 'access-token';
      const idToken = 'id-token';

      setUp(() {
        final googleSignInAuthentication = MockGoogleSignInAuthentication();
        final googleSignInAccount = MockGoogleSignInAccount();
        when(() => googleSignInAuthentication.accessToken)
            .thenReturn(accessToken);
        when(() => googleSignInAuthentication.idToken).thenReturn(idToken);
        when(() => googleSignInAccount.authentication)
            .thenAnswer((_) async => googleSignInAuthentication);
        when(() => googleSignIn.signIn())
            .thenAnswer((_) async => googleSignInAccount);
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) => Future.value(MockUserCredential()));
        when(() => firebaseAuth.signInWithPopup(any()))
            .thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls signIn authentication, and signInWithCredential', () async {
        await authenticationRepository.logInWithGoogle();
        verify(() => googleSignIn.signIn()).called(1);
        verify(() => firebaseAuth.signInWithCredential(any())).called(1);
      });

      test(
          'throws LogInWithGoogleFailure and calls signIn authentication, and '
          'signInWithPopup when authCredential is null and kIsWeb is true',
          () async {
        authenticationRepository.isWeb = true;
        await expectLater(
          () => authenticationRepository.logInWithGoogle(),
          throwsA(isA<LogInWithGoogleFailure>()),
        );
        verifyNever(() => googleSignIn.signIn());
        verify(() => firebaseAuth.signInWithPopup(any())).called(1);
      });

      test(
          'sucessfully calls signIn authentication, and '
          'signInWithPopup when authCredential is not null and kIsWeb is true',
          () async {
        final credential = MockUserCredential();
        when(() => firebaseAuth.signInWithPopup(any()))
            .thenAnswer((_) async => credential);
        when(() => credential.credential).thenReturn(FakeAuthCredential());
        authenticationRepository.isWeb = true;
        await expectLater(
          authenticationRepository.logInWithGoogle(),
          completes,
        );
        verifyNever(() => googleSignIn.signIn());
        verify(() => firebaseAuth.signInWithPopup(any())).called(1);
      });

      test('succeeds when signIn succeeds', () {
        expect(authenticationRepository.logInWithGoogle(), completes);
      });

      test('throws LogInWithGoogleFailure when exception occurs', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception());
        expect(
          authenticationRepository.logInWithGoogle(),
          throwsA(isA<LogInWithGoogleFailure>()),
        );
      });
    });

    group('logInWithEmailAndPassword', () {
      setUp(() {
        when(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => Future.value(MockUserCredential()));
      });

      test('calls signInWithEmailAndPassword', () async {
        await authenticationRepository.logInWithEmailAndPassword(
          email: email,
          password: password,
        );
        verify(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
      });

      test('succeeds when signInWithEmailAndPassword succeeds', () async {
        expect(
          authenticationRepository.logInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          completes,
        );
      });

      test(
          'throws LogInWithEmailAndPasswordFailure '
          'when signInWithEmailAndPassword throws', () async {
        when(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception());
        expect(
          authenticationRepository.logInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(isA<LogInWithEmailAndPasswordFailure>()),
        );
      });
    });

    group('logOut', () {
      test('calls signOut', () async {
        when(() => firebaseAuth.signOut()).thenAnswer((_) async {});
        when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
        await authenticationRepository.logOut();
        verify(() => firebaseAuth.signOut()).called(1);
        verify(() => googleSignIn.signOut()).called(1);
      });

      test('throws LogOutFailure when signOut throws', () async {
        when(() => firebaseAuth.signOut()).thenThrow(Exception());
        expect(
          authenticationRepository.logOut(),
          throwsA(isA<LogOutFailure>()),
        );
      });
    });

    group('user', () {
      test('emits User.empty when firebase user is null', () async {
        when(() => firebaseAuth.authStateChanges())
            .thenAnswer((_) => Stream.value(null));
        await expectLater(
          authenticationRepository.user,
          emitsInOrder(const <User>[User.empty]),
        );
      });

      test('emits User when firebase user is not null', () async {
        final firebaseUser = MockFirebaseUser();
        when(() => firebaseUser.uid).thenReturn(_mockFirebaseUserUid);
        when(() => firebaseUser.email).thenReturn(_mockFirebaseUserEmail);
        when(() => firebaseUser.photoURL).thenReturn(null);
        when(() => firebaseAuth.authStateChanges())
            .thenAnswer((_) => Stream.value(firebaseUser));
        await expectLater(
          authenticationRepository.user,
          emitsInOrder(const <User>[user]),
        );
        verify(
          () => cache.write(
            key: AuthenticationRepository.userCacheKey,
            value: user,
          ),
        ).called(1);
      });
    });

    group('currentUser', () {
      test('returns User.empty when cached user is null', () {
        when(
          () => cache.read(key: AuthenticationRepository.userCacheKey),
        ).thenReturn(null);
        expect(
          authenticationRepository.currentUser,
          equals(User.empty),
        );
      });

      test('returns User when cached user is not null', () async {
        when(
          () => cache.read(key: AuthenticationRepository.userCacheKey),
        ).thenReturn(user);
        expect(authenticationRepository.currentUser, equals(user));
      });
    });
  });
}
