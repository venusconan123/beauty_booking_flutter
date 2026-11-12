import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/models/staff_access.dart';
import 'package:men_hair_booking/screens/staff_portal_screen.dart';

Future<void> openForm(
  WidgetTester tester,
  Future<void> Function(String, String) change,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StaffWorkspace(
        access: const StaffAccess(
          employeeId: 'employee-a',
          salonId: 'salon_01',
          name: 'Nhân viên A',
          active: true,
        ),
        email: 'staff@example.test',
        onSignOut: () {},
        onChangePassword: change,
        bookings: const SizedBox(),
      ),
    ),
  );
  await tester.tap(find.text('Tài khoản'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Đổi mật khẩu'));
  await tester.tap(find.text('Đổi mật khẩu'));
  await tester.pumpAndSettle();
}

Future<void> fillForm(
  WidgetTester tester,
  String current,
  String next,
  String confirmation,
) async {
  await tester.enterText(find.byKey(const ValueKey('password-0')), current);
  await tester.enterText(find.byKey(const ValueKey('password-1')), next);
  await tester.enterText(
    find.byKey(const ValueKey('password-2')),
    confirmation,
  );
  await tester.ensureVisible(find.text('Lưu mật khẩu mới'));
}

void main() {
  testWidgets(
    'phone form masks all passwords and reveals each field independently',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openForm(tester, (_, _) async {});
      expect(find.byType(TextField), findsNWidgets(3));
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.obscureText),
        isTrue,
      );
      await tester.ensureVisible(find.byTooltip('Hiện Mật khẩu hiện tại'));
      await tester.tap(find.byTooltip('Hiện Mật khẩu hiện tại'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].obscureText, isFalse);
      expect(fields[1].obscureText, isTrue);
      expect(fields[2].obscureText, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'staff account opens password form; confirmation and length errors do not submit',
    (tester) async {
      var calls = 0;
      await openForm(tester, (_, _) async => calls++);
      expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
      await fillForm(tester, 'old-pass-123', 'short', 'different');
      await tester.tap(find.text('Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu mới phải từ 8–128 ký tự.'), findsOneWidget);
      expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
      expect(calls, 0);
      await fillForm(tester, 'old-pass-123', 'old-pass-123', 'old-pass-123');
      await tester.tap(find.text('Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(
        find.text('Mật khẩu mới phải khác mật khẩu hiện tại.'),
        findsOneWidget,
      );
      expect(calls, 0);
    },
  );

  testWidgets(
    'successful change submits once, blocks repeated taps and returns to the staff account',
    (tester) async {
      final pending = Completer<void>();
      final calls = <List<String>>[];
      await openForm(tester, (old, next) {
        calls.add([old, next]);
        return pending.future;
      });
      await fillForm(tester, 'old-pass-123', 'new-pass-456', 'new-pass-456');
      await tester.tap(find.text('Lưu mật khẩu mới'));
      await tester.pump();
      expect(find.text('Đang đổi mật khẩu...'), findsOneWidget);
      await tester.tap(find.text('Đang đổi mật khẩu...'));
      await tester.pump();
      expect(calls, [
        ['old-pass-123', 'new-pass-456'],
      ]);
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Đã đổi mật khẩu. Dùng mật khẩu mới cho lần đăng nhập sau.'),
        findsOneWidget,
      );
      expect(find.text('staff@example.test'), findsOneWidget);
      expect(find.text('Mật khẩu hiện tại'), findsNothing);
    },
  );

  testWidgets(
    'wrong password stays on the form and permits a corrected retry without leaking error detail',
    (tester) async {
      var calls = 0;
      await openForm(tester, (_, _) async {
        calls++;
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'raw-sensitive-error',
        );
      });
      await fillForm(tester, 'wrong-pass', 'new-pass-456', 'new-pass-456');
      await tester.tap(find.text('Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(
        find.text('Mật khẩu hiện tại không đúng. Vui lòng nhập lại.'),
        findsOneWidget,
      );
      expect(find.textContaining('raw-sensitive-error'), findsNothing);
      expect(calls, 1);
      await tester.ensureVisible(find.text('Lưu mật khẩu mới'));
      await tester.tap(find.text('Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
}
