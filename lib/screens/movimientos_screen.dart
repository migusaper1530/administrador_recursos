import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers_db/database_helper.dart';
import '../modelos/modelo_movimiento.dart';
import '../widgets/ui.dart';

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _db = DatabaseHelper.instance;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final consulta = _db.movimientos();
    setState(() {
      _future = consulta;
    });
  }

  Future<void> _formulario([Map<String, dynamic>? item]) async {
    final recursos = item == null
        ? await _db.recursosActivos()
        : await _db.recursos();
    if (!mounted) return;
    if (recursos.isEmpty) {
      showMessage(context, 'Primero crea un recurso.', error: true);
      return;
    }
    final key = GlobalKey<FormState>();
    final cantidad = TextEditingController(text: '${item?['cantidad'] ?? ''}');
    final fecha = TextEditingController(
      text:
          item?['fecha'] as String? ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final responsable = TextEditingController(
      text: item?['responsable'] as String? ?? '',
    );
    final observacion = TextEditingController(
      text: item?['observacion'] as String? ?? '',
    );
    var recursoId = item?['recurso_id'] as int? ?? recursos.first['id'] as int;
    var tipo = item?['tipo'] as String? ?? 'ENTRADA';

    int disponible() {
      final recurso = recursos.firstWhere((r) => r['id'] == recursoId);
      var stock = (recurso['stock_actual'] as num).toInt();
      if (item != null && item['recurso_id'] == recursoId) {
        final anterior = (item['cantidad'] as num).toInt();
        stock += item['tipo'] == 'ENTRADA' ? -anterior : anterior;
      }
      return stock;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            item == null ? '> nuevo movimiento' : '> editar movimiento',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: recursoId,
                    decoration: const InputDecoration(labelText: 'recurso'),
                    items: recursos
                        .map(
                          (r) => DropdownMenuItem(
                            value: r['id'] as int,
                            child: Text(r['nombre'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => recursoId = value!);
                      key.currentState?.validate();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: 'tipo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'ENTRADA',
                        child: Text('+ entrada'),
                      ),
                      DropdownMenuItem(
                        value: 'SALIDA',
                        child: Text('− salida'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => tipo = value!);
                      key.currentState?.validate();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: cantidad,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'cantidad'),
                    validator: (value) {
                      final n = int.tryParse(value ?? '');
                      if (n == null || n <= 0) {
                        return 'usa un número mayor a 0';
                      }
                      if (tipo == 'SALIDA' && n > disponible()) {
                        return 'solo hay ${disponible()} disponibles';
                      }
                      return null;
                    },
                  ),
                  if (tipo == 'SALIDA')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'disponible: ${disponible()}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: responsable,
                    decoration: const InputDecoration(labelText: 'responsable'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'campo obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: fecha,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'fecha',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final elegida = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(fecha.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (elegida != null) {
                        fecha.text = DateFormat('yyyy-MM-dd').format(elegida);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: observacion,
                    decoration: const InputDecoration(
                      labelText: 'nota opcional',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!key.currentState!.validate()) return;
                try {
                  await _db.guardarMovimiento(
                    ModeloMovimiento(
                      id: item?['id'] as int?,
                      recursoId: recursoId,
                      tipo: tipo,
                      cantidad: int.parse(cantidad.text),
                      fecha: fecha.text,
                      responsable: responsable.text,
                      observacion: observacion.text,
                    ),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _recargar();
                } catch (e) {
                  if (dialogContext.mounted) {
                    showMessage(
                      dialogContext,
                      e.toString().replaceFirst('Exception: ', ''),
                      error: true,
                    );
                  }
                }
              },
              child: const Text('guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> item) async {
    try {
      await _db.eliminarMovimiento(ModeloMovimiento.fromMap(item));
      if (!mounted) return;
      showMessage(context, 'Movimiento eliminado.');
      _recargar();
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _formulario,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'movimientos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) return const EmptyView('sin movimientos');
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final entrada = item['tipo'] == 'ENTRADA';
                      return AnimatedListItem(
                        index: index,
                        child: Card(
                          child: ListTile(
                            onTap: () => _formulario(item),
                            leading: Text(
                              entrada ? '+' : '−',
                              style: TextStyle(
                                fontSize: 26,
                                color: entrada ? positive : negative,
                              ),
                            ),
                            title: Text(item['recurso_nombre'] as String),
                            subtitle: Text(
                              '${item['fecha']} · ${item['responsable']}',
                              style: const TextStyle(color: muted),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item['cantidad']}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) => value == 'edit'
                                      ? _formulario(item)
                                      : _eliminar(item),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('eliminar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
