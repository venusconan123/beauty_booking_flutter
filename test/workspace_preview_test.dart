import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/workspace/workspace_app.dart';
import 'package:men_hair_booking/workspace/workspace_store.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final role in WorkspaceRole.values) {
      testWidgets('preview $role at width $width opens and navigates', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = WorkspaceStore(restore: false)..switchRole(role);
        await tester.pumpWidget(WorkspaceApp(store: store));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (role == WorkspaceRole.customer) {
          await tester.tap(find.text('Vào không gian khách hàng'));
        } else {
          await tester.tap(find.text('Xem vai trò Admin / Nhân viên'));
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .text(
                  role == WorkspaceRole.admin
                      ? 'Quản trị viên'
                      : store.employeeName,
                )
                .last,
          );
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (role != WorkspaceRole.customer) {
          final label = role == WorkspaceRole.admin
              ? 'Bảng phân ca'
              : 'Lịch làm tháng';
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
