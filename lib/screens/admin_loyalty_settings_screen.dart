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
  final _discountController = TextEditingController(text: '25');
  LoyaltyRewardType _rewardType = LoyaltyRewardType.visitCount;
  bool _isEnabled = true;
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
    _discountController.dispose();
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
        _isEnabled = settings.isEnabled;
        _rewardType = settings.rewardType;
        _requiredVisitsController.text = settings.requiredVisits.toString();
        _minimumOrderController.text = settings.minimumOrderAmount.toString();
        _discountController.text = settings.discountPercent.toString();
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(error.message ?? 'Không thể tải cấu hình tích lũy.', true);
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
            'isEnabled': _isEnabled,
            'rewardType': switch (_rewardType) {
              LoyaltyRewardType.visitCount => 'visit_count',
              LoyaltyRewardType.minimumOrder => 'minimum_order',
            },
            'requiredVisits': int.parse(_requiredVisitsController.text),
            'minimumOrderAmount': int.parse(_minimumOrderController.text),
            'discountPercent': int.parse(_discountController.text),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      _showMessage('Đã lưu chính sách tích lũy.', false);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? 'Không thể lưu cấu hình tích lũy.', true);
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

  String _formatPrice(int price) {
    final value = price.toString();
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) result.write('.');
      result.write(value[index]);
    }
    return '${result}đ';
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
                        _settingsCard(),
                        const SizedBox(height: 16),
                        _previewCard(),
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
            'Cấu hình này áp dụng khi admin đánh dấu một lịch hẹn là đã hoàn thành. Voucher đã cấp trước đó không bị thay đổi.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _gold,
            title: const Text(
              'Bật chương trình tích lũy',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Tắt để tạm ngừng cấp voucher mới.',
              style: TextStyle(color: _muted),
            ),
            value: _isEnabled,
            onChanged: (value) => setState(() => _isEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điều kiện nhận voucher',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<LoyaltyRewardType>(
            initialValue: _rewardType,
            dropdownColor: const Color(0xFF172230),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              'Cách tích lũy',
              Icons.tune_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: LoyaltyRewardType.visitCount,
                child: Text('Theo số lần hoàn thành dịch vụ'),
              ),
              DropdownMenuItem(
                value: LoyaltyRewardType.minimumOrder,
                child: Text('Theo giá trị của từng đơn hàng'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _rewardType = value);
            },
          ),
          const SizedBox(height: 14),
          if (_rewardType == LoyaltyRewardType.visitCount)
            _numberField(
              controller: _requiredVisitsController,
              label: 'Số lần sử dụng dịch vụ',
              icon: Icons.repeat_rounded,
              minimum: 1,
            )
          else
            _numberField(
              controller: _minimumOrderController,
              label: 'Giá trị đơn tối thiểu (VND)',
              icon: Icons.payments_outlined,
              minimum: 1,
            ),
          const SizedBox(height: 14),
          _numberField(
            controller: _discountController,
            label: 'Phần trăm giảm của voucher',
            icon: Icons.percent_rounded,
            minimum: 1,
            maximum: 100,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final visits = int.tryParse(_requiredVisitsController.text) ?? 10;
    final minimum = int.tryParse(_minimumOrderController.text) ?? 500000;
    final discount = int.tryParse(_discountController.text) ?? 25;
    final condition = _rewardType == LoyaltyRewardType.visitCount
        ? 'Sau mỗi $visits lần hoàn thành dịch vụ'
        : 'Mỗi đơn hoàn thành từ ${_formatPrice(minimum)}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoration(borderColor: const Color(0x8859D38C)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_outlined, color: Color(0xFF59D38C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xem trước chính sách',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$condition, khách hàng nhận một voucher giảm $discount% cho lần đặt lịch tiếp theo.',
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
              ],
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
