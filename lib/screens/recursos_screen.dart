import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers_db/database_helper.dart';
import '../modelos/modelo_categoria.dart';
import '../modelos/modelo_recurso.dart';
import '../widgets/ui.dart';

class RecursosScreen extends StatefulWidget {
  const RecursosScreen({super.key});

  @override
  State<RecursosScreen> createState() => _RecursosScreenState();
}

class _RecursosScreenState extends State<RecursosScreen> {
  final _db = DatabaseHelper.instance;
  final _buscar = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  void _recargar() {
    final consulta = _db.recursos(buscar: _buscar.text);
    setState(() {
      _future = consulta;
    });
  }

  Future<void> _formulario([Map<String, dynamic>? item]) async {
    final categorias = await _db.categorias();
    final existentes = await _db.recursos();
    if (!mounted) return;
    if (categorias.isEmpty) {
      showMessage(context, 'Primero crea una categoría.', error: true);
      return;
    }
    final key = GlobalKey<FormState>();
    final nombre = TextEditingController(
      text: item?['nombre'] as String? ?? '',
    );
    final descripcion = TextEditingController(
      text: item?['descripcion'] as String? ?? '',
    );
    final ubicacion = TextEditingController(
      text: item?['ubicacion'] as String? ?? '',
    );
    var categoriaId = item?['categoria_id'] as int? ?? categorias.first.id!;
    var activo = (item?['activo'] as int? ?? 1) == 1;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? '> nuevo recurso' : '> editar recurso'),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: categoriaId,
                    decoration: const InputDecoration(labelText: 'categoría'),
                    items: categorias
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      categoriaId = value!;
                      key.currentState?.validate();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nombre,
                    decoration: const InputDecoration(labelText: 'nombre'),
                    validator: (value) {
                      final texto = value?.trim() ?? '';
                      if (texto.isEmpty) return 'campo obligatorio';
                      final repetido = existentes.any(
                        (r) =>
                            r['id'] != item?['id'] &&
                            r['categoria_id'] == categoriaId &&
                            (r['nombre'] as String).toLowerCase() ==
                                texto.toLowerCase(),
                      );
                      return repetido ? 'ya existe en esta categoría' : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ubicacion,
                    decoration: const InputDecoration(labelText: 'ubicación'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'campo obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descripcion,
                    decoration: const InputDecoration(
                      labelText: 'descripción opcional',
                    ),
                  ),
                  SwitchListTile(
                    value: activo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('activo'),
                    onChanged: (value) => setDialogState(() => activo = value),
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
                  await _db.guardarRecurso(
                    ModeloRecurso(
                      id: item?['id'] as int?,
                      categoriaId: categoriaId,
                      nombre: nombre.text,
                      descripcion: descripcion.text,
                      ubicacion: ubicacion.text,
                      stockMinimo: (item?['stock_minimo'] as int?) ?? 0,
                      activo: activo,
                      fechaRegistro:
                          item?['fecha_registro'] as String? ??
                          DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    ),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _recargar();
                } catch (_) {
                  if (dialogContext.mounted) {
                    showMessage(
                      dialogContext,
                      'El nombre ya existe en esa categoría.',
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿eliminar recurso?'),
        content: Text(item['nombre'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final ok = await _db.eliminarRecurso(item['id'] as int);
    if (!mounted) return;
    showMessage(
      context,
      ok ? 'Recurso eliminado.' : 'Tiene movimientos: edítalo y desactívalo.',
      error: !ok,
    );
    _recargar();
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
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'recursos',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoriasScreen(),
                      ),
                    );
                    _recargar();
                  },
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('categorías'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _buscar,
              decoration: const InputDecoration(
                prefixText: '> ',
                hintText: 'buscar recurso...',
              ),
              onChanged: (_) => _recargar(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) return const EmptyView('sin recursos');
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final activo = item['activo'] == 1;
                      final stock = (item['stock_actual'] as num).toInt();
                      return AnimatedListItem(
                        index: index,
                        child: Card(
                          child: ListTile(
                            onTap: () => _formulario(item),
                            leading: Icon(
                              Icons.inventory_2_outlined,
                              color: activo ? positive : muted,
                            ),
                            title: Text(
                              item['nombre'] as String,
                              style: TextStyle(color: activo ? null : muted),
                            ),
                            subtitle: Text(
                              '${item['categoria_nombre']} · ${item['ubicacion']}',
                              style: const TextStyle(color: muted),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$stock',
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

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final _db = DatabaseHelper.instance;

  Future<void> _formulario([ModeloCategoria? categoria]) async {
    final existentes = await _db.categorias();
    if (!mounted) return;
    final key = GlobalKey<FormState>();
    final nombre = TextEditingController(text: categoria?.nombre ?? '');
    final descripcion = TextEditingController(
      text: categoria?.descripcion ?? '',
    );
    var activo = categoria?.activo ?? true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            categoria == null ? '> nueva categoría' : '> editar categoría',
          ),
          content: Form(
            key: key,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'nombre'),
                  validator: (value) {
                    final texto = value?.trim() ?? '';
                    if (texto.isEmpty) return 'campo obligatorio';
                    final repetido = existentes.any(
                      (c) =>
                          c.id != categoria?.id &&
                          c.nombre.toLowerCase() == texto.toLowerCase(),
                    );
                    return repetido ? 'esa categoría ya existe' : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descripcion,
                  decoration: const InputDecoration(
                    labelText: 'descripción opcional',
                  ),
                ),
                SwitchListTile(
                  value: activo,
                  title: const Text('activa'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => activo = v),
                ),
              ],
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
                  await _db.guardarCategoria(
                    ModeloCategoria(
                      id: categoria?.id,
                      nombre: nombre.text,
                      descripcion: descripcion.text,
                      activo: activo,
                    ),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  setState(() {});
                } catch (_) {
                  if (dialogContext.mounted) {
                    showMessage(
                      dialogContext,
                      'Esa categoría ya existe.',
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

  Future<void> _eliminar(ModeloCategoria categoria) async {
    final ok = await _db.eliminarCategoria(categoria.id!);
    if (!mounted) return;
    showMessage(
      context,
      ok ? 'Categoría eliminada.' : 'La categoría tiene recursos asociados.',
      error: !ok,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('categorías')),
      floatingActionButton: FloatingActionButton(
        onPressed: _formulario,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<ModeloCategoria>>(
        future: _db.categorias(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) return const EmptyView('sin categorías');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!
                .map(
                  (c) => AnimatedListItem(
                    index: snapshot.data!.indexOf(c),
                    child: Card(
                      child: ListTile(
                        onTap: () => _formulario(c),
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: c.activo ? positive : muted,
                        ),
                        title: Text(c.nombre),
                        subtitle: c.descripcion.isEmpty
                            ? null
                            : Text(c.descripcion),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) =>
                              v == 'edit' ? _formulario(c) : _eliminar(c),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('eliminar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
