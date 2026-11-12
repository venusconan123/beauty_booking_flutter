import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/sample_salons.dart';
import '../models/monthly_roster.dart';
import '../widgets/monthly_roster_grid.dart';
import 'workspace_store.dart';

part 'workspace_bookings.dart';
part 'workspace_roster.dart';
part 'workspace_management.dart';

const _ink = Color(0xff0b1623),
    _gold = Color(0xffd9ad60),
    _paper = Color(0xfff6f7f9),
    _muted = Color(0xff67717d);
const _line = Color(0xffe8ebef);

class WorkspaceApp extends StatelessWidget {
  const WorkspaceApp({super.key, required this.store});
  final WorkspaceStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Men Hair Booking • Giao diện',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: _ink, height: 1.5),
        bodyLarge: TextStyle(color: _ink, height: 1.5),
      ),
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gold,
        primary: _ink,
        secondary: _gold,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _paper,
        foregroundColor: _ink,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 2),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xfff3e6cf),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: _line),
        selectedColor: const Color(0xfff3e6cf),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _line),
    ),
    home: _WorkspaceShell(store: store),
  );
}

class _WorkspaceShell extends StatefulWidget {
  const _WorkspaceShell({required this.store});
  final WorkspaceStore store;
  @override
  State<_WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<_WorkspaceShell> {
  WorkspaceStore get s => widget.store;
  String page = 'home';
  bool entered = false;
  final scaffold = GlobalKey<ScaffoldState>();
  @override
  void initState() {
    super.initState();
    s.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(_refresh);
    super.dispose();
  }

  List<(String, String, IconData)> get destinations => switch (s.role) {
    WorkspaceRole.customer => [
      ('home', 'Khám phá', Icons.explore_outlined),
      ('bookings', 'Lịch hẹn của tôi', Icons.event_note_outlined),
      ('styles', 'Kiểu tóc', Icons.content_cut),
      ('branches', 'Chi nhánh', Icons.location_on_outlined),
      ('support', 'Hỗ trợ', Icons.chat_bubble_outline),
      ('profile', 'Tài khoản', Icons.person_outline),
    ],
    WorkspaceRole.staff => [
      ('bookings', 'Lịch được giao', Icons.event_note_outlined),
      ('roster', 'Lịch làm tháng', Icons.calendar_month_outlined),
      ('reports', 'Thống kê cá nhân', Icons.insights_outlined),
      ('profile', 'Tài khoản', Icons.person_outline),
    ],
    WorkspaceRole.admin => [
      ('home', 'Tổng quan', Icons.dashboard_outlined),
      ('bookings', 'Quản lý lịch hẹn', Icons.event_note_outlined),
      ('roster', 'Bảng phân ca', Icons.calendar_month_outlined),
      ('reports', 'Thống kê', Icons.insights_outlined),
      ('people', 'Nhân viên', Icons.badge_outlined),
      ('services', 'Dịch vụ', Icons.content_cut),
      ('vouchers', 'Voucher', Icons.local_offer_outlined),
      ('branches', 'Chi nhánh', Icons.storefront_outlined),
      ('support', 'Hộp thư hỗ trợ', Icons.chat_bubble_outline),
      ('profile', 'Cài đặt', Icons.settings_outlined),
    ],
  };
  void _navigate(String next) {
    setState(() => page = next);
  }

  Future<void> _roles() async {
    final chosen = await showModalBottomSheet<(WorkspaceRole, String?)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn không gian làm việc',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Dữ liệu cục bộ dùng chung; không đăng nhập Firebase thật.',
                  style: TextStyle(color: _muted),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Khách hàng'),
                  subtitle: Text(s.customerName),
                  onTap: () => Navigator.pop(c, (WorkspaceRole.customer, null)),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Quản trị viên'),
                  subtitle: const Text('Quản lý toàn bộ 3 chi nhánh'),
                  onTap: () => Navigator.pop(c, (WorkspaceRole.admin, null)),
                ),
                for (final p in s.people)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text('${p['name']}'),
                    subtitle: Text(
                      '${s.branchName(p['salonId'] as String)}${p['active'] == true ? '' : ' • Ngừng hoạt động'}',
                    ),
                    onTap: () => Navigator.pop(c, (
                      WorkspaceRole.staff,
                      p['id'] as String,
                    )),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      s.switchRole(chosen.$1, employee: chosen.$2);
      setState(() {
        entered = true;
        page = s.role == WorkspaceRole.staff ? 'bookings' : 'home';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!entered) {
      return _Welcome(
        store: s,
        onEnter: () => setState(() {
          entered = true;
          page = 'home';
        }),
        onRoles: _roles,
      );
    }
    final menu = destinations;
    if (!menu.any((d) => d.$1 == page)) page = menu.first.$1;
    final title = menu.firstWhere((d) => d.$1 == page).$2;
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final content = s.role == WorkspaceRole.staff && !s.staffEnabled
        ? _Empty(
            icon: Icons.lock_outline,
            title: 'Tài khoản đã ngừng hoạt động',
            text:
                'Liên hệ quản trị viên để được hỗ trợ. Lịch sử vẫn được giữ nguyên.',
            action: TextButton(
              onPressed: _roles,
              child: const Text('Đổi tài khoản xem trước'),
            ),
          )
        : switch (page) {
            'home' => _Home(store: s, onBook: _book, onNavigate: _navigate),
            'bookings' => _BookingPage(store: s, onBook: _book),
            'roster' => _RosterPage(store: s),
            'reports' => _ReportsPage(store: s),
            'people' => _PeoplePage(store: s),
            'services' => _ServicesPage(store: s),
            'vouchers' => _VouchersPage(store: s),
            'branches' => _BranchesPage(
              store: s,
              onBook: (id) => _book(branch: id),
            ),
            'styles' => _StylesPage(onBook: _book),
            'support' => _SupportPage(store: s),
            _ => _ProfilePage(
              store: s,
              onExit: () => setState(() => entered = false),
              onRoles: _roles,
            ),
          };
    Widget side = Container(
      width: 252,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, Color(0xff192a3b)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.content_cut, color: _gold, size: 32),
                  SizedBox(height: 14),
                  Text(
                    'MEN HAIR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'BOOKING & STUDIO',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final d in menu)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected: page == d.$1,
                        selectedTileColor: const Color(0xffd9ad60),
                        iconColor: Colors.white60,
                        textColor: Colors.white70,
                        selectedColor: _ink,
                        leading: Icon(d.$3),
                        title: Text(
                          d.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: page == d.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: page == d.$1
                            ? const Icon(Icons.chevron_right, size: 18)
                            : null,
                        onTap: () {
                          _navigate(d.$1);
                          if (!wide) Navigator.pop(context);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: _gold,
                child: Icon(Icons.person, color: _ink),
              ),
              title: Text(
                s.role == WorkspaceRole.admin
                    ? 'Quản trị viên'
                    : s.role == WorkspaceRole.staff
                    ? s.employeeName
                    : s.customerName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Đổi vai trò xem trước',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              onTap: _roles,
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
    return Scaffold(
      key: scaffold,
      drawer: wide ? null : Drawer(child: side),
      appBar: wide
          ? null
          : AppBar(
              title: Text(title),
              actions: [
                IconButton(
                  tooltip: 'Đổi vai trò',
                  onPressed: _roles,
                  icon: const Icon(Icons.switch_account_outlined),
                ),
              ],
            ),
      body: Row(
        children: [
          if (wide) side,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: _line)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MEN HAIR / WORKSPACE',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.8,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${shortDate(dayKey(s.today))} • Giờ Việt Nam',
                          style: const TextStyle(color: _muted),
                        ),
                        const SizedBox(width: 14),
                        IconButton(
                          tooltip: 'Đổi vai trò',
                          onPressed: _roles,
                          icon: const Icon(Icons.switch_account_outlined),
                        ),
                      ],
                    ),
                  ),
                Container(
                  color: const Color(0xfff4eddf),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Text(
                    s.storageNotice ??
                        'Bản xem trước • Dữ liệu được lưu trên thiết bị • Thanh toán mô phỏng',
                    style: const TextStyle(
                      color: Color(0xff705018),
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: menu.indexWhere((d) => d.$1 == page).clamp(0, 3),
              onDestinationSelected: (i) {
                if (menu.length > 4 && i == 3) {
                  scaffold.currentState?.openDrawer();
                } else {
                  _navigate(menu[i].$1);
                }
              },
              destinations: [
                for (final d in menu.take(menu.length > 4 ? 3 : 4))
                  NavigationDestination(icon: Icon(d.$3), label: d.$2),
                if (menu.length > 4)
                  const NavigationDestination(
                    icon: Icon(Icons.menu),
                    label: 'Thêm',
                  ),
              ],
            ),
    );
  }

  void _book({String? branch}) {
    if (!s.people.any((p) => p['active'] == true)) {
      _info(
        context,
        'Chưa có chuyên viên',
        'Vui lòng quay lại sau khi quản trị viên mở hoạt động cho nhân viên.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _BookingWizard(store: s, initialBranch: branch ?? 'salon_01'),
      ),
    );
  }
}

class _Welcome extends StatefulWidget {
  const _Welcome({
    required this.store,
    required this.onEnter,
    required this.onRoles,
  });
  final WorkspaceStore store;
  final VoidCallback onEnter, onRoles;
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(text: 'khachhang@example.test'),
      password = TextEditingController(text: 'preview123'),
      name = TextEditingController(),
      phone = TextEditingController();
  bool register = false, obscure = true;
  @override
  void dispose() {
    for (final c in [email, password, name, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/login_barbershop_background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: _ink),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xee0b1623), Color(0xb30b1623)],
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Panel(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.content_cut, color: _gold, size: 44),
                      const SizedBox(height: 16),
                      const Text(
                        'MEN HAIR BOOKING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        register
                            ? 'Tạo phong cách của bạn'
                            : 'Chào mừng trở lại',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bản duyệt giao diện: biểu mẫu xử lý cục bộ, không tạo hay xác thực tài khoản thật.',
                        style: TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 24),
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nhập họ và tên'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                          ),
                          validator: (v) =>
                              RegExp(r'^0\d{9}$').hasMatch(v ?? '')
                              ? null
                              : 'Số điện thoại gồm 10 số, bắt đầu bằng 0',
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) =>
                            RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(v ?? '')
                            ? null
                            : 'Nhập email hợp lệ',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu xem trước',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (v?.length ?? 0) < 6 ? 'Ít nhất 6 ký tự' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _info(
                            context,
                            'Khôi phục mật khẩu',
                            'Chức năng gửi email sẽ được nối Firebase Auth sau khi duyệt giao diện. Bản này không gửi email hoặc lưu mật khẩu.',
                          ),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (!form.currentState!.validate()) return;
                          if (register) {
                            widget.store.saveProfile(name.text, phone.text);
                          }
                          widget.store.switchRole(WorkspaceRole.customer);
                          widget.onEnter();
                        },
                        child: Text(
                          register
                              ? 'Tạo hồ sơ xem trước'
                              : 'Vào không gian khách hàng',
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => register = !register),
                        child: Text(
                          register
                              ? 'Đã có tài khoản? Đăng nhập'
                              : 'Chưa có tài khoản? Đăng ký',
                        ),
                      ),
                      const Divider(),
                      OutlinedButton.icon(
                        onPressed: widget.onRoles,
                        icon: const Icon(Icons.switch_account),
                        label: const Text('Xem vai trò Admin / Nhân viên'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 22});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: .025),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle, {this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 14,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: _muted)),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title, text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: _gold),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          ?action,
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.color = const Color(0xff1a7d68)});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _Metrics extends StatelessWidget {
  const _Metrics(this.items);
  final List<(String, String, IconData)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = c.maxWidth >= 950
          ? 4
          : c.maxWidth >= 520
          ? 2
          : 1;
      final width = (c.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final i in items)
            SizedBox(
              width: width,
              child: Panel(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfff6efdf),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        i.$3,
                        color: const Color(0xff98702f),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.$1,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String text, {
  String button = 'Xác nhận',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(button),
          ),
        ],
      ),
    ) ??
    false;
Future<void> _info(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void _mutate(BuildContext context, VoidCallback action, String message) {
  try {
    action();
    _toast(context, message);
  } catch (e) {
    _toast(context, e.toString().replaceFirst('Bad state: ', ''));
  }
}

Widget _page(List<Widget> children) => LayoutBuilder(
  builder: (context, constraints) => ListView(
    padding: EdgeInsets.symmetric(
      horizontal: constraints.maxWidth < 600 ? 16 : 30,
      vertical: 28,
    ),
    children: children,
  ),
);
Widget _gap([double height = 18]) => SizedBox(height: height);

class _Home extends StatelessWidget {
  const _Home({
    required this.store,
    required this.onBook,
    required this.onNavigate,
  });
  final WorkspaceStore store;
  final VoidCallback onBook;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) {
    final admin = store.role == WorkspaceRole.admin;
    final upcoming =
        store.bookings
            .where(
              (b) =>
                  b['status'] == 'confirmed' &&
                  (admin || b['customerId'] == 'customer-local'),
            )
            .toList()
          ..sort(
            (a, b) => '${a['day']}${a['start']}'.compareTo(
              '${b['day']}${b['start']}',
            ),
          );
    final todayBookings = store.bookings
        .where((b) => b['day'] == dayKey(store.today))
        .toList();
    return _page([
      _Heading(
        admin
            ? 'Một ngày vận hành hiệu quả'
            : 'Chào ${store.customerName.split(' ').last},',
        admin
            ? '3 chi nhánh • Điều phối lịch hẹn, nhân sự và hiệu suất'
            : 'Một diện mạo mới, một ngày tự tin hơn.',
        action: admin
            ? OutlinedButton.icon(
                onPressed: () => onNavigate('roster'),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Bảng phân ca'),
              )
            : null,
      ),
      if (!admin) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).width < 600 ? 400 : 290,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/home_editorial_hero.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(color: _ink),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _ink.withValues(alpha: .95),
                        _ink.withValues(alpha: .35),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR STYLE. YOUR SIGNATURE.',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        _gap(12),
                        const Text(
                          'Chất riêng bắt đầu\ntừ mái tóc.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        _gap(18),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _ink,
                          ),
                          onPressed: onBook,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Đặt lịch ngay'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _gap(24),
      ] else ...[
        _WorkspaceBanner(
          eyebrow: 'KHÔNG GIAN QUẢN TRỊ',
          title: 'Mọi lịch hẹn. Một góc nhìn.',
          subtitle:
              'Sắp xếp đội ngũ, chăm sóc khách hàng và theo dõi hoạt động mỗi ngày.',
          icon: Icons.space_dashboard_outlined,
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
            ),
            onPressed: () => onNavigate('bookings'),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Quản lý lịch hẹn'),
          ),
        ),
        _gap(22),
        _Metrics([
          ('Lịch hẹn hôm nay', '${todayBookings.length}', Icons.event_note),
          (
            'Đang phục vụ',
            '${todayBookings.where((b) => b['status'] == 'in_service').length}',
            Icons.content_cut,
          ),
          (
            'Nhân viên hoạt động',
            '${store.people.where((p) => p['active'] == true).length}',
            Icons.groups_outlined,
          ),
          (
            'Chưa thanh toán',
            moneyText(
              store.completions.fold<int>(
                0,
                (n, c) =>
                    n +
                    math.max(
                      0,
                      (c['due'] as int) -
                          store.paidFor(c['bookingId'] as String),
                    ),
              ),
            ),
            Icons.account_balance_wallet_outlined,
          ),
        ]),
        _gap(24),
      ],
      _Heading(
        admin ? 'Lịch sắp tới' : 'Lịch hẹn của bạn',
        'Theo dõi cuộc hẹn và các bước phục vụ',
        action: TextButton(
          onPressed: () => onNavigate('bookings'),
          child: const Text('Xem tất cả →'),
        ),
      ),
      if (upcoming.isEmpty)
        Panel(
          child: _Empty(
            icon: Icons.event_available,
            title: 'Chưa có lịch sắp tới',
            text: 'Chọn chi nhánh và khung giờ phù hợp.',
            action: admin
                ? null
                : FilledButton(
                    onPressed: onBook,
                    child: const Text('Đặt lịch'),
                  ),
          ),
        ),
      for (final b in upcoming.take(3))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _BookingTile(store: store, booking: b),
        ),
      _gap(20),
      if (!admin) ...[
        const _Heading(
          'Dịch vụ dành cho bạn',
          'Giá và thời lượng hiển thị trước khi đặt',
        ),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth >= 850
                ? (c.maxWidth - 24) / 3
                : c.maxWidth >= 530
                ? (c.maxWidth - 12) / 2
                : c.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final service in store.services.where(
                  (s) => s['active'] == true,
                ))
                  SizedBox(
                    width: width,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.content_cut, color: _gold),
                          _gap(16),
                          Text(
                            '${service['name']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _gap(8),
                          Text(
                            '${service['description']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted),
                          ),
                          _gap(16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  moneyText(service['price'] as int),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '${service['duration']} phút',
                                style: const TextStyle(color: _muted),
                              ),
                            ],
                          ),
                          _gap(12),
                          TextButton(
                            onPressed: onBook,
                            child: const Text('Chọn dịch vụ →'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ] else
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Điều hành nhanh',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              _gap(),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in [
                    ('people', 'Quản lý nhân viên', Icons.groups_outlined),
                    ('reports', 'Báo cáo doanh thu', Icons.insights),
                    ('services', 'Danh mục dịch vụ', Icons.content_cut),
                    (
                      'vouchers',
                      'Ưu đãi khách hàng',
                      Icons.local_offer_outlined,
                    ),
                  ])
                    OutlinedButton.icon(
                      onPressed: () => onNavigate(item.$1),
                      icon: Icon(item.$3),
                      label: Text(item.$2),
                    ),
                ],
              ),
            ],
          ),
        ),
    ]);
  }
}

class _WorkspaceBanner extends StatelessWidget {
  const _WorkspaceBanner({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  });
  final String eyebrow, title, subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 22 : 30),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(colors: [_ink, Color(0xff263e50)]),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                _gap(12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: constraints.maxWidth < 500 ? 25 : 30,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _gap(10),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xffc4cfd9)),
                ),
                if (action != null) ...[_gap(20), action!],
              ],
            ),
          ),
          if (constraints.maxWidth >= 650) ...[
            const SizedBox(width: 32),
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Icon(icon, color: _gold, size: 54),
            ),
          ],
        ],
      ),
    ),
  );
}
