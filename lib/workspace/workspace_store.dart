import 'dart:convert';

import '../data/sample_salons.dart';
import 'local_storage.dart';

enum WorkspaceRole { customer, staff, admin }

enum ReportPeriod { day, week, month, year }

typedef RowData = Map<String, dynamic>;
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String clockText(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String moneyText(num n) =>
    '${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
String shortDate(String day) =>
    '${day.substring(8)}/${day.substring(5, 7)}/${day.substring(0, 4)}';
const statusLabels = {
  'confirmed': 'Đã xác nhận',
  'in_service': 'Đang phục vụ',
  'completed': 'Đã hoàn thành',
  'cancelled': 'Đã hủy',
};
const shiftTemplates = <String, List<int>>{
  'S': [420, 900],
  'C': [840, 1320],
  'F': [420, 1320],
  'HC': [540, 1020],
  'OFF': [0, 1440],
};

/// A self-contained UI data source. No Firebase client, credentials or network IO.
/// Production adapters must revalidate every mutation on the server.
class WorkspaceStore {
  final Set<void Function()> _listeners = {};
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  WorkspaceStore({DateTime? today, bool restore = true, String? snapshot})
    : today = DateTime(
        (today ?? _vietnamNow()).year,
        (today ?? _vietnamNow()).month,
        (today ?? _vietnamNow()).day,
      ) {
    _seed();
    if (restore) {
      final saved = snapshot ?? readWorkspace();
      if (saved != null) {
        try {
          _restore(saved);
        } catch (_) {
          storageNotice =
              'Không đọc được bản lưu cũ; đang dùng dữ liệu mẫu mới.';
        }
      }
    }
  }
  static DateTime _vietnamNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));
  final DateTime today;
  WorkspaceRole role = WorkspaceRole.customer;
  String staffId = 'staff-1';
  String customerName = 'Nguyễn Minh Anh';
  String customerPhone = '0901234567';
  String? storageNotice;
  List<RowData> people = [],
      services = [],
      bookings = [],
      shifts = [],
      vouchers = [],
      messages = [];
  List<RowData> completions = [], receipts = [], audit = [];
  final Set<String> _requests = {};
  int _sequence = 0;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  String get employeeName => person(staffId)['name'] as String;
  String get staffBranch => person(staffId)['salonId'] as String;
  bool get staffEnabled => person(staffId)['active'] == true;
  RowData person(String id) => people.firstWhere((p) => p['id'] == id);
  String branchName(String id) =>
      sampleSalons.firstWhere((b) => b.id == id).name;
  bool _overlaps(int a, int b, int c, int d) => a < d && c < b;
  bool _live(RowData b) =>
      b['status'] == 'confirmed' || b['status'] == 'in_service';
  List<RowData> activeShifts(String employee, String day) => shifts
      .where(
        (s) =>
            s['employeeId'] == employee &&
            s['day'] == day &&
            s['status'] != 'cancelled',
      )
      .toList();
  List<RowData> liveBookings(String employee, String day) => bookings
      .where((b) => b['employeeId'] == employee && b['day'] == day && _live(b))
      .toList();
  void switchRole(WorkspaceRole next, {String? employee}) {
    role = next;
    if (employee != null) staffId = employee;
    notifyListeners();
  }

  void _admin() {
    if (role != WorkspaceRole.admin) {
      throw StateError('Chỉ quản trị viên được thực hiện thao tác này.');
    }
  }

  void _staffBooking(RowData b) {
    if (role == WorkspaceRole.admin) return;
    if (role != WorkspaceRole.staff ||
        !staffEnabled ||
        b['employeeId'] != staffId) {
      throw StateError('Bạn không có quyền xử lý lịch hẹn này.');
    }
  }

  void _changed(String action) {
    audit.add({
      'id': _id('event'),
      'action': action,
      'at': DateTime.now().toUtc().toIso8601String(),
      'actor': role.name,
    });
    try {
      writeWorkspace(exportJson());
      storageNotice = null;
    } catch (_) {
      storageNotice =
          'Trình duyệt không cho lưu cục bộ. Hãy xuất bản lưu trước khi đóng trang.';
    }
    notifyListeners();
  }

  void _seed() {
    services = commonServices
        .map(
          (s) => <String, dynamic>{
            'id': s.id,
            'name': s.name,
            'price': s.price,
            'duration': s.durationMinutes,
            'description': s.description,
            'active': true,
          },
        )
        .toList();
    const names = [
      'Lê Hoàng Nam',
      'Trần Quốc Bảo',
      'Phạm Minh Khang',
      'Nguyễn Đức Huy',
      'Võ Anh Tuấn',
      'Đặng Gia Phúc',
    ];
    people = List.generate(
      6,
      (i) => {
        'id': 'staff-${i + 1}',
        'name': names[i],
        'salonId': 'salon_0${i ~/ 2 + 1}',
        'active': true,
        'email': 'nhanvien${i + 1}@example.test',
      },
    );
    for (var d = -35; d <= 65; d++) {
      final day = dayKey(today.add(Duration(days: d)));
      for (final p in people) {
        final position = people.indexOf(p);
        final code = d >= 6
            ? ['S', 'C', 'HC', 'F', 'OFF'][(d + position) % 5]
            : 'F';
        final hours = shiftTemplates[code]!;
        shifts.add({
          'id': _id('shift'),
          'employeeId': p['id'],
          'salonId': p['salonId'],
          'day': day,
          'code': code,
          'start': hours[0],
          'end': hours[1],
          'status': code == 'OFF' ? 'off' : 'scheduled',
        });
      }
    }
    vouchers = [
      {
        'id': 'WELCOME10',
        'name': 'Chào bạn mới',
        'percent': 10,
        'minimum': 100000,
        'limit': 30,
        'used': 0,
        'active': true,
      },
      {
        'id': 'MEN15',
        'name': 'Phong cách mới',
        'percent': 15,
        'minimum': 200000,
        'limit': 20,
        'used': 0,
        'active': true,
      },
    ];
    final cuts = [services[1], services[2]];
    for (var i = 0; i < 16; i++) {
      final p = people[i % 6];
      final d = today.subtract(Duration(days: i ~/ 2 + 1));
      final b = <String, dynamic>{
        'id': 'MHB-${1000 + i}',
        'customerId': i.isEven ? 'customer-local' : 'other',
        'customer': i.isEven ? customerName : 'Khách ${i + 1}',
        'phone': customerPhone,
        'employeeId': p['id'],
        'salonId': p['salonId'],
        'day': dayKey(d),
        'start': 540 + i % 2 * 120,
        'end': 600 + i % 2 * 120,
        'items': cuts.map((s) => Map<String, dynamic>.from(s)).toList(),
        'total': 110000,
        'discount': 0,
        'status': 'completed',
        'note': '',
        'payment': 'Tại salon',
        'createdAt': d.toIso8601String(),
      };
      bookings.add(b);
      _snapshot(b, completedAt: '${dayKey(d)}T12:00:00+07:00');
      if (i % 3 != 0) {
        receipts.add({
          'id': 'receipt-$i',
          'bookingId': b['id'],
          'amount': i % 4 == 0 ? 60000 : 110000,
          'at': d.toIso8601String(),
        });
      }
    }
    for (var i = 0; i < 4; i++) {
      final p = people[i];
      bookings.add({
        'id': 'MHB-${1100 + i}',
        'customerId': i.isEven ? 'customer-local' : 'other',
        'customer': i.isEven ? customerName : 'Khách Nguyễn Văn $i',
        'phone': customerPhone,
        'employeeId': p['id'],
        'salonId': p['salonId'],
        'day': dayKey(today),
        'start': 540 + i * 90,
        'end': 600 + i * 90,
        'items': cuts.map((s) => Map<String, dynamic>.from(s)).toList(),
        'total': 110000,
        'discount': 0,
        'status': 'confirmed',
        'note': 'Tư vấn kiểu tóc phù hợp khuôn mặt',
        'payment': 'Tại salon',
        'createdAt': today.toIso8601String(),
      });
    }
  }

  int durationOf(Iterable<RowData> items) =>
      ((items.fold<int>(0, (n, s) => n + (s['duration'] as int)) + 29) ~/ 30) *
      30;
  List<int> availableSlots(
    String employee,
    String branch,
    String day,
    int duration,
  ) {
    if (day.compareTo(dayKey(today)) < 0 ||
        person(employee)['active'] != true ||
        duration <= 0) {
      return [];
    }
    final work = activeShifts(
      employee,
      day,
    ).where((s) => s['salonId'] == branch && s['status'] == 'scheduled');
    final busy = liveBookings(employee, day);
    return [
      for (var m = 420; m + duration <= 1320; m += 30)
        if (work.any((s) => m >= s['start'] && m + duration <= s['end']) &&
            !busy.any(
              (b) => _overlaps(
                m,
                m + duration,
                b['start'] as int,
                b['end'] as int,
              ),
            ))
          m,
    ];
  }

  String createBooking({
    required String requestId,
    required String employee,
    required String branch,
    required String day,
    required int start,
    required Set<String> serviceIds,
    String voucher = '',
    String note = '',
    String payment = 'Tại salon',
  }) {
    if (role != WorkspaceRole.customer) {
      throw StateError('Hãy chuyển sang tài khoản khách hàng để đặt lịch.');
    }
    final fingerprint = jsonEncode([
      employee,
      branch,
      day,
      start,
      (serviceIds.toList()..sort()),
      voucher.trim().toUpperCase(),
      note.trim(),
      payment,
    ]);
    final repeated = bookings
        .where((b) => b['requestId'] == requestId)
        .firstOrNull;
    if (repeated != null) {
      if (repeated['requestFingerprint'] != fingerprint) {
        throw StateError('Mã yêu cầu đã được dùng cho nội dung khác.');
      }
      return repeated['id'] as String;
    }
    if (customerName.trim().isEmpty ||
        !RegExp(r'^0\d{9}$').hasMatch(customerPhone)) {
      throw StateError(
        'Vui lòng nhập tên và số điện thoại Việt Nam gồm 10 số.',
      );
    }
    final items = services
        .where((s) => serviceIds.contains(s['id']) && s['active'] == true)
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    if (items.isEmpty || items.length != serviceIds.length) {
      throw StateError('Vui lòng chọn dịch vụ còn hoạt động.');
    }
    final duration = durationOf(items);
    if (!availableSlots(employee, branch, day, duration).contains(start)) {
      throw StateError(
        'Giờ này không còn trống hoặc thợ chưa có ca. Hãy chọn giờ khác.',
      );
    }
    final total = items.fold<int>(0, (n, s) => n + (s['price'] as int));
    final code = voucher.trim().toUpperCase();
    RowData? offer;
    if (code.isNotEmpty) {
      offer = vouchers
          .where((v) => v['id'] == code && v['active'] == true)
          .firstOrNull;
      if (offer == null ||
          total < offer['minimum'] ||
          offer['used'] >= offer['limit']) {
        throw StateError(
          'Voucher không hợp lệ, hết lượt hoặc chưa đủ giá trị tối thiểu.',
        );
      }
    }
    final discount = offer == null
        ? 0
        : (total * (offer['percent'] as int) ~/ 100);
    final b = <String, dynamic>{
      'id': _id('MHB'),
      'requestId': requestId,
      'requestFingerprint': fingerprint,
      'customerId': 'customer-local',
      'customer': customerName.trim(),
      'phone': customerPhone,
      'employeeId': employee,
      'salonId': branch,
      'day': day,
      'start': start,
      'end': start + duration,
      'items': items,
      'total': total,
      'discount': discount,
      'status': 'confirmed',
      'note': note.trim(),
      'payment': payment,
      'voucher': code,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    bookings.add(b);
    if (offer != null) offer['used'] = (offer['used'] as int) + 1;
    _changed('Đặt lịch ${b['id']}');
    return b['id'] as String;
  }

  void cancelBooking(String id) {
    final b = bookings.firstWhere((b) => b['id'] == id);
    if (role != WorkspaceRole.admin &&
        (role != WorkspaceRole.customer ||
            b['customerId'] != 'customer-local')) {
      throw StateError('Bạn không có quyền hủy lịch này.');
    }
    if (b['status'] == 'cancelled') return;
    if (b['status'] != 'confirmed') {
      throw StateError('Chỉ được hủy lịch chưa bắt đầu phục vụ.');
    }
    b['status'] = 'cancelled';
    b['cancelledAt'] = DateTime.now().toUtc().toIso8601String();
    _changed('Hủy lịch $id');
  }

  void startBooking(String id) {
    final b = bookings.firstWhere((b) => b['id'] == id);
    _staffBooking(b);
    if (b['status'] != 'confirmed') {
      throw StateError('Chỉ bắt đầu lịch đã xác nhận.');
    }
    if (b['day'] != dayKey(today)) {
      throw StateError('Chỉ bắt đầu phục vụ lịch trong ngày hôm nay.');
    }
    b['status'] = 'in_service';
    b['startedAt'] = DateTime.now().toUtc().toIso8601String();
    _changed('Bắt đầu phục vụ $id');
  }

  void _snapshot(RowData b, {String? completedAt}) {
    completions.add({
      'bookingId': b['id'],
      'employeeId': b['employeeId'],
      'salonId': b['salonId'],
      'day': completedAt == null ? dayKey(today) : completedAt.substring(0, 10),
      'completedAt':
          completedAt ??
          '${dayKey(today)}T${clockText(_vietnamNow().hour * 60 + _vietnamNow().minute)}:00+07:00',
      'items': (b['items'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      'total': b['total'],
      'discount': b['discount'],
      'due': (b['total'] as int) - (b['discount'] as int),
    });
  }

  void completeBooking(String id) {
    final b = bookings.firstWhere((b) => b['id'] == id);
    _staffBooking(b);
    if (b['status'] == 'completed') return;
    if (b['status'] != 'in_service') {
      throw StateError('Hãy bắt đầu phục vụ trước khi hoàn thành.');
    }
    if (!completions.any((c) => c['bookingId'] == id)) _snapshot(b);
    b['status'] = 'completed';
    _changed('Hoàn thành $id');
  }

  int paidFor(String id) => receipts
      .where((r) => r['bookingId'] == id)
      .fold<int>(0, (n, r) => n + (r['amount'] as int));
  void receivePayment(String id, int amount, String requestId) {
    _admin();
    if (_requests.contains(requestId)) {
      final previous = receipts.firstWhere((r) => r['id'] == requestId);
      if (previous['bookingId'] != id || previous['amount'] != amount) {
        throw StateError('Mã biên nhận đã dùng cho nội dung khác.');
      }
      return;
    }
    final b = bookings.firstWhere((b) => b['id'] == id);
    final due = (b['total'] as int) - (b['discount'] as int) - paidFor(id);
    if (b['status'] != 'completed' || amount <= 0 || amount > due) {
      throw StateError(
        'Chỉ ghi thu cho lịch hoàn thành, số tiền không vượt công nợ.',
      );
    }
    receipts.add({
      'id': requestId,
      'bookingId': id,
      'amount': amount,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    _requests.add(requestId);
    _changed('Ghi nhận thu $id');
  }

  void assignRoster({
    required String branch,
    required Set<String> cells,
    required String code,
    int? customStart,
    int? customEnd,
  }) {
    _admin();
    if (cells.isEmpty || cells.length > 100) {
      throw StateError('Chọn từ 1 đến 100 ô cho mỗi lần lưu.');
    }
    final hours = code == 'T'
        ? [customStart ?? -1, customEnd ?? -1]
        : shiftTemplates[code];
    if (hours == null ||
        (code != 'OFF' &&
            (hours[0] < 420 ||
                hours[1] > 1320 ||
                hours[0] >= hours[1] ||
                hours.any((m) => m % 30 != 0)))) {
      throw StateError('Giờ ca phải nằm trong 07:00–22:00, theo bước 30 phút.');
    }
    final additions = <RowData>[];
    final removedIds = <String>{};
    for (final cell in cells) {
      final parts = cell.split('|'), employee = parts[0], day = parts[1];
      if (day.compareTo(dayKey(today)) < 0 ||
          person(employee)['active'] != true) {
        throw StateError(
          'Không sửa ngày quá khứ hoặc xếp ca cho nhân viên ngừng hoạt động.',
        );
      }
      final current = activeShifts(employee, day);
      for (final s in current.where((s) => s['salonId'] == branch)) {
        removedIds.add(s['id'] as String);
      }
      for (final s in current.where((s) => s['salonId'] != branch)) {
        if (_overlaps(hours[0], hours[1], s['start'] as int, s['end'] as int)) {
          throw StateError(
            '${person(employee)['name']} • ${shortDate(day)}: trùng ${s['code']} ${clockText(s['start'] as int)}–${clockText(s['end'] as int)} tại ${branchName(s['salonId'] as String)}.',
          );
        }
      }
      for (final b in liveBookings(
        employee,
        day,
      ).where((b) => b['salonId'] == branch)) {
        if (code == 'OFF' || b['start'] < hours[0] || b['end'] > hours[1]) {
          throw StateError(
            '${person(employee)['name']} có lịch khách ${clockText(b['start'] as int)} ngày ${shortDate(day)}; ca mới không bao phủ lịch hẹn.',
          );
        }
      }
      if (code == 'OFF' && liveBookings(employee, day).isNotEmpty) {
        throw StateError('Không xếp OFF khi có lịch khách còn hiệu lực.');
      }
      additions.add({
        'id': _id('shift'),
        'employeeId': employee,
        'salonId': branch,
        'day': day,
        'code': code,
        'start': hours[0],
        'end': hours[1],
        'status': code == 'OFF' ? 'off' : 'scheduled',
      });
    }
    for (final s in shifts.where((s) => removedIds.contains(s['id']))) {
      s['status'] = 'cancelled';
    }
    shifts.addAll(additions);
    _changed('Phân $code cho ${cells.length} ô');
  }

  void cancelShift(String id) {
    _admin();
    final s = shifts.firstWhere((s) => s['id'] == id);
    if ((s['day'] as String).compareTo(dayKey(today)) < 0) {
      throw StateError('Không hủy ca quá khứ.');
    }
    if (liveBookings(
      s['employeeId'] as String,
      s['day'] as String,
    ).any((b) => b['salonId'] == s['salonId'])) {
      throw StateError('Ca đang có lịch khách. Hãy xử lý lịch hẹn trước.');
    }
    s['status'] = 'cancelled';
    _changed('Hủy ca $id');
  }

  void swapShifts(String aId, String bId) {
    _admin();
    final a = shifts.firstWhere((s) => s['id'] == aId),
        b = shifts.firstWhere((s) => s['id'] == bId);
    if (a['employeeId'] == b['employeeId'] ||
        a['day'] == b['day'] ||
        a['status'] != 'scheduled' ||
        b['status'] != 'scheduled') {
      throw StateError(
        'Chọn hai ca làm của hai nhân viên ở hai ngày khác nhau. OFF không phải ca làm.',
      );
    }
    for (final employee in [
      a['employeeId'] as String,
      b['employeeId'] as String,
    ]) {
      if (person(employee)['active'] != true) {
        throw StateError('Nhân viên đã ngừng hoạt động.');
      }
      for (final day in [a['day'] as String, b['day'] as String]) {
        if (day.compareTo(dayKey(today)) < 0) {
          throw StateError('Không đổi ca trong quá khứ.');
        }
        if (liveBookings(employee, day).isNotEmpty) {
          throw StateError(
            '${person(employee)['name']} có lịch khách ngày ${shortDate(day)}. Cần trống cả hai người trong cả hai ngày.',
          );
        }
      }
    }
    for (final pair in [
      (a, b['employeeId'] as String),
      (b, a['employeeId'] as String),
    ]) {
      for (final s in activeShifts(
        pair.$2,
        pair.$1['day'] as String,
      ).where((s) => s['id'] != aId && s['id'] != bId)) {
        if (_overlaps(
          pair.$1['start'] as int,
          pair.$1['end'] as int,
          s['start'] as int,
          s['end'] as int,
        )) {
          throw StateError(
            '${person(pair.$2)['name']} trùng ${s['code']} ${clockText(s['start'] as int)}–${clockText(s['end'] as int)} ngày ${shortDate(s['day'] as String)} tại ${branchName(s['salonId'] as String)}.',
          );
        }
      }
    }
    final first = a['employeeId'];
    a['employeeId'] = b['employeeId'];
    b['employeeId'] = first;
    _changed('Đổi hai ca A/B');
  }

  void savePerson(RowData p) {
    _admin();
    if ('${p['name']}'.trim().isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch('${p['email']}')) {
      throw StateError('Nhập tên và email hợp lệ.');
    }
    if (people.any((x) => x['email'] == p['email'] && x['id'] != p['id'])) {
      throw StateError('Email đã được liên kết với nhân viên khác.');
    }
    final index = people.indexWhere((x) => x['id'] == p['id']);
    if (index < 0) {
      people.add({...p, 'id': _id('staff')});
    } else {
      people[index] = Map.from(p);
    }
    _changed('Cập nhật nhân viên');
  }

  void saveService(RowData s) {
    _admin();
    if ('${s['name']}'.trim().isEmpty ||
        (s['price'] as int) <= 0 ||
        (s['duration'] as int) <= 0) {
      throw StateError('Tên, giá và thời lượng phải hợp lệ.');
    }
    final index = services.indexWhere((x) => x['id'] == s['id']);
    if (index < 0) {
      services.add({...s, 'id': _id('service')});
    } else {
      services[index] = Map.from(s);
    }
    _changed('Cập nhật dịch vụ');
  }

  void saveVoucher(RowData v) {
    _admin();
    if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch('${v['id']}') ||
        v['percent'] <= 0 ||
        v['percent'] > 100 ||
        v['limit'] < v['used'] ||
        v['minimum'] < 0) {
      throw StateError(
        'Mã 3–20 chữ/số, giảm 1–100%, số lượt không nhỏ hơn lượt đã dùng.',
      );
    }
    final i = vouchers.indexWhere((x) => x['id'] == v['id']);
    if (i >= 0 && v['newVoucher'] == true) {
      throw StateError('Mã voucher đã tồn tại; hãy chọn mã khác.');
    }
    if (i >= 0 && v['used'] != vouchers[i]['used']) {
      throw StateError('Không được thay đổi số lượt đã dùng.');
    }
    v.remove('newVoucher');
    if (i < 0) {
      vouchers.add(Map.from(v));
    } else {
      vouchers[i] = Map.from(v);
    }
    _changed('Cập nhật voucher');
  }

  void sendMessage(String text, {bool reply = false}) {
    if (text.trim().isEmpty) return;
    if (reply) _admin();
    messages.add({
      'id': _id('message'),
      'text': text.trim(),
      'sender': reply ? 'admin' : 'customer',
      'at': DateTime.now().toIso8601String(),
    });
    _changed('Gửi tin nhắn hỗ trợ');
  }

  List<RowData> reportRows(
    ReportPeriod period,
    DateTime anchor, {
    String? branch,
    String? employee,
  }) {
    final first = switch (period) {
      ReportPeriod.day => DateTime(anchor.year, anchor.month, anchor.day),
      ReportPeriod.week => DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
      ).subtract(Duration(days: anchor.weekday - 1)),
      ReportPeriod.month => DateTime(anchor.year, anchor.month),
      ReportPeriod.year => DateTime(anchor.year),
    };
    final end = switch (period) {
      ReportPeriod.day => first.add(const Duration(days: 1)),
      ReportPeriod.week => first.add(const Duration(days: 7)),
      ReportPeriod.month => DateTime(first.year, first.month + 1),
      ReportPeriod.year => DateTime(first.year + 1),
    };
    final scopedEmployee = role == WorkspaceRole.staff ? staffId : employee;
    if (role == WorkspaceRole.staff && !staffEnabled) return [];
    return completions
        .where(
          (c) =>
              (c['day'] as String).compareTo(dayKey(first)) >= 0 &&
              (c['day'] as String).compareTo(dayKey(end)) < 0 &&
              (branch == null || c['salonId'] == branch) &&
              (scopedEmployee == null || c['employeeId'] == scopedEmployee),
        )
        .toList();
  }

  void saveProfile(String name, String phone) {
    if (name.trim().isEmpty || !RegExp(r'^0\d{9}$').hasMatch(phone)) {
      throw StateError('Nhập tên và số điện thoại Việt Nam gồm 10 số.');
    }
    customerName = name.trim();
    customerPhone = phone;
    _changed('Cập nhật hồ sơ');
  }

  String exportJson() => jsonEncode({
    'version': 1,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'people': people,
    'services': services,
    'bookings': bookings,
    'shifts': shifts,
    'vouchers': vouchers,
    'messages': messages,
    'completions': completions,
    'receipts': receipts,
    'audit': audit,
  });
  void _restore(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['version'] != 1) throw const FormatException('Unsupported data');
    List<RowData> rows(String key) => (data[key] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final loaded = [
      for (final key in [
        'people',
        'services',
        'bookings',
        'shifts',
        'vouchers',
        'messages',
        'completions',
        'receipts',
        'audit',
      ])
        rows(key),
    ];
    final loadedName = data['customerName'] as String;
    final loadedPhone = data['customerPhone'] as String;
    if (loaded[0].isEmpty || loaded[1].isEmpty) {
      throw const FormatException('Empty catalog');
    }
    people = loaded[0];
    services = loaded[1];
    bookings = loaded[2];
    shifts = loaded[3];
    vouchers = loaded[4];
    messages = loaded[5];
    completions = loaded[6];
    receipts = loaded[7];
    audit = loaded[8];
    customerName = loadedName;
    customerPhone = loadedPhone;
    _requests.addAll(receipts.map((r) => r['id'] as String));
  }
}
