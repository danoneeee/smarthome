import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DeviceLogScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;
  const DeviceLogScreen({super.key, required this.deviceId, required this.deviceName});

  @override
  State<DeviceLogScreen> createState() => _DeviceLogScreenState();
}

class _DeviceLogScreenState extends State<DeviceLogScreen> {
  List<Map<String, dynamic>> _events = [];
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
      final res = await api.get('/devices/${widget.deviceId}/log?limit=100');
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List<dynamic>? ?? [];
        _events = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  static const _typeIcons = {
    'command': Icons.send,
    'scenario': Icons.auto_awesome,
    'energy': Icons.bolt,
    'state': Icons.sync,
  };
  static const _typeColors = {
    'command': Color(0xFF4FC3F7),
    'scenario': Color(0xFFBA68C8),
    'energy': Color(0xFFFFD54F),
    'state': Color(0xFF81C784),
  };
  static const _typeLabels = {
    'command': 'Команда',
    'scenario': 'Сценарий',
    'energy': 'Энергия',
    'state': 'Состояние',
  };
  static const _actionLabels = {
    'turn_on': 'Включение',
    'turn_off': 'Выключение',
    'set_temperature': 'Установка температуры',
  };

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    String s = iso.trim();
    // Бэкенд отдаёт UTC (+00:00 или Z). Если нет суффикса — считаем UTC.
    final hasTz = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
    if (!hasTz) s = '${s}Z';
    final dt = DateTime.tryParse(s);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusChip(String? value, String eventType) {
    if (eventType == 'energy') {
      return Text('${value ?? '0'} кВт·ч', style: const TextStyle(fontSize: 12, color: Color(0xFFFFD54F)));
    }
    final isOk = value == 'mqtt_sent' || value == 'applied';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isOk ? Icons.check_circle : Icons.info_outline, size: 14,
            color: isOk ? const Color(0xFF00D4AA) : Colors.white54),
        const SizedBox(width: 4),
        Text(
          value == 'mqtt_sent' ? 'MQTT отправлено' : value == 'applied' ? 'Применено' : (value ?? ''),
          style: TextStyle(fontSize: 11, color: isOk ? const Color(0xFF00D4AA) : Colors.white54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Журнал: ${widget.deviceName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _events.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 80),
                      Icon(Icons.history, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('Нет событий', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _events.length,
                      itemBuilder: (_, i) {
                        final e = _events[i];
                        final type = (e['event_type'] ?? '') as String;
                        final icon = _typeIcons[type] ?? Icons.circle;
                        final color = _typeColors[type] ?? Colors.grey;
                        final actionName = _actionLabels[e['name']] ?? (e['name'] ?? '');
                        final typeLabel = _typeLabels[type] ?? type;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.2),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(actionName, style: const TextStyle(fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['description'] ?? typeLabel,
                                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                const SizedBox(height: 4),
                                _statusChip(e['value'], type),
                              ],
                            ),
                            trailing: Text(_formatTime(e['created_at']),
                                style: const TextStyle(fontSize: 11, color: Colors.white54)),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
