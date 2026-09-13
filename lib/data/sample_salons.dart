import '../models/salon.dart';

const List<Salon> sampleSalons = [
  Salon(
    id: 'salon_01',
    name: 'Barber Shop Trung Tâm',
    address: '12 Nguyễn Văn A, Trung tâm thành phố',
    distance: 1.2,
    rating: 4.8,
    services: [
      'Cắt tóc',
      'Gội đầu',
      'Tạo kiểu',
    ],
  ),
  Salon(
    id: 'salon_02',
    name: 'Gentleman Barber',
    address: '25 Trần Văn B, Trung tâm thành phố',
    distance: 2.5,
    rating: 4.6,
    services: [
      'Cắt tóc',
      'Uốn tóc',
      'Nhuộm tóc',
    ],
  ),
  Salon(
    id: 'salon_03',
    name: 'Men Style Salon',
    address: '48 Lê Văn C, Trung tâm thành phố',
    distance: 3.1,
    rating: 4.7,
    services: [
      'Cắt tóc',
      'Gội đầu',
      'Chăm sóc da',
    ],
  ),
];