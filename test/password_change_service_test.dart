import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/services/password_change_service.dart';

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  @override
  User? get currentUser => user;
}

class _Provider extends Fake implements UserInfo {
  _Provider(this.providerId);
  @override
  final String providerId;
}

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  _User({this.uid = 'staff-test', this.provider = 'password'});
  @override
  final String uid;
  final String provider;
  final calls = <String>[];
  AuthCredential? credential;
  String? savedPassword;
  FirebaseAuthException? reauthError;
  void Function()? afterReauth;
  @override
  String get email => 'staff@example.test';
  @override
  List<UserInfo> get providerData => [_Provider(provider)];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential value,
  ) async {
    calls.add('reauthenticate');
    credential = value;
    if (reauthError != null) throw reauthError!;
    afterReauth?.call();
    return _Credential();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('update');
    savedPassword = newPassword;
  }
}

void main() {
  late _Auth auth;
  late _User user;
  late PasswordChangeService service;
  setUp(() {
    user = _User();
    auth = _Auth()..user = user;
    service = PasswordChangeService(auth: auth);
  });

  test(
    'reauthenticates the current account before updating; preserves exact passwords',
    () async {
      await service.changePassword(' old-pass ', ' new-password ');
      expect(user.calls, ['reauthenticate', 'update']);
      final credential = user.credential! as EmailAuthCredential;
      expect(credential.email, 'staff@example.test');
      expect(credential.password, ' old-pass ');
      expect(user.savedPassword, ' new-password ');
      expect(auth.currentUser?.uid, user.uid);
    },
  );

  test('incorrect current password never reaches updatePassword', () async {
    user.reauthError = FirebaseAuthException(code: 'invalid-credential');
    await expectLater(
      service.changePassword('wrong-pass', 'new-pass-123'),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(user.calls, ['reauthenticate']);
    expect(user.savedPassword, isNull);
    expect(auth.currentUser?.uid, 'staff-test');
  });

  test(
    'invalid and unchanged new passwords fail before authentication',
    () async {
      for (final next in ['short', 'x' * 129, 'current-pass']) {
        await expectLater(
          service.changePassword('current-pass', next),
          throwsA(isA<FirebaseAuthException>()),
        );
      }
      await expectLater(
        service.changePassword('', 'new-pass-123'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(user.calls, isEmpty);
    },
  );

  test(
    'signed-out and non-password accounts cannot update passwords',
    () async {
      auth.user = null;
      await expectLater(
        service.changePassword('current-pass', 'new-pass-123'),
        throwsA(isA<FirebaseAuthException>()),
      );
      final google = _User(provider: 'google.com');
      auth.user = google;
      await expectLater(
        service.changePassword('current-pass', 'new-pass-123'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(google.calls, isEmpty);
      expect(user.calls, isEmpty);
    },
  );

  test(
    'changing or signing out the account during reauthentication aborts the update',
    () async {
      for (final next in [null, _User(uid: 'another-account')]) {
        user.calls.clear();
        auth.user = user;
        user.afterReauth = () => auth.user = next;
        await expectLater(
          service.changePassword('current-pass', 'new-pass-123'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'user-mismatch',
            ),
          ),
        );
        expect(user.calls, ['reauthenticate']);
        expect(user.savedPassword, isNull);
      }
    },
  );

  test('errors use friendly text and never expose raw Firebase messages', () {
    final error = FirebaseAuthException(
      code: 'wrong-password',
      message: 'sensitive-upstream-detail',
    );
    expect(
      passwordChangeErrorText(error),
      contains('Mật khẩu hiện tại không đúng'),
    );
    expect(passwordChangeErrorText(error), isNot(contains(error.message!)));
    expect(
      passwordChangeErrorText(
        FirebaseAuthException(code: 'network-request-failed'),
      ),
      contains('kiểm tra đăng nhập bằng mật khẩu mới'),
    );
  });
}
