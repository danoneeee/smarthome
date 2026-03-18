import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HousesScreen extends StatefulWidget {
  const HousesScreen({super.key});

  @override
  State<HousesScreen> createState() => _HousesScreenState();
}

class _HousesScreenState extends State<HousesScreen> {
  List<dynamic> _houses = [];
  List<dynamic> _rooms = [];
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
      final hRes = await api.get('/houses');
      final rRes = await api.get('/rooms');
      if (hRes.statusCode == 200) _houses = jsonDecode(hRes.body) as List<dynamic>? ?? [];
      if (rRes.statusCode == 200) _rooms = jsonDecode(rRes.body) as List<dynamic>? ?? [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addHouse() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый дом'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Адрес (необязательно)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.post('/houses', body: {
      'name': nameController.text.trim(),
      'address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
    });
    if (res.statusCode == 201 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дом создан')));
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode}')));
    }
  }

  Future<void> _addRoom() async {
    if (_houses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала добавьте дом')));
      return;
    }
    int? selectedHouseId = _houses.isNotEmpty ? (_houses[0] as Map)['id'] : null;
    final nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новая комната'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedHouseId,
                decoration: const InputDecoration(labelText: 'Дом', border: OutlineInputBorder()),
                items: _houses.map<DropdownMenuItem<int>>((h) {
                  final id = (h as Map)['id'] as int;
                  return DropdownMenuItem(value: id, child: Text((h['name'] ?? '').toString()));
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedHouseId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название комнаты', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || selectedHouseId == null) return;
    final api = context.read<AuthProvider>().authService.api;
    final res = await api.post('/rooms', body: {'house_id': selectedHouseId, 'name': nameController.text.trim()});
    if (res.statusCode == 201 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Комната создана')));
      _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${res.statusCode}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _houses.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.home_work_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('Нет домов', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  const Text('Нажмите + чтобы добавить дом или комнату', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _houses.length,
                itemBuilder: (_, i) {
                  final h = _houses[i] as Map<String, dynamic>;
                  final rooms = _rooms.where((r) => r['house_id'] == h['id']).toList();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(h['name'] ?? ''),
                      subtitle: Text((h['address'] ?? '').toString().isEmpty ? 'Комнаты: ${rooms.length}' : '${h['address']}\nКомнаты: ${rooms.length}'),
                      trailing: rooms.isEmpty ? null : Text(rooms.map((r) => r['name']).join(', '), style: const TextStyle(fontSize: 12)),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'room',
            onPressed: _addRoom,
            child: const Icon(Icons.door_front_door),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'house',
            onPressed: _addHouse,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
