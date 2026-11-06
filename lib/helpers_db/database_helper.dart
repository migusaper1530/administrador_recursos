import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../modelos/modelo_categoria.dart';
import '../modelos/modelo_movimiento.dart';
import '../modelos/modelo_recurso.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'stash_recursos.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categorias (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL COLLATE NOCASE UNIQUE,
            descripcion TEXT NOT NULL DEFAULT '',
            activo INTEGER NOT NULL DEFAULT 1 CHECK(activo IN (0, 1))
          )
        ''');
        await db.execute('''
          CREATE TABLE recursos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            categoria_id INTEGER NOT NULL,
            nombre TEXT NOT NULL COLLATE NOCASE,
            descripcion TEXT NOT NULL DEFAULT '',
            ubicacion TEXT NOT NULL,
            stock_minimo INTEGER NOT NULL DEFAULT 0 CHECK(stock_minimo >= 0),
            activo INTEGER NOT NULL DEFAULT 1 CHECK(activo IN (0, 1)),
            fecha_registro TEXT NOT NULL,
            FOREIGN KEY (categoria_id) REFERENCES categorias(id)
              ON DELETE RESTRICT ON UPDATE CASCADE,
            UNIQUE(categoria_id, nombre)
          )
        ''');
        await db.execute('''
          CREATE TABLE movimientos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recurso_id INTEGER NOT NULL,
            tipo TEXT NOT NULL CHECK(tipo IN ('ENTRADA', 'SALIDA')),
            cantidad INTEGER NOT NULL CHECK(cantidad > 0),
            fecha TEXT NOT NULL,
            responsable TEXT NOT NULL,
            observacion TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (recurso_id) REFERENCES recursos(id)
              ON DELETE RESTRICT ON UPDATE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_recursos_categoria ON recursos(categoria_id)',
        );
        await db.execute(
          'CREATE INDEX idx_movimientos_recurso ON movimientos(recurso_id)',
        );
        await db.execute(
          'CREATE INDEX idx_movimientos_fecha ON movimientos(fecha)',
        );
      },
    );
  }

  Future<List<ModeloCategoria>> categorias({bool soloActivas = false}) async {
    final db = await database;
    final rows = await db.query(
      'categorias',
      where: soloActivas ? 'activo = 1' : null,
      orderBy: 'nombre COLLATE NOCASE',
    );
    return rows.map(ModeloCategoria.fromMap).toList();
  }

  Future<void> guardarCategoria(ModeloCategoria categoria) async {
    final db = await database;
    if (categoria.id == null) {
      await db.insert('categorias', categoria.toMap(incluirId: false));
    } else {
      await db.update(
        'categorias',
        categoria.toMap(incluirId: false),
        where: 'id = ?',
        whereArgs: [categoria.id],
      );
    }
  }

  Future<bool> eliminarCategoria(int id) async {
    try {
      final db = await database;
      return await db.delete('categorias', where: 'id = ?', whereArgs: [id]) >
          0;
    } on DatabaseException {
      return false;
    }
  }

  String _stockSql([String alias = 'r']) =>
      '''
    COALESCE((SELECT SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.cantidad ELSE -m.cantidad END)
      FROM movimientos m WHERE m.recurso_id = $alias.id), 0)
  ''';

  Future<List<Map<String, dynamic>>> recursos({String buscar = ''}) async {
    final db = await database;
    final filtro = buscar.trim();
    return db.rawQuery(
      '''
      SELECT r.*, c.nombre AS categoria_nombre, ${_stockSql()} AS stock_actual
      FROM recursos r
      INNER JOIN categorias c ON c.id = r.categoria_id
      WHERE (? = '' OR r.nombre LIKE ? OR r.ubicacion LIKE ?)
      ORDER BY r.activo DESC, r.nombre COLLATE NOCASE
    ''',
      [filtro, '%$filtro%', '%$filtro%'],
    );
  }

  Future<List<Map<String, dynamic>>> recursosActivos() async {
    final db = await database;
    return db.rawQuery('''
      SELECT r.id, r.nombre, r.ubicacion, ${_stockSql()} AS stock_actual
      FROM recursos r WHERE r.activo = 1 ORDER BY r.nombre COLLATE NOCASE
    ''');
  }

  Future<List<Map<String, dynamic>>> reporteInventario({
    int? categoriaId,
    bool soloActivos = false,
    bool soloBajo = false,
  }) async {
    final db = await database;
    final condiciones = <String>[];
    final args = <Object?>[];
    if (categoriaId != null) {
      condiciones.add('r.categoria_id = ?');
      args.add(categoriaId);
    }
    if (soloActivos) condiciones.add('r.activo = 1');
    if (soloBajo) condiciones.add('${_stockSql()} <= r.stock_minimo');
    final where = condiciones.isEmpty
        ? ''
        : 'WHERE ${condiciones.join(' AND ')}';
    return db.rawQuery('''
      SELECT r.*, c.nombre AS categoria_nombre, ${_stockSql()} AS stock_actual
      FROM recursos r
      INNER JOIN categorias c ON c.id = r.categoria_id
      $where
      ORDER BY r.activo DESC, r.nombre COLLATE NOCASE
    ''', args);
  }

  Future<void> guardarRecurso(ModeloRecurso recurso) async {
    final db = await database;
    if (recurso.id == null) {
      await db.insert('recursos', recurso.toMap(incluirId: false));
    } else {
      await db.update(
        'recursos',
        recurso.toMap(incluirId: false),
        where: 'id = ?',
        whereArgs: [recurso.id],
      );
    }
  }

  Future<bool> eliminarRecurso(int id) async {
    try {
      final db = await database;
      return await db.delete('recursos', where: 'id = ?', whereArgs: [id]) > 0;
    } on DatabaseException {
      return false;
    }
  }

  Future<int> _stock(Transaction txn, int recursoId, {int? excluir}) async {
    final rows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN tipo = 'ENTRADA' THEN cantidad ELSE -cantidad END), 0) AS stock
      FROM movimientos WHERE recurso_id = ? ${excluir == null ? '' : 'AND id <> ?'}
    ''',
      [recursoId, ?excluir],
    );
    return (rows.first['stock'] as num).toInt();
  }

  Future<void> guardarMovimiento(ModeloMovimiento movimiento) async {
    final db = await database;
    await db.transaction((txn) async {
      if (movimiento.id != null) {
        final anterior = await txn.query(
          'movimientos',
          where: 'id = ?',
          whereArgs: [movimiento.id],
          limit: 1,
        );
        if (anterior.isEmpty) throw Exception('El movimiento ya no existe.');
        final recursoAnterior = anterior.first['recurso_id'] as int;
        final stockSinAnterior = await _stock(
          txn,
          recursoAnterior,
          excluir: movimiento.id,
        );
        if (stockSinAnterior < 0) {
          throw Exception(
            'El cambio dejaría stock negativo en el recurso anterior.',
          );
        }
      }

      final stockBase = await _stock(
        txn,
        movimiento.recursoId,
        excluir: movimiento.id,
      );
      final stockFinal = movimiento.tipo == 'ENTRADA'
          ? stockBase + movimiento.cantidad
          : stockBase - movimiento.cantidad;
      if (stockFinal < 0) {
        throw Exception('Stock insuficiente. Disponible: $stockBase.');
      }

      if (movimiento.id == null) {
        await txn.insert('movimientos', movimiento.toMap(incluirId: false));
      } else {
        await txn.update(
          'movimientos',
          movimiento.toMap(incluirId: false),
          where: 'id = ?',
          whereArgs: [movimiento.id],
        );
      }
    });
  }

  Future<void> eliminarMovimiento(ModeloMovimiento movimiento) async {
    final db = await database;
    await db.transaction((txn) async {
      final restante = await _stock(
        txn,
        movimiento.recursoId,
        excluir: movimiento.id,
      );
      if (restante < 0) {
        throw Exception('No se puede eliminar: el stock quedaría negativo.');
      }
      await txn.delete(
        'movimientos',
        where: 'id = ?',
        whereArgs: [movimiento.id],
      );
    });
  }

  Future<List<Map<String, dynamic>>> movimientos({
    String? desde,
    String? hasta,
    int? categoriaId,
    String? tipo,
    int limite = 100,
  }) async {
    final db = await database;
    final condiciones = <String>[];
    final args = <Object?>[];
    if (desde != null) {
      condiciones.add('m.fecha >= ?');
      args.add(desde);
    }
    if (hasta != null) {
      condiciones.add('m.fecha <= ?');
      args.add(hasta);
    }
    if (categoriaId != null) {
      condiciones.add('r.categoria_id = ?');
      args.add(categoriaId);
    }
    if (tipo != null) {
      condiciones.add('m.tipo = ?');
      args.add(tipo);
    }
    final where = condiciones.isEmpty
        ? ''
        : 'WHERE ${condiciones.join(' AND ')}';
    args.add(limite);
    return db.rawQuery('''
      SELECT m.*, r.nombre AS recurso_nombre, c.nombre AS categoria_nombre
      FROM movimientos m
      INNER JOIN recursos r ON r.id = m.recurso_id
      INNER JOIN categorias c ON c.id = r.categoria_id
      $where ORDER BY m.fecha DESC, m.id DESC LIMIT ?
    ''', args);
  }

  Future<Map<String, int>> resumen({
    String? desde,
    String? hasta,
    int? categoriaId,
    String? tipo,
  }) async {
    final db = await database;
    final recursosFiltro = categoriaId == null
        ? ''
        : 'WHERE r.categoria_id = ?';
    final recursosArgs = <Object?>[?categoriaId];
    final recursoRows = await db.rawQuery('''
      SELECT COUNT(*) AS recursos,
        COALESCE(SUM(${_stockSql()}), 0) AS stock,
        COALESCE(SUM(CASE WHEN ${_stockSql()} <= r.stock_minimo THEN 1 ELSE 0 END), 0) AS bajo
      FROM recursos r $recursosFiltro
    ''', recursosArgs);

    final condiciones = <String>[];
    final args = <Object?>[];
    if (desde != null) {
      condiciones.add('m.fecha >= ?');
      args.add(desde);
    }
    if (hasta != null) {
      condiciones.add('m.fecha <= ?');
      args.add(hasta);
    }
    if (categoriaId != null) {
      condiciones.add('r.categoria_id = ?');
      args.add(categoriaId);
    }
    if (tipo != null) {
      condiciones.add('m.tipo = ?');
      args.add(tipo);
    }
    final where = condiciones.isEmpty
        ? ''
        : 'WHERE ${condiciones.join(' AND ')}';
    final movRows = await db.rawQuery('''
      SELECT COUNT(*) AS movimientos,
        COALESCE(SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.cantidad ELSE 0 END), 0) AS entradas,
        COALESCE(SUM(CASE WHEN m.tipo = 'SALIDA' THEN m.cantidad ELSE 0 END), 0) AS salidas
      FROM movimientos m INNER JOIN recursos r ON r.id = m.recurso_id $where
    ''', args);
    final r = recursoRows.first;
    final m = movRows.first;
    return {
      'recursos': (r['recursos'] as num).toInt(),
      'stock': (r['stock'] as num).toInt(),
      'bajo': (r['bajo'] as num).toInt(),
      'movimientos': (m['movimientos'] as num).toInt(),
      'entradas': (m['entradas'] as num).toInt(),
      'salidas': (m['salidas'] as num).toInt(),
    };
  }
}
