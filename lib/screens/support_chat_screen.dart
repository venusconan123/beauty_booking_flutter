import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SupportChatScreen extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? customerEmail;

  const SupportChatScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.customerEmail,
  });

  bool get isAdminMode => customerId != null;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const Color _ink = Color(0xFF090E14);
  static const Color _panel = Color(0xFF111923);
  static const Color _gold = Color(0xFFF0C36A);
  static const Color _cream = Color(0xFFF5EFE5);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _customerId => widget.customerId ?? _currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _chatReference =>
      FirebaseFirestore.instance.collection('support_chats').doc(_customerId);

  @override
  void initState() {
    super.initState();
    _markConversationRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markConversationRead() async {
    if (_customerId.isEmpty) return;
    try {
      await _chatReference.set({
        'userId': _customerId,
        if (widget.isAdminMode) 'unreadForAdmin': false,
        if (!widget.isAdminMode) 'unreadForUser': false,
      }, SetOptions(merge: true));
    } catch (_) {
      // Cuộc trò chuyện có thể chưa được tạo; lần gửi đầu tiên sẽ tạo dữ liệu.
    }
  }

  Future<void> _sendMessage() async {
    final user = _currentUser;
    final content = _messageController.text.trim();
    if (user == null || _customerId.isEmpty || content.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final messageReference = _chatReference.collection('messages').doc();
      final batch = FirebaseFirestore.instance.batch();
      final customerName = widget.customerName?.trim().isNotEmpty == true
          ? widget.customerName!.trim()
          : widget.isAdminMode
          ? 'Khách hàng'
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : user.email?.split('@').first ?? 'Khách hàng');
      final customerEmail = widget.customerEmail ?? user.email ?? '';

      batch.set(_chatReference, {
        'userId': _customerId,
        'userName': customerName,
        'userEmail': customerEmail,
        'lastMessage': content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.isAdminMode) 'unreadForUser': true,
        if (widget.isAdminMode) 'unreadForAdmin': false,
        if (!widget.isAdminMode) 'unreadForAdmin': true,
        if (!widget.isAdminMode) 'unreadForUser': false,
      }, SetOptions(merge: true));
      batch.set(messageReference, {
        'senderId': user.uid,
        'senderRole': widget.isAdminMode ? 'admin' : 'user',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _messageController.clear();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi tin nhắn: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Đang gửi...';
    final date = timestamp.toDate().toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.hour)}:${twoDigits(date.minute)} '
        '${twoDigits(date.day)}/${twoDigits(date.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null || _customerId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập.')));
    }

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAdminMode
                  ? (widget.customerName ?? 'Khách hàng')
                  : 'Chat với admin',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.isAdminMode
                  ? (widget.customerEmail ?? '')
                  : 'Hỗ trợ đặt lịch và dịch vụ',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.support_agent_rounded, color: _gold),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatReference
                      .collection('messages')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Không thể tải tin nhắn. Hãy kiểm tra Firestore Rules.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data?.docs ?? [];
                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: Color(0x1FF0C36A),
                                child: Icon(
                                  Icons.forum_outlined,
                                  color: _gold,
                                  size: 34,
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Chưa có tin nhắn',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Hãy gửi tin nhắn đầu tiên để bắt đầu cuộc trò chuyện.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data();
                        final mine = data['senderId'] == user.uid;
                        final senderRole = data['senderRole']?.toString();
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 560),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                            decoration: BoxDecoration(
                              color: mine ? _panel : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(17),
                                topRight: const Radius.circular(17),
                                bottomLeft: Radius.circular(mine ? 17 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 17),
                              ),
                              border: Border.all(
                                color: mine
                                    ? const Color(0x55F0C36A)
                                    : const Color(0x16090E14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(
                                    senderRole == 'admin' ? 'Admin' : 'Khách hàng',
                                    style: const TextStyle(
                                      color: _gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                Text(
                                  data['content']?.toString() ?? '',
                                  style: TextStyle(
                                    color: mine ? Colors.white : _ink,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(data['createdAt'] as Timestamp?),
                                  style: TextStyle(
                                    color: mine ? Colors.white54 : Colors.black45,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color(0x18000000), blurRadius: 16),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: widget.isAdminMode
                              ? 'Nhập nội dung trả lời...'
                              : 'Nhập tin nhắn cho admin...',
                          filled: true,
                          fillColor: const Color(0xFFF3F4F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Gửi tin nhắn',
                      onPressed: _isSending ? null : _sendMessage,
                      style: IconButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _ink,
                        padding: const EdgeInsets.all(15),
                      ),
                      icon: _isSending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
