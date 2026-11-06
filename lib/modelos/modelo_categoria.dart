class ModeloCategoria {
  final int? id;
  final String nombre;
  final String descripcion;
  final bool activo;

  const ModeloCategoria({
    this.id,
    required this.nombre,
    this.descripcion = '',
    this.activo = true,
  });

  Map<String, dynamic> toMap({bool incluirId = true}) {
    final map = <String, dynamic>{
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'activo': activo ? 1 : 0,
    };
    if (incluirId && id != null) map['id'] = id;
    return map;
  }

  factory ModeloCategoria.fromMap(Map<String, dynamic> map) {
    return ModeloCategoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      activo: (map['activo'] as int? ?? 1) == 1,
    );
  }
}
