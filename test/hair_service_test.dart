import 'package:beauty_booking_app/models/hair_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HairService chuyển đổi dữ liệu Firestore đúng', () {
    final service = HairService.fromMap('service_cut', {
      'name': 'Cắt tóc nam',
      'price': 80000,
      'durationMinutes': 30,
      'description': 'Cắt và tạo kiểu',
    });

    expect(service.id, 'service_cut');
    expect(service.price, 80000);
    expect(service.durationMinutes, 30);
    expect(service.toMap()['name'], 'Cắt tóc nam');
  });
}
