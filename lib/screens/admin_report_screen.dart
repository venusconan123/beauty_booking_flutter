import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminReportScreen extends StatelessWidget {
  const AdminReportScreen({super.key});

  static const _ink = Color(0xFF071426);
  static const _panel = Color(0xFF10233B);
  static const _gold = Color(0xFFF4C567);
  static const _muted = Color(0xFFABB8C9);

  Future<void> _resolve(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    await reference.update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đánh dấu báo cáo là đã xử lý.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Xóa báo cáo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Báo cáo này sẽ bị xóa khỏi hệ thống.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý báo cáo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _gold),
            );
          }
          final reports = [...snapshot.data!.docs];
          reports.sort((first, second) {
            final firstTime =
                (first.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final secondTime =
                (second.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return secondTime.compareTo(firstTime);
          });
          if (reports.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có báo cáo nào.',
                style: TextStyle(color: _muted),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final data = report.data();
                  final resolved = data['status'] == 'resolved';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: resolved
                            ? const Color(0x555DDB91)
                            : const Color(0x66F4C567),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: resolved
                              ? const Color(0x225DDB91)
                              : const Color(0x22F4C567),
                          foregroundColor: resolved
                              ? const Color(0xFF5DDB91)
                              : _gold,
                          child: Icon(
                            resolved
                                ? Icons.task_alt_rounded
                                : Icons.flag_rounded,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['type'] == 'employee'
                                    ? 'Báo cáo nhân viên'
                                    : 'Báo cáo đánh giá',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                data['targetName']?.toString() ?? '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data['salonName']?.toString() ?? '',
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: _panel,
                          iconColor: Colors.white,
                          onSelected: (value) {
                            if (value == 'resolve') {
                              _resolve(context, report.reference);
                            } else {
                              _delete(context, report.reference);
                            }
                          },
                          itemBuilder: (_) => [
                            if (!resolved)
                              const PopupMenuItem(
                                value: 'resolve',
                                child: Text(
                                  'Đánh dấu đã xử lý',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Xóa báo cáo',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

