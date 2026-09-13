import '../models/hair_service.dart';
import '../models/salon.dart';

const HairService comboTenSteps = HairService(
  id: 'service_combo_10',
  name: 'Combo 10 bước',
  price: 150000,
  durationMinutes: 60,
  description: 'Combo chăm sóc tóc và thư giãn gồm 10 bước.',
);

const HairService hairCut = HairService(
  id: 'service_hair_cut',
  name: 'Cắt tóc nam',
  price: 80000,
  durationMinutes: 30,
  description: 'Tư vấn và cắt tóc theo kiểu phù hợp với khách hàng.',
);

const HairService hairWash = HairService(
  id: 'service_hair_wash',
  name: 'Gội đầu',
  price: 30000,
  durationMinutes: 20,
  description: 'Gội sạch tóc kết hợp massage thư giãn.',
);

const HairService hairStyling = HairService(
  id: 'service_styling',
  name: 'Tạo kiểu',
  price: 50000,
  durationMinutes: 30,
  description: 'Sấy và tạo kiểu tóc theo yêu cầu.',
);

const HairService hairPerm = HairService(
  id: 'service_perm',
  name: 'Uốn tóc',
  price: 250000,
  durationMinutes: 120,
  description: 'Uốn và tạo kiểu tóc nam.',
);

const HairService hairDye = HairService(
  id: 'service_dye',
  name: 'Nhuộm tóc',
  price: 300000,
  durationMinutes: 150,
  description: 'Tư vấn màu và nhuộm tóc theo yêu cầu.',
);

const HairService skinCare = HairService(
  id: 'service_skin_care',
  name: 'Chăm sóc da',
  price: 100000,
  durationMinutes: 45,
  description: 'Làm sạch và chăm sóc da mặt cơ bản.',
);

const List<HairService> commonServices = [
  comboTenSteps,
  hairCut,
  hairWash,
  hairStyling,
  hairPerm,
  hairDye,
  skinCare,
];

const List<Salon> sampleSalons = [
  Salon(
    id: 'salon_01',
    name: '30Shine 345 Nguyễn Văn Linh',
    address: '343–345 Nguyễn Văn Linh, Thanh Khê, Đà Nẵng',
    latitude: 16.059879,
    longitude: 108.210489,
    distance: 2.0,
    rating: 4.8,
    services: commonServices,
  ),
  Salon(
    id: 'salon_02',
    name: '30Shine 130 Xô Viết Nghệ Tĩnh',
    address: '130 Xô Viết Nghệ Tĩnh, Hòa Cường, Đà Nẵng',
    latitude: 16.032159,
    longitude: 108.216245,
    distance: 4.8,
    rating: 4.7,
    services: commonServices,
  ),
  Salon(
    id: 'salon_03',
    name: '30Shine Sơn Trà (mô phỏng)',
    address:
        '120 Ngô Quyền, Sơn Trà, Đà Nẵng '
        '(địa điểm mô phỏng)',
    latitude: 16.070200,
    longitude: 108.235000,
    distance: 3.5,
    rating: 4.6,
    services: commonServices,
  ),
];
