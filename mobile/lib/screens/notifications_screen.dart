import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    setState(() => _loading = true);
    try {
      final res = await api.get('/notifications?limit=50');
      if (res.statusCode == 200 && mounted) _list = jsonDecode(res.body) as List<dynamic>? ?? [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    final api = context.read<AuthProvider>().authService.api;
    await api.patch('/notifications/$id/read');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: _list.isEmpty
          ? const Center(child: Text('Нет уведомлений'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final n = _list[i] as Map<String, dynamic>;
                final isRead = n['is_read'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isRead ? null : Colors.white12,
                  child: ListTile(
                    title: Text(n['title'] ?? 'Уведомление', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: n['body'] != null ? Text(n['body']) : null,
                    trailing: isRead ? null : TextButton(onPressed: () => _markRead(n['id']), child: const Text('Прочитано')),
                  ),
                );
              },
            ),
    );
  }
}
