import '../models/barber.dart';

const List<Barber> sampleBarbers = [
  // Chi nhánh 1
  Barber(
    id: 'barber_01',
    salonId: 'salon_01',
    name: 'Nguyễn Minh',
    experienceYears: 5,
    rating: 4.8,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_02',
    salonId: 'salon_01',
    name: 'Trần Hoàng',
    experienceYears: 3,
    rating: 4.6,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_03',
    salonId: 'salon_01',
    name: 'Lê Quốc',
    experienceYears: 7,
    rating: 4.9,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_04',
    salonId: 'salon_01',
    name: 'Phạm Tuấn',
    experienceYears: 4,
    rating: 4.7,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_05',
    salonId: 'salon_01',
    name: 'Võ Thành',
    experienceYears: 6,
    rating: 4.8,
    imageUrl: null,
  ),

  // Chi nhánh 2
  Barber(
    id: 'barber_06',
    salonId: 'salon_02',
    name: 'Đỗ Nam',
    experienceYears: 2,
    rating: 4.5,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_07',
    salonId: 'salon_02',
    name: 'Bùi Hưng',
    experienceYears: 5,
    rating: 4.7,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_08',
    salonId: 'salon_02',
    name: 'Ngô Anh',
    experienceYears: 8,
    rating: 4.9,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_09',
    salonId: 'salon_02',
    name: 'Hoàng Long',
    experienceYears: 3,
    rating: 4.6,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_10',
    salonId: 'salon_02',
    name: 'Đặng Khoa',
    experienceYears: 6,
    rating: 4.8,
    imageUrl: null,
  ),

  // Chi nhánh 3
  Barber(
    id: 'barber_11',
    salonId: 'salon_03',
    name: 'Trịnh Duy',
    experienceYears: 4,
    rating: 4.7,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_12',
    salonId: 'salon_03',
    name: 'Lý Phong',
    experienceYears: 7,
    rating: 4.9,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_13',
    salonId: 'salon_03',
    name: 'Mai Đức',
    experienceYears: 3,
    rating: 4.6,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_14',
    salonId: 'salon_03',
    name: 'Đinh Quân',
    experienceYears: 5,
    rating: 4.8,
    imageUrl: null,
  ),
  Barber(
    id: 'barber_15',
    salonId: 'salon_03',
    name: 'Vương Sơn',
    experienceYears: 2,
    rating: 4.5,
    imageUrl: null,
  ),
];

List<Barber> getBarbersBySalonId(String salonId) {
  return sampleBarbers
      .where((barber) => barber.salonId == salonId)
      .toList();
}