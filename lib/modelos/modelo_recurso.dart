class ModeloRecurso {
  final int? id;
  final int categoriaId;
  final String nombre;
  final String descripcion;
  final String ubicacion;
  final int stockMinimo;
  final bool activo;
  final String fechaRegistro;

  const ModeloRecurso({
    this.id,
    required this.categoriaId,
    required this.nombre,
    this.descripcion = '',
    required this.ubicacion,
    required this.stockMinimo,
    this.activo = true,
    required this.fechaRegistro,
  });

  Map<String, dynamic> toMap({bool incluirId = true}) {
    final map = <String, dynamic>{
      'categoria_id': categoriaId,
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'ubicacion': ubicacion.trim(),
      'stock_minimo': stockMinimo,
      'activo': activo ? 1 : 0,
      'fecha_registro': fechaRegistro,
    };
    if (incluirId && id != null) map['id'] = id;
    return map;
  }

  factory ModeloRecurso.fromMap(Map<String, dynamic> map) {
    return ModeloRecurso(
      id: map['id'] as int?,
      categoriaId: map['categoria_id'] as int,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      ubicacion: map['ubicacion'] as String,
      stockMinimo: map['stock_minimo'] as int,
      activo: (map['activo'] as int? ?? 1) == 1,
      fechaRegistro: map['fecha_registro'] as String,
    );
  }
}
