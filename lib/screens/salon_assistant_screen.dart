import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_salons.dart';
import '../models/barber.dart';
import '../models/salon_assistant_reply.dart';
import '../services/salon_assistant_service.dart';
import '../services/scheduling_service.dart';
import 'date_time_selection_screen.dart';

typedef AskSalonAssistant =
    Future<SalonAssistantReply> Function(
      String,
      Map<String, dynamic>,
      List<String>,
    );

class SalonAssistantScreen extends StatefulWidget {
  const SalonAssistantScreen({super.key, this.ask});
  final AskSalonAssistant? ask;
  @override
  State<SalonAssistantScreen> createState() => _SalonAssistantScreenState();
}

class _SalonAssistantScreenState extends State<SalonAssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({bool user, String text, SalonAssistantReply? reply})>[];
  final _questions = <String>[];
  final _conversation = <Map<String, String>>[];
  Map<String, dynamic> _context = {};
  bool _busy = false;
  bool _showPreferences = false;
  String? _error;
  late final AskSalonAssistant _ask = widget.ask ?? SalonAssistantService().ask;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? example]) async {
    final question = (example ?? _input.text).trim();
    if (_busy || question.isEmpty || question.length > 1200) return;
    final history = _questions.toList();
    setState(() {
      _busy = true;
      _error = null;
      _messages.add((user: true, text: question, reply: null));
      _input.clear();
    });
    _scrollToEnd();
    try {
      final reply = await _ask(question, {
        ..._context,
        'conversation': _conversation
            .map((turn) => Map<String, String>.of(turn))
            .toList(),
      }, history);
      if (!mounted) return;
      setState(() {
        _context = Map.of(reply.context);
        _messages.add((user: false, text: reply.message, reply: reply));
        _questions.add(question);
        if (_questions.length > 4) _questions.removeAt(0);
        _conversation.addAll([
          {'role': 'user', 'content': question},
          {'role': 'assistant', 'content': reply.message},
        ]);
        if (_conversation.length > 6) {
          _conversation.removeRange(0, _conversation.length - 6);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst(
          RegExp(r'^(Bad state: |Exception: )'),
          '',
        );
        _input.text = question;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(now.year, now.month, now.day);
    final previous = DateTime.tryParse('${_context['dateKey']}');
    final picked = await showDatePicker(
      context: context,
      initialDate: previous != null && !previous.isBefore(today)
          ? previous
          : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null && mounted) {
      setState(() => _context['dateKey'] = SchedulingService.dateKey(picked));
    }
  }

  void _book(SalonAssistantReply reply, Map<String, dynamic> employee) {
    final branch = sampleSalons
        .where((s) => s.id == reply.context['salonId'])
        .firstOrNull;
    if (branch == null || reply.services.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DateTimeSelectionScreen(
          salon: branch,
          selectedServices: reply.services,
          useAnyBarber: false,
          initialDate: DateTime.tryParse('${reply.context['dateKey']}'),
          selectedBarber: Barber(
            id: employee['employeeId'] as String,
            salonId: branch.id,
            name: employee['name'] as String,
            experienceYears: (employee['experienceYears'] as num).toInt(),
            rating: (employee['rating'] as num).toDouble(),
            reviewCount: (employee['reviewCount'] as num).toInt(),
          ),
        ),
      ),
    );
  }

  Widget _recommendation(
    SalonAssistantReply reply,
    Map<String, dynamic> employee,
  ) {
    final times = (employee['times'] as List).cast<String>();
    final matches = (employee['matchingServices'] as List).cast<String>();
    final periods = (employee['periods'] as List)
        .map((p) => '${p['start']}–${p['end']}')
        .join(', ');
    final count = employee['reviewCount'] as int;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${employee['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              '${employee['experienceYears']} năm kinh nghiệm · ${count == 0 ? 'Chưa có đánh giá' : '${(employee['rating'] as num).toStringAsFixed(1)} ★ ($count đánh giá)'}',
            ),
            if (employee['salonName'] case final String name
                when name.isNotEmpty)
              Text(name, style: Theme.of(context).textTheme.bodySmall),
            if (periods.isNotEmpty) Text('Ca làm: $periods'),
            if (reply.recommendationKind == 'expertise')
              const Text('Gợi ý theo chuyên môn · Chưa kiểm tra lịch làm'),
            if (matches.isNotEmpty)
              Text('Chuyên môn phù hợp: ${matches.join(', ')}')
            else if (reply.services.isNotEmpty)
              const Text('Hồ sơ chưa ghi rõ chuyên môn cho dịch vụ này.'),
            if (times.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Giờ bắt đầu còn trống:'),
              Wrap(
                spacing: 6,
                children: times
                    .take(8)
                    .map(
                      (time) => Chip(
                        label: Text(time),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
              if (times.length > 8)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Xem thêm ${times.length - 8} giờ'),
                  children: [
                    Wrap(
                      spacing: 6,
                      children: times
                          .skip(8)
                          .map((time) => Chip(label: Text(time)))
                          .toList(),
                    ),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: () => _book(reply, employee),
                icon: const Icon(Icons.event_available),
                label: const Text('Chọn giờ và đặt lịch'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFFE6B6),
              child: Icon(
                Icons.auto_awesome,
                size: 20,
                color: Color(0xFF182534),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trợ lý AI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Tư vấn tóc & lịch hẹn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _messages.clear();
                    _questions.clear();
                    _conversation.clear();
                    _context = {};
                    _error = null;
                    _input.clear();
                  }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.storefront_outlined,
                            size: 17,
                          ),
                          label: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width < 500
                                  ? MediaQuery.sizeOf(context).width - 140
                                  : 280,
                            ),
                            child: Text(
                              sampleSalons
                                      .where((s) => s.id == _context['salonId'])
                                      .firstOrNull
                                      ?.name ??
                                  'Chọn chi nhánh',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _showPreferences = !_showPreferences,
                                ),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _context['dateKey'] == null
                                ? 'Hôm nay'
                                : '${_context['dateKey']}'
                                      .split('-')
                                      .reversed
                                      .join('/'),
                          ),
                          onPressed: _busy ? null : _pickDate,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showPreferences)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_context['salonId']),
                          initialValue: _context['salonId'] as String?,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Chi nhánh muốn đến',
                            border: OutlineInputBorder(),
                          ),
                          items: sampleSalons
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _context['salonId'] = value),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _pickDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _context['dateKey'] == null
                                  ? 'Ngày: Hôm nay (giờ Việt Nam)'
                                  : 'Ngày: ${_context['dateKey']}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_messages.isEmpty) ...[
                        const Icon(Icons.auto_awesome, size: 42),
                        const SizedBox(height: 12),
                        const Text(
                          'Mình có thể giúp gì cho mái tóc của bạn?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bạn cứ hỏi tự nhiên. Mình sẽ giúp chọn dịch vụ, tìm thợ có chuyên môn phù hợp và xem lịch khi bạn cần.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final text in [
                              'Tôi muốn uốn tóc, thợ nào có chuyên môn phù hợp?',
                              'Giá các dịch vụ hiện tại là bao nhiêu?',
                              'Ngày mai có nhân viên nào làm?',
                            ])
                              ActionChip(
                                label: Text(text),
                                onPressed: _busy ? null : () => _send(text),
                              ),
                          ],
                        ),
                      ],
                      for (final entry in _messages)
                        Align(
                          alignment: entry.user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: entry.user
                                  ? const Color(0xFFFFE2AA)
                                  : Colors.white,
                              border: entry.user
                                  ? null
                                  : Border.all(color: const Color(0xFFE6E9EF)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!entry.user) ...[
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 16,
                                        color: Color(0xFFAC7725),
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Trợ lý salon',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                SelectableText(
                                  entry.text,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.65,
                                    color: Color(0xFF172333),
                                  ),
                                ),
                                if (entry.reply case final reply?) ...[
                                  for (final employee in reply.recommendations)
                                    _recommendation(reply, employee),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Đã tra dữ liệu lúc ${reply.checkedAt.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(11, 16)} · giờ Việt Nam',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Sao chép câu trả lời',
                                        iconSize: 16,
                                        onPressed: () => Clipboard.setData(
                                          ClipboardData(text: reply.message),
                                        ),
                                        icon: const Icon(Icons.copy_outlined),
                                      ),
                                    ],
                                  ),
                                  if (reply.recommendations.any(
                                    (p) =>
                                        (p['times'] as List?)?.isNotEmpty ??
                                        false,
                                  ))
                                    const Text(
                                      'Giờ đang hiển thị chưa được giữ chỗ; mình sẽ kiểm tra lại khi bạn đặt lịch.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  if (entry == _messages.last &&
                                      !_busy &&
                                      reply.suggestedQuestions.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: reply.suggestedQuestions
                                          .map(
                                            (question) => ActionChip(
                                              label: Text(question),
                                              onPressed: () => _send(question),
                                              avatar: const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 15,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (_busy)
                        const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Mình đang xem thông tin cho bạn…'),
                            ),
                          ],
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          enabled: !_busy,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          maxLength: 1200,
                          decoration: const InputDecoration(
                            hintText: 'Nhắn cho trợ lý salon…',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Gửi câu hỏi',
                        onPressed: _busy ? null : () => _send(),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
