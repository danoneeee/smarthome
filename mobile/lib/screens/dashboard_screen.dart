import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _devices = [];
  List<dynamic> _houses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dRes = await api.get('/devices');
      final hRes = await api.get('/houses');
      if (dRes.statusCode == 200 && hRes.statusCode == 200) {
        setState(() {
          _devices = jsonDecode(dRes.body) as List<dynamic>? ?? [];
          _houses = jsonDecode(hRes.body) as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Ошибка: $_error'));
    }

    final online = _devices.where((d) => d['status'] == 'online').length;
    // Группировка по room_id (разные комнаты с одинаковым именем не сливаются)
    final byRoomId = <int?, List<dynamic>>{};
    for (final d in _devices) {
      final rid = d['room_id'] as int?;
      byRoomId.putIfAbsent(rid, () => []).add(d);
    }
    // Название комнаты для отображения
    String roomTitle(int? rid, List<dynamic> devs) {
      if (rid == null) return 'Без комнаты';
      final first = devs.isNotEmpty ? devs.first : null;
      return first?['room_name'] as String? ?? 'Комната #$rid';
    }
    final entries = byRoomId.entries.toList()
      ..sort((a, b) {
        final na = roomTitle(a.key, a.value);
        final nb = roomTitle(b.key, b.value);
        if (na == 'Без комнаты') return 1;
        if (nb == 'Без комнаты') return -1;
        return na.compareTo(nb);
      });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _statCard('Устройств', _devices.length.toString()),
              const SizedBox(width: 12),
              _statCard('Онлайн', online.toString()),
              const SizedBox(width: 12),
              _statCard('Домов', _houses.length.toString()),
            ],
          ),
          const SizedBox(height: 24),
          Text('Устройства по комнатам', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final title = roomTitle(e.key, e.value);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.door_front_door_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...e.value.map((d) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 8,
                            backgroundColor: d['status'] == 'online' ? const Color(0xFF00D4AA) : Colors.grey,
                          ),
                          title: Text(d['name'] ?? ''),
                          subtitle: Text(d['device_type']?['category'] ?? d['device_type']?['name'] ?? ''),
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(value, style: const TextStyle(color: Color(0xFF00D4AA), fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
