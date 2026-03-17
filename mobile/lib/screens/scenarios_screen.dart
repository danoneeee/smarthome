import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  List<dynamic> _scenarios = [];
  List<dynamic> _devices = [];
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
      final sRes = await api.get('/scenarios');
      final dRes = await api.get('/devices');
      if (sRes.statusCode == 200) _scenarios = jsonDecode(sRes.body) as List<dynamic>? ?? [];
      if (dRes.statusCode == 200) _devices = jsonDecode(dRes.body) as List<dynamic>? ?? [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _actionLabels = {'turn_on': 'Включить', 'turn_off': 'Выключить', 'set_temperature': 'Установить температуру'};

  Future<void> _addScenario() async {
    if (_devices.isEmpty) {
      _load();
      if (_devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала добавьте устройства')));
        return;
      }
    }
    final nameController = TextEditingController();
    final actions = <Map<String, dynamic>>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новый сценарий'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Действия с устройствами', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...actions.asMap().entries.map((e) {
                  final a = e.value;
                  final devList = _devices.cast<Map<String, dynamic>>().where((d) => d['id'] == a['device_id']).toList();
                  final devName = devList.isNotEmpty ? (devList.first['name'] ?? '') : 'Устройство #${a['device_id']}';
                  final actionLabel = _actionLabels[a['action'] as String] ?? a['action'];
                  return ListTile(
                    dense: true,
                    title: Text('$devName → $actionLabel'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setDialogState(() => actions.removeAt(e.key)),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить действие'),
                  onPressed: () => _pickDeviceAction(ctx, setDialogState, actions),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.post('/scenarios', body: {
      'name': nameController.text.trim(),
      'trigger_type': 'manual',
      'device_actions': actions.map((a) => {'device_id': a['device_id'], 'action': a['action'], 'action_params': a['action_params']}).toList(),
    });
    if (res.statusCode == 201 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сценарий создан')));
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode}')));
    }
  }

  Future<void> _pickDeviceAction(BuildContext ctx, void Function(void Function()) setDialogState, List<Map<String, dynamic>> actions) async {
    int? deviceId;
    String action = 'turn_on';
    final tempController = TextEditingController(text: '20');
    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setPickState) => AlertDialog(
          title: const Text('Действие устройства'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: deviceId,
                decoration: const InputDecoration(labelText: 'Устройство', border: OutlineInputBorder()),
                items: _devices.map<DropdownMenuItem<int>>((d) {
                  final id = (d as Map)['id'] as int;
                  return DropdownMenuItem(value: id, child: Text((d['name'] ?? '').toString()));
                }).toList(),
                onChanged: (v) => setPickState(() => deviceId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: action,
                decoration: const InputDecoration(labelText: 'Действие', border: OutlineInputBorder()),
                items: ['turn_on', 'turn_off', 'set_temperature'].map((a) => DropdownMenuItem(value: a, child: Text(_actionLabels[a] ?? a))).toList(),
                onChanged: (v) => setPickState(() => action = v ?? 'turn_on'),
              ),
              if (action == 'set_temperature') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: tempController,
                  decoration: const InputDecoration(labelText: 'Значение температуры', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                if (deviceId != null) {
                  final params = action == 'set_temperature' ? {'value': num.tryParse(tempController.text) ?? 20} : null;
                  actions.add({'device_id': deviceId, 'action': action, 'action_params': params});
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    setDialogState(() {});
  }

  Future<void> _editScenario(Map<String, dynamic> s) async {
    final nameController = TextEditingController(text: (s['name'] ?? '').toString());
    List<Map<String, dynamic>> actions = List<Map<String, dynamic>>.from((s['device_actions'] as List<dynamic>? ?? []).map((a) => Map<String, dynamic>.from(a as Map)));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Редактировать сценарий'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Действия с устройствами', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...actions.asMap().entries.map((e) {
                  final a = e.value;
                  final devList = _devices.cast<Map<String, dynamic>>().where((d) => d['id'] == a['device_id']).toList();
                  final devName = devList.isNotEmpty ? (devList.first['name'] ?? '') : 'Устройство #${a['device_id']}';
                  final actionLabel = _actionLabels[a['action'] as String] ?? a['action'];
                  return ListTile(
                    dense: true,
                    title: Text('$devName → $actionLabel'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setDialogState(() => actions.removeAt(e.key)),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить действие'),
                  onPressed: () => _pickDeviceAction(ctx, setDialogState, actions),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.patch('/scenarios/${s['id']}', body: {
      'name': nameController.text.trim(),
      'device_actions': actions.map((a) => {'device_id': a['device_id'], 'action': a['action'], 'action_params': a['action_params']}).toList(),
    });
    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сценарий обновлён')));
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode}')));
    }
  }

  Future<void> _run(int id) async {
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.post('/scenarios/$id/run');
    if (!mounted) return;
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      final msg = data['message'] ?? 'Сценарий выполнен';
      final details = results.map((r) {
        final m = r as Map<String, dynamic>;
        final name = m['device_name'] ?? 'Устройство #${m['device_id']}';
        final action = _actionLabels[m['action']] ?? m['action'];
        final st = m['status'] == 'mqtt_sent' ? 'MQTT' : 'OK';
        return '$name: $action [$st]';
      }).join('\n');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF00D4AA), size: 40),
          title: Text(msg),
          content: Text(details, style: const TextStyle(fontSize: 13)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _scenarios.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.auto_awesome_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('Нет сценариев', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  const Text('Нажмите + чтобы создать сценарий', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _scenarios.length,
                itemBuilder: (_, i) {
                  final s = _scenarios[i] as Map<String, dynamic>;
                  final actions = s['device_actions'] as List<dynamic>? ?? [];
                  final actionTexts = actions.map((a) {
                    final m = a as Map<String, dynamic>;
                    final devList = _devices.cast<Map<String, dynamic>>().where((d) => d['id'] == m['device_id']).toList();
                    final devName = devList.isNotEmpty ? (devList.first['name'] ?? '') : 'Устройство';
                    final label = _actionLabels[m['action'] as String] ?? m['action'];
                    return '$devName: $label';
                  }).toList();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editScenario(s),
                              ),
                              FilledButton(
                                onPressed: () => _run(s['id']),
                                child: const Text('Выполнить'),
                              ),
                            ],
                          ),
                          if (actionTexts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(actionTexts.join(' • '), style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addScenario,
        child: const Icon(Icons.add),
      ),
    );
  }
}
