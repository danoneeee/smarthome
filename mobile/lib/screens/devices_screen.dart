import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'device_log_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<dynamic> _devices = [];
  List<dynamic> _deviceTypes = [];
  List<dynamic> _rooms = [];
  bool _loading = true;
  int? _filterRoomId;
  bool _loadingCommand = false;

  @override
  void initState() {
    super.initState();
    _load();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future<void> refresh() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      await _load(silent: true);
      if (mounted) refresh();
    }
    refresh();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    if (!silent) setState(() => _loading = true);
    try {
      final dRes = await api.get('/devices');
      final tRes = silent ? null : await api.get('/devices/types');
      final rRes = silent ? null : await api.get('/rooms');
      if (dRes.statusCode == 200) _devices = jsonDecode(dRes.body) as List<dynamic>? ?? [];
      if (tRes != null && tRes.statusCode == 200) {
        final decoded = jsonDecode(tRes.body);
        _deviceTypes = decoded is List ? decoded : [];
      }
      if (rRes != null && rRes.statusCode == 200) _rooms = jsonDecode(rRes.body) as List<dynamic>? ?? [];
    } catch (_) {}
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _addDevice() async {
    final nameController = TextEditingController();
    List<dynamic> dialogTypes = List.from(_deviceTypes);
    List<dynamic> dialogRooms = List.from(_rooms);
    if (dialogTypes.isEmpty || dialogRooms.isEmpty) {
      final api = context.read<AuthProvider>().authService.api;
      String? typesError;
      try {
        if (dialogTypes.isEmpty) {
          final tRes = await api.get('/devices/types');
          if (tRes.statusCode == 200) {
            final decoded = jsonDecode(tRes.body);
            if (decoded is List) {
              dialogTypes = decoded;
            } else {
              typesError = 'Неверный формат ответа';
            }
          } else {
            typesError = 'Сервер: ${tRes.statusCode}';
          }
        }
        if (dialogRooms.isEmpty && typesError == null) {
          final rRes = await api.get('/rooms');
          if (rRes.statusCode == 200) dialogRooms = jsonDecode(rRes.body) as List<dynamic>? ?? [];
        }
      } catch (e) {
        typesError = 'Подключение: ${e.toString().split('\n').first}';
      }
      if (!mounted) return;
      if (dialogTypes.isEmpty) {
        final baseUrl = api.baseUrl;
        final hint = typesError != null
            ? '$typesError\nURL: $baseUrl\nПерезапустите приложение (Stop → Run). Backend: ./run.sh в папке backend.'
            : 'Не удалось загрузить типы устройств. Проверьте сервер и повторите.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hint),
          duration: const Duration(seconds: 6),
        ));
        return;
      }
    }
    int? typeId;
    final firstId = dialogTypes.isNotEmpty ? (dialogTypes[0] as Map)['id'] : null;
    if (firstId != null) typeId = firstId is int ? firstId : int.tryParse(firstId.toString());
    int? roomId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новое устройство'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: typeId,
                  decoration: const InputDecoration(labelText: 'Тип', border: OutlineInputBorder()),
                  items: dialogTypes.map<DropdownMenuItem<int>>((t) {
                    final raw = (t as Map)['id'];
                    final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '0') ?? 0;
                    final label = (t['category'] ?? t['name'] ?? id).toString();
                    return DropdownMenuItem<int>(value: id, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setDialogState(() => typeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: roomId,
                  decoration: const InputDecoration(labelText: 'Комната (необязательно)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('— Без комнаты —')),
                    ...dialogRooms.map<DropdownMenuItem<int?>>((r) {
                      final raw = (r as Map)['id'];
                      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '0') ?? 0;
                      return DropdownMenuItem<int?>(value: id, child: Text((r['name'] ?? '').toString()));
                    }),
                  ],
                  onChanged: (v) => setDialogState(() => roomId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || typeId == null) return;
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.post('/devices', body: {
      'name': nameController.text.trim(),
      'type_id': typeId,
      if (roomId != null) 'room_id': roomId,
    });
    if (res.statusCode == 201 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Устройство добавлено')));
      _load();
    } else {
      final body = res.body;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode} ${body.length > 80 ? body.substring(0, 80) : body}')));
    }
  }

  Future<void> _sendCommand(int deviceId, String command) async {
    if (_loadingCommand) return;
    setState(() => _loadingCommand = true);
    final api = context.read<AuthProvider>().authService.api;
    try {
      final res = await api.post('/devices/$deviceId/command', body: {'command': command});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.statusCode == 200 ? 'Команда отправлена' : 'Ошибка ${res.statusCode}'),
          duration: const Duration(seconds: 2),
        ));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loadingCommand = false);
    }
  }

  Future<void> _editDevice(Map<String, dynamic> d) async {
    final nameController = TextEditingController(text: (d['name'] ?? '').toString());
    int? roomId = d['room_id'] as int?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Редактировать устройство'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: roomId,
                  decoration: const InputDecoration(labelText: 'Комната', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('— Без комнаты —')),
                    ..._rooms.map<DropdownMenuItem<int>>((r) {
                      final id = (r as Map)['id'] as int;
                      return DropdownMenuItem(value: id, child: Text((r['name'] ?? '').toString()));
                    }),
                  ],
                  onChanged: (v) => setDialogState(() => roomId = v),
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
    final res = await api.patch('/devices/${d['id']}', body: {
      'name': nameController.text.trim(),
      'room_id': roomId,
    });
    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Устройство обновлено')));
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode}')));
    }
  }

  Future<void> _deleteDevice(Map<String, dynamic> d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить устройство?'),
        content: Text('Устройство «${d['name']}» будет удалено.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.delete('/devices/${d['id']}');
    if (res.statusCode == 204 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Устройство удалено')));
      _load();
    }
  }

  static const int _allRoomsId = 0;

  List<dynamic> get _filteredDevices {
    if (_filterRoomId == null || _filterRoomId == _allRoomsId) return _devices;
    return _devices.where((d) => d['room_id'] == _filterRoomId).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final list = _filteredDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Устройства'),
        actions: [
          PopupMenuButton<int?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Фильтр по комнате',
            onSelected: (v) => setState(() => _filterRoomId = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('Все комнаты')),
              ..._rooms.map<PopupMenuItem<int?>>((r) {
                final id = (r as Map)['id'] as int;
                return PopupMenuItem(value: id, child: Text((r['name'] ?? '').toString()));
              }),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: list.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.smart_toy_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('Нет устройств', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  const Text('Нажмите + чтобы добавить устройство', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final d = list[i] as Map<String, dynamic>;
                  final supports = (d['device_type']?['supported_commands'] as List<dynamic>?) ?? [];
                  final canSwitch = supports.contains('turn_on') || supports.contains('turn_off');

                  final meta = (d['metadata_'] ?? d['metadata']) as Map<String, dynamic>? ?? {};
                  final state = meta['state'] as String?;
                  final isOn = state == 'on';
                  final lastSeen = d['last_seen'] as String?;
                  String lastSeenText = '';
                  if (lastSeen != null) {
                    String ls = lastSeen.trim();
                    if (!ls.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(ls)) ls = '${ls}Z';
                    final dt = DateTime.tryParse(ls);
                    if (dt != null) {
                      final local = dt.toLocal();
                      final diff = DateTime.now().difference(local);
                      if (diff.inMinutes < 1) {
                        lastSeenText = 'только что';
                      } else if (diff.inMinutes < 60) {
                        lastSeenText = '${diff.inMinutes} мин назад';
                      } else if (diff.inHours < 24) {
                        lastSeenText = '${diff.inHours} ч назад';
                      } else {
                        lastSeenText = '${local.day}.${local.month.toString().padLeft(2, '0')} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
                      }
                    }
                  }

                  void openLog() {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DeviceLogScreen(deviceId: d['id'] as int, deviceName: (d['name'] ?? '').toString()),
                    ));
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Строка 1: название + меню
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: openLog,
                                  child: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (v) {
                                  if (v == 'edit') _editDevice(d);
                                  if (v == 'delete') _deleteDevice(d);
                                  if (v == 'log') openLog();
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'log', child: Text('Журнал активности')),
                                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                                ],
                              ),
                            ],
                          ),
                          // Строка 2: тип · комната · время
                          Row(
                            children: [
                              Text(d['device_type']?['category'] ?? d['device_type']?['name'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              if (d['room_name'] != null) ...[
                                const Text(' · ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                Text(d['room_name'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                              const Spacer(),
                              if (lastSeenText.isNotEmpty)
                                Text(lastSeenText, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                            ],
                          ),
                          if (canSwitch) ...[
                            const SizedBox(height: 10),
                            // Строка 3: кнопки Вкл/Выкл — подсвечена активная
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _loadingCommand ? null : () => _sendCommand(d['id'], 'turn_on'),
                                    icon: Icon(Icons.power_settings_new, size: 16, color: isOn ? Colors.black87 : Colors.white54),
                                    label: const Text('Вкл'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: isOn ? const Color(0xFF00D4AA) : Colors.white12,
                                      foregroundColor: isOn ? Colors.black87 : Colors.white54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _loadingCommand ? null : () => _sendCommand(d['id'], 'turn_off'),
                                    icon: Icon(Icons.power_off, size: 16, color: !isOn ? Colors.black87 : Colors.white54),
                                    label: const Text('Выкл'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: !isOn ? const Color(0xFF00D4AA) : Colors.white12,
                                      foregroundColor: !isOn ? Colors.black87 : Colors.white54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.history, color: Colors.white54, size: 20),
                                  tooltip: 'Журнал',
                                  onPressed: openLog,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDevice,
        child: const Icon(Icons.add),
      ),
    );
  }
}
