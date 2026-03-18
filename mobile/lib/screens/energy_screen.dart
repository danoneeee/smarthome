import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _days = 30;

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
      final res = await api.get('/energy/summary?days=$_days');
      if (res.statusCode == 200 && mounted) {
        setState(() => _data = jsonDecode(res.body) as Map<String, dynamic>?);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const Center(child: Text('Нет данных'));

    final totalKwh = (_data!['total_kwh'] as num?)?.toDouble() ?? 0;
    final totalCost = (_data!['total_cost_rub'] as num?)?.toDouble() ?? 0;
    final savingPct = (_data!['saving_percent'] as num?)?.toDouble() ?? 0;
    final byCategory = _data!['by_category'] as Map<String, dynamic>? ?? {};
    final byDevice = _data!['by_device'] as List<dynamic>? ?? [];

    final categoryIcons = {
      'Освещение': Icons.lightbulb_outline,
      'Розетки': Icons.power,
      'Климат': Icons.thermostat_outlined,
      'Датчики': Icons.sensors,
      'Безопасность': Icons.security,
    };
    final categoryColors = {
      'Освещение': const Color(0xFFFFD54F),
      'Розетки': const Color(0xFF4FC3F7),
      'Климат': const Color(0xFFFF8A65),
      'Датчики': const Color(0xFF81C784),
      'Безопасность': const Color(0xFFBA68C8),
    };

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Период
            Row(
              children: [
                const Text('Период:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('7 дней'), selected: _days == 7, onSelected: (_) { _days = 7; _load(); }),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('30 дней'), selected: _days == 30, onSelected: (_) { _days = 30; _load(); }),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('90 дней'), selected: _days == 90, onSelected: (_) { _days = 90; _load(); }),
              ],
            ),
            const SizedBox(height: 16),

            // Итого
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Потребление', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('${totalKwh.toStringAsFixed(1)} кВт·ч', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00D4AA))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Стоимость', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('${totalCost.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (savingPct != 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(savingPct > 0 ? Icons.trending_down : Icons.trending_up,
                              color: savingPct > 0 ? const Color(0xFF00D4AA) : Colors.redAccent, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            savingPct > 0
                                ? 'Экономия ${savingPct.abs().toStringAsFixed(1)}% по сравнению с прошлым периодом'
                                : 'Расход вырос на ${savingPct.abs().toStringAsFixed(1)}% по сравнению с прошлым периодом',
                            style: TextStyle(
                              color: savingPct > 0 ? const Color(0xFF00D4AA) : Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // По категориям
            Text('По категориям', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...byCategory.entries.map((e) {
              final cat = e.key;
              final kwh = (e.value as num).toDouble();
              final pct = totalKwh > 0 ? (kwh / totalKwh * 100) : 0.0;
              final icon = categoryIcons[cat] ?? Icons.device_unknown;
              final color = categoryColors[cat] ?? Colors.grey;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
                  title: Text(cat),
                  subtitle: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.white12, color: color, minHeight: 6),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${kwh.toStringAsFixed(1)} кВт·ч', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // По устройствам
            Text('По устройствам', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...byDevice.map((d) {
              final m = d as Map<String, dynamic>;
              final kwh = (m['kwh'] as num?)?.toDouble() ?? 0;
              final cost = (m['cost_rub'] as num?)?.toDouble() ?? 0;
              final watts = (m['power_watts'] as num?)?.toInt() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(m['device_name'] ?? ''),
                  subtitle: Text('${m['category'] ?? ''} · $watts Вт'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${kwh.toStringAsFixed(1)} кВт·ч', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${cost.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
