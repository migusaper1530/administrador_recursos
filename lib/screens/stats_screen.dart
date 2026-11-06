import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers_db/database_helper.dart';
import '../modelos/modelo_categoria.dart';
import '../widgets/ui.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _db = DatabaseHelper.instance;
  int? _categoriaId;
  String? _tipo;
  String _reporte = 'MOVIMIENTOS';
  bool _soloActivos = false;
  DateTimeRange? _rango;
  late Future<List<Object>> _future;

  String? get _desde =>
      _rango == null ? null : DateFormat('yyyy-MM-dd').format(_rango!.start);
  String? get _hasta =>
      _rango == null ? null : DateFormat('yyyy-MM-dd').format(_rango!.end);

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final reporte = _reporte == 'INVENTARIO'
        ? _db.reporteInventario(
            categoriaId: _categoriaId,
            soloActivos: _soloActivos,
            soloBajo: false,
          )
        : _db.movimientos(
            desde: _desde,
            hasta: _hasta,
            categoriaId: _categoriaId,
            tipo: _tipo,
            limite: 100,
          );
    setState(() {
      _future = Future.wait<Object>([
        _db.resumen(
          desde: _reporte == 'MOVIMIENTOS' ? _desde : null,
          hasta: _reporte == 'MOVIMIENTOS' ? _hasta : null,
          categoriaId: _categoriaId,
          tipo: _reporte == 'MOVIMIENTOS' ? _tipo : null,
        ),
        reporte,
        _db.categorias(soloActivas: true),
      ]);
    });
  }

  Future<void> _elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _rango,
    );
    if (rango != null) {
      _rango = rango;
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final resumen = snapshot.data![0] as Map<String, int>;
        final reporte = snapshot.data![1] as List<Map<String, dynamic>>;
        final categorias = snapshot.data![2] as List<ModeloCategoria>;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Text(
              'stats',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('movimientos'),
                  selected: _reporte == 'MOVIMIENTOS',
                  onSelected: (_) {
                    _reporte = 'MOVIMIENTOS';
                    _recargar();
                  },
                ),
                ChoiceChip(
                  label: const Text('inventario'),
                  selected: _reporte == 'INVENTARIO',
                  onSelected: (_) {
                    _reporte = 'INVENTARIO';
                    _recargar();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: _categoriaId,
              decoration: const InputDecoration(labelText: 'categoría'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('todas')),
                ...categorias.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.nombre),
                  ),
                ),
              ],
              onChanged: (value) {
                _categoriaId = value;
                _recargar();
              },
            ),
            const SizedBox(height: 10),
            if (_reporte == 'MOVIMIENTOS')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('todos'),
                    selected: _tipo == null,
                    onSelected: (_) {
                      _tipo = null;
                      _recargar();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('entradas'),
                    selected: _tipo == 'ENTRADA',
                    onSelected: (_) {
                      _tipo = 'ENTRADA';
                      _recargar();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('salidas'),
                    selected: _tipo == 'SALIDA',
                    onSelected: (_) {
                      _tipo = 'SALIDA';
                      _recargar();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _rango == null ? 'fechas' : '${_desde!} · ${_hasta!}',
                    ),
                    onPressed: _elegirRango,
                  ),
                  if (_rango != null)
                    ActionChip(
                      label: const Text('limpiar'),
                      onPressed: () {
                        _rango = null;
                        _recargar();
                      },
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('solo activos'),
                    selected: _soloActivos,
                    onSelected: (value) {
                      _soloActivos = value;
                      _recargar();
                    },
                  ),
                ],
              ),
            const SectionTitle('resumen parametrizable'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _Stat(
                  'recursos',
                  resumen['recursos']!,
                  const Color(0xFF7AA2F7),
                ),
                _Stat('stock', resumen['stock']!, positive),
                _Stat(
                  'movimientos',
                  resumen['movimientos']!,
                  const Color(0xFFBB9AF7),
                ),
                _Stat('entradas', resumen['entradas']!, positive),
                _Stat('salidas', resumen['salidas']!, negative),
              ],
            ),
            const SectionTitle('entradas vs salidas'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      maxY:
                          [
                            resumen['entradas']!,
                            resumen['salidas']!,
                          ].reduce((a, b) => a > b ? a : b).toDouble() +
                          1,
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: resumen['entradas']!.toDouble(),
                              color: positive,
                              width: 46,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: resumen['salidas']!.toDouble(),
                              color: negative,
                              width: 46,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SectionTitle(
              '${_reporte == 'INVENTARIO' ? 'inventario' : 'movimientos'} · ${reporte.length}',
            ),
            if (reporte.isEmpty)
              const SizedBox(height: 120, child: EmptyView('sin resultados'))
            else
              ...reporte.asMap().entries.map((entry) {
                final item = entry.value;
                if (_reporte == 'INVENTARIO') {
                  final stock = (item['stock_actual'] as num).toInt();
                  return AnimatedListItem(
                    index: entry.key,
                    child: Card(
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          color: positive,
                        ),
                        title: Text(item['nombre'] as String),
                        subtitle: Text(
                          '${item['categoria_nombre']} · ${item['ubicacion']}',
                          style: const TextStyle(color: muted),
                        ),
                        trailing: Text('$stock'),
                      ),
                    ),
                  );
                }
                final entrada = item['tipo'] == 'ENTRADA';
                return AnimatedListItem(
                  index: entry.key,
                  child: Card(
                    child: ListTile(
                      dense: true,
                      leading: Text(
                        entrada ? '+' : '−',
                        style: TextStyle(
                          fontSize: 22,
                          color: entrada ? positive : negative,
                        ),
                      ),
                      title: Text(item['recurso_nombre'] as String),
                      subtitle: Text(
                        '${item['categoria_nombre']} · ${item['fecha']}',
                        style: const TextStyle(color: muted),
                      ),
                      trailing: Text('${item['cantidad']}'),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
