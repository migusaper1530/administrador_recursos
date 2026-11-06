import 'package:flutter/material.dart';

import '../helpers_db/database_helper.dart';
import '../modelos/modelo_categoria.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _buscar = TextEditingController();
  late Future<List<Object>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  void _cargar() {
    final consulta = Future.wait<Object>([
      _db.resumen(),
      _db.categorias(),
      _db.recursos(),
    ]);
    setState(() {
      _future = consulta;
    });
  }

  void _mostrarDisponibilidad(Map<String, dynamic> recurso) {
    final stock = (recurso['stock_actual'] as num).toInt();
    final activo = recurso['activo'] == 1;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recurso['nombre'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$stock unidades disponibles',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: activo ? positive : muted,
              ),
            ),
            const SizedBox(height: 12),
            Text('categoría: ${recurso['categoria_nombre']}'),
            Text('ubicación: ${recurso['ubicacion']}'),
            Text('estado: ${activo ? 'activo' : 'inactivo'}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('cerrar'),
          ),
        ],
      ),
    );
  }

  bool _coincide(Map<String, dynamic> recurso, String consulta) {
    if (consulta.isEmpty) return true;
    final texto = [
      recurso['nombre'],
      recurso['descripcion'],
      recurso['ubicacion'],
    ].join(' ').toLowerCase();
    return texto.contains(consulta);
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
        final categorias = snapshot.data![1] as List<ModeloCategoria>;
        final recursos = snapshot.data![2] as List<Map<String, dynamic>>;
        final consulta = _buscar.text.trim().toLowerCase();
        final categoriasVisibles = categorias.where((categoria) {
          if (consulta.isEmpty) return true;
          return recursos.any(
            (recurso) =>
                recurso['categoria_id'] == categoria.id &&
                _coincide(recurso, consulta),
          );
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _cargar(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const Text(
                'mis recursos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${resumen['stock']}',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: positive,
                            ),
                          ),
                          const Text(
                            'unidades disponibles',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SectionTitle('categorías y artículos'),
              TextField(
                controller: _buscar,
                decoration: const InputDecoration(
                  prefixText: '> ',
                  hintText: 'buscar artículo...',
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              if (categoriasVisibles.isEmpty)
                const SizedBox(
                  height: 160,
                  child: EmptyView('no se encontraron artículos'),
                )
              else
                ...categoriasVisibles.asMap().entries.map((entry) {
                  final categoria = entry.value;
                  final articulos = recursos
                      .where(
                        (recurso) =>
                            recurso['categoria_id'] == categoria.id &&
                            _coincide(recurso, consulta),
                      )
                      .toList();
                  return AnimatedListItem(
                    index: entry.key,
                    child: Card(
                      child: ExpansionTile(
                        initiallyExpanded: consulta.isNotEmpty,
                        leading: Icon(
                          Icons.folder_outlined,
                          color: categoria.activo ? positive : muted,
                        ),
                        title: Text(categoria.nombre),
                        subtitle: Text(
                          '${articulos.length} artículos',
                          style: const TextStyle(color: muted),
                        ),
                        children: articulos.isEmpty
                            ? const [
                                ListTile(
                                  title: Text(
                                    'sin artículos',
                                    style: TextStyle(color: muted),
                                  ),
                                ),
                              ]
                            : articulos
                                  .map(
                                    (recurso) => ListTile(
                                      onTap: () =>
                                          _mostrarDisponibilidad(recurso),
                                      leading: const Icon(
                                        Icons.inventory_2_outlined,
                                      ),
                                      title: Text(recurso['nombre'] as String),
                                      subtitle: Text(
                                        recurso['ubicacion'] as String,
                                        style: const TextStyle(color: muted),
                                      ),
                                      trailing: Text(
                                        '${(recurso['stock_actual'] as num).toInt()}',
                                        style: const TextStyle(fontSize: 17),
                                      ),
                                    ),
                                  )
                                  .toList(),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
