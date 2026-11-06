class ModeloMovimiento {
  final int? id;
  final int recursoId;
  final String tipo;
  final int cantidad;
  final String fecha;
  final String responsable;
  final String observacion;

  const ModeloMovimiento({
    this.id,
    required this.recursoId,
    required this.tipo,
    required this.cantidad,
    required this.fecha,
    required this.responsable,
    this.observacion = '',
  });

  Map<String, dynamic> toMap({bool incluirId = true}) {
    final map = <String, dynamic>{
      'recurso_id': recursoId,
      'tipo': tipo,
      'cantidad': cantidad,
      'fecha': fecha,
      'responsable': responsable.trim(),
      'observacion': observacion.trim(),
    };
    if (incluirId && id != null) map['id'] = id;
    return map;
  }

  factory ModeloMovimiento.fromMap(Map<String, dynamic> map) {
    return ModeloMovimiento(
      id: map['id'] as int?,
      recursoId: map['recurso_id'] as int,
      tipo: map['tipo'] as String,
      cantidad: map['cantidad'] as int,
      fecha: map['fecha'] as String,
      responsable: map['responsable'] as String,
      observacion: (map['observacion'] as String?) ?? '',
    );
  }
}
