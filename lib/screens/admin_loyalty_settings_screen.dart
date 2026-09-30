import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/loyalty_settings.dart';

class AdminLoyaltySettingsScreen extends StatefulWidget {
  const AdminLoyaltySettingsScreen({super.key});

  @override
  State<AdminLoyaltySettingsScreen> createState() =>
      _AdminLoyaltySettingsScreenState();
}

class _AdminLoyaltySettingsScreenState
    extends State<AdminLoyaltySettingsScreen> {
  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xF2121B28);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);

  final _formKey = GlobalKey<FormState>();
  final _requiredVisitsController = TextEditingController(text: '10');
  final _minimumOrderController = TextEditingController(text: '500000');
  final _visitDiscountController = TextEditingController(text: '25');
  final _orderDiscountController = TextEditingController(text: '10');
  bool _visitRewardEnabled = true;
  bool _orderRewardEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _requiredVisitsController.dispose();
    _minimumOrderController.dispose();
    _visitDiscountController.dispose();
    _orderDiscountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('loyalty')
          .get();
      final settings = LoyaltySettings.fromMap(snapshot.data());
      if (!mounted) return;
      setState(() {
        _visitRewardEnabled = settings.visitRewardEnabled;
        _orderRewardEnabled = settings.orderRewardEnabled;
        _requiredVisitsController.text = settings.requiredVisits.toString();
        _minimumOrderController.text = settings.minimumOrderAmount.toString();
        _visitDiscountController.text = settings.visitDiscountPercent
            .toString();
        _orderDiscountController.text = settings.orderDiscountPercent
            .toString();
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(_firebaseErrorMessage(error), true);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('loyalty')
          .set({
            'visitRewardEnabled': _visitRewardEnabled,
            'requiredVisits': int.parse(_requiredVisitsController.text),
            'visitDiscountPercent': int.parse(
              _visitDiscountController.text,
            ),
            'orderRewardEnabled': _orderRewardEnabled,
            'minimumOrderAmount': int.parse(_minimumOrderController.text),
            'orderDiscountPercent': int.parse(
              _orderDiscountController.text,
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      _showMessage('Đã lưu chính sách tích lũy.', false);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(_firebaseErrorMessage(error), true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
      ),
    );
  }

  String _firebaseErrorMessage(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Không đủ quyền lưu cấu hình. Hãy deploy Firestore Rules mới và kiểm tra tài khoản admin.';
    }
    return error.message ?? 'Không thể lưu cấu hình tích lũy.';
  }

  String _formatPrice(int price) {
    final value = price.toString();
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) result.write('.');
      result.write(value[index]);
    }
    return '$resultđ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý tích điểm',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_barbershop_background.jpg',
            fit: BoxFit.cover,
          ),
          const ColoredBox(color: Color(0xED08111E)),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _gold))
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _headerCard(),
                        const SizedBox(height: 16),
                        _visitSettingsCard(),
                        const SizedBox(height: 16),
                        _orderSettingsCard(),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor: _ink,
                            ),
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _isSaving ? 'Đang lưu...' : 'Lưu chính sách',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: _gold, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chính sách thưởng khách hàng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Hai chính sách hoạt động độc lập khi admin đánh dấu lịch hẹn đã hoàn thành. Nếu khách đồng thời đạt cả hai điều kiện, khách sẽ nhận hai voucher riêng.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _visitSettingsCard() {
    final visits = int.tryParse(_requiredVisitsController.text) ?? 10;
    final discount = int.tryParse(_visitDiscountController.text) ?? 25;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _gold,
            secondary: const Icon(Icons.repeat_rounded, color: _gold),
            title: const Text(
              'Theo số lần hoàn thành dịch vụ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Cấp voucher sau mỗi số lần dịch vụ đã đặt.',
              style: TextStyle(color: _muted),
            ),
            value: _visitRewardEnabled,
            onChanged: (value) => setState(() => _visitRewardEnabled = value),
          ),
          const SizedBox(height: 14),
          _numberField(
            controller: _requiredVisitsController,
            label: 'Số lần hoàn thành dịch vụ',
            icon: Icons.event_repeat_rounded,
            minimum: 1,
          ),
          const SizedBox(height: 14),
          _numberField(
            controller: _visitDiscountController,
            label: 'Phần trăm giảm theo số lần',
            icon: Icons.percent_rounded,
            minimum: 1,
            maximum: 100,
            suffix: '%',
          ),
          const SizedBox(height: 14),
          _policyPreview(
            enabled: _visitRewardEnabled,
            message:
                'Sau mỗi $visits lần hoàn thành, khách nhận voucher giảm $discount%.',
          ),
        ],
      ),
    );
  }

  Widget _orderSettingsCard() {
    final minimum = int.tryParse(_minimumOrderController.text) ?? 500000;
    final discount = int.tryParse(_orderDiscountController.text) ?? 10;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _gold,
            secondary: const Icon(Icons.payments_outlined, color: _gold),
            title: const Text(
              'Theo giá trị đơn hàng',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Cấp voucher cho từng đơn đạt giá trị tối thiểu.',
              style: TextStyle(color: _muted),
            ),
            value: _orderRewardEnabled,
            onChanged: (value) => setState(() => _orderRewardEnabled = value),
          ),
          const SizedBox(height: 14),
          _numberField(
            controller: _minimumOrderController,
            label: 'Giá trị đơn tối thiểu (VND)',
            icon: Icons.price_check_rounded,
            minimum: 1,
          ),
          const SizedBox(height: 14),
          _numberField(
            controller: _orderDiscountController,
            label: 'Phần trăm giảm theo giá trị đơn',
            icon: Icons.percent_rounded,
            minimum: 1,
            maximum: 100,
            suffix: '%',
          ),
          const SizedBox(height: 14),
          _policyPreview(
            enabled: _orderRewardEnabled,
            message:
                'Đơn từ ${_formatPrice(minimum)} nhận voucher giảm $discount%.',
          ),
        ],
      ),
    );
  }

  Widget _policyPreview({required bool enabled, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x331A2B25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? const Color(0x8859D38C)
              : const Color(0x446C7480),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: enabled ? const Color(0xFF59D38C) : _muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enabled ? message : 'Chính sách này đang tắt.',
              style: const TextStyle(color: _muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int minimum,
    int? maximum,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, icon).copyWith(suffixText: suffix),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final number = int.tryParse(value?.trim() ?? '');
        if (number == null || number < minimum) {
          return 'Vui lòng nhập số từ $minimum trở lên.';
        }
        if (maximum != null && number > maximum) {
          return 'Giá trị không được vượt quá $maximum.';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _gold),
      filled: true,
      fillColor: const Color(0xB30D1723),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x446C7480)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _gold),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  BoxDecoration _decoration({Color borderColor = const Color(0x55F6C768)}) {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor),
      boxShadow: const [
        BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 12)),
      ],
    );
  }
}
