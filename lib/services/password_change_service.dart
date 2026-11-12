import 'package:firebase_auth/firebase_auth.dart';

class PasswordChangeService {
  PasswordChangeService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final email = user.email;
    if (email == null ||
        !user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      throw FirebaseAuthException(code: 'password-provider-required');
    }
    if (currentPassword.isEmpty) {
      throw FirebaseAuthException(code: 'missing-password');
    }
    if (newPassword.length < 8 || newPassword.length > 128) {
      throw FirebaseAuthException(code: 'weak-password');
    }
    if (newPassword == currentPassword) {
      throw FirebaseAuthException(code: 'password-unchanged');
    }
    // Do not trim passwords or sign in as a different user to authenticate.
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    if (_auth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user.updatePassword(newPassword);
  }
}

String passwordChangeErrorText(
  FirebaseAuthException error,
) => switch (error.code) {
  'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
    'Mật khẩu hiện tại không đúng. Vui lòng nhập lại.',
  'missing-password' => 'Vui lòng nhập mật khẩu hiện tại.',
  'weak-password' || 'password-does-not-meet-requirements' =>
    'Mật khẩu mới chưa đáp ứng yêu cầu bảo mật. Hãy chọn mật khẩu mạnh hơn, từ 8–128 ký tự.',
  'password-unchanged' => 'Mật khẩu mới phải khác mật khẩu hiện tại.',
  'password-provider-required' || 'operation-not-allowed' =>
    'Chức năng này dành cho tài khoản đăng nhập bằng email và mật khẩu.',
  'requires-recent-login' ||
  'user-token-expired' ||
  'invalid-user-token' ||
  'user-mismatch' ||
  'user-not-found' =>
    'Phiên đăng nhập đã thay đổi hoặc hết hạn. Vui lòng đăng nhập lại.',
  'user-disabled' =>
    'Tài khoản đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.',
  'too-many-requests' => 'Bạn đã thử quá nhiều lần. Vui lòng đợi rồi thử lại.',
  'network-request-failed' =>
    'Kết nối bị gián đoạn. Hãy kiểm tra đăng nhập bằng mật khẩu mới trước khi thử đổi lại.',
  _ => 'Không thể đổi mật khẩu lúc này. Vui lòng thử lại.',
};
