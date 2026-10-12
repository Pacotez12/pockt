import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = await Directory.systemTemp.createTemp('pockt_mig_v7_');
    dbFile = File('${tempDir.path}/pockt_v6.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void createV6DatabaseWithData(File file) {
    final rawDb = sqlite.sqlite3.open(file.path);

    rawDb.execute('''
      PRAGMA user_version = 6;

      CREATE TABLE categories (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color_dark INTEGER NOT NULL,
        color_light INTEGER NOT NULL,
        kind TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE transactions (
        id TEXT NOT NULL PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'PYG',
        category_id TEXT NOT NULL REFERENCES categories(id),
        merchant TEXT,
        note TEXT,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        recurring_rule_id TEXT,
        suggestion_id TEXT,
        deleted_at INTEGER
      );

      CREATE TABLE suggested_transactions (
        id TEXT NOT NULL PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL DEFAULT 'PYG',
        category_id TEXT REFERENCES categories(id),
        merchant TEXT,
        occurred_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        source_ref TEXT,
        status TEXT NOT NULL,
        transaction_id TEXT REFERENCES transactions(id),
        raw_text TEXT,
        fingerprint TEXT,
        created_at INTEGER NOT NULL
      );

      CREATE UNIQUE INDEX idx_suggested_transactions_source_source_ref_occurred_at
      ON suggested_transactions (source, source_ref, occurred_at);

      CREATE TABLE recurring_rules (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        frequency TEXT NOT NULL,
        day_of_month INTEGER,
        day_of_week INTEGER,
        month_of_year INTEGER,
        next_due_date INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE income_schedules (
        id TEXT NOT NULL PRIMARY KEY,
        mode TEXT NOT NULL,
        pay_days TEXT NOT NULL,
        pay_day_rules TEXT NOT NULL,
        monthly_amount INTEGER,
        pay_split_percents TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        effective_from INTEGER NOT NULL
      );

      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        monthly_limit INTEGER NOT NULL,
        alert_80_sent_for TEXT,
        alert_100_sent_for TEXT
      );

      CREATE TABLE day_marks (
        date TEXT NOT NULL PRIMARY KEY,
        no_spend INTEGER NOT NULL
      );

      CREATE TABLE settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE category_keywords (
        id TEXT NOT NULL PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        keyword TEXT NOT NULL,
        source TEXT NOT NULL,
        UNIQUE (category_id, keyword)
      );

      CREATE TABLE merchant_memory (
        raw_merchant TEXT NOT NULL PRIMARY KEY,
        clean_merchant TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id),
        usage_count INTEGER NOT NULL DEFAULT 1,
        last_used_at INTEGER NOT NULL
      );

      CREATE TABLE salary_deductions (
        id TEXT NOT NULL PRIMARY KEY,
        schedule_id TEXT NOT NULL REFERENCES income_schedules(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        value INTEGER NOT NULL
      );

      -- 1. Categorías de fábrica intactas con colores viejos por defecto
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000001', 'Comida', 'fork-knife', 0xFFFF9F43, 0xFFD9771A, 'expense', 0);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000002', 'Transporte', 'car-profile', 0xFF54A0FF, 0xFF1F6FD1, 'expense', 1);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000003', 'Hogar', 'house-line', 0xFF1DD1A1, 0xFF0E9673, 'expense', 2);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000004', 'Salud', 'heartbeat', 0xFFFF6B6B, 0xFFD64545, 'expense', 3);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000006', 'Servicios', 'lightning', 0xFF48DBFB, 0xFF0E9CBF, 'expense', 5);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000007', 'Educación', 'graduation-cap', 0xFFA4B0BE, 0xFF5D6B7A, 'expense', 6);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000008', 'Regalos', 'gift', 0xFFFECA57, 0xFFC9921A, 'expense', 7);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000009', 'Ropa', 't-shirt', 0xFFF368E0, 0xFFC43BB2, 'expense', 8);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000010', 'Otros', 'package', 0xFF8395A7, 0xFF556677, 'expense', 9);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000011', 'Sueldo', 'briefcase', 0xFF10B981, 0xFF059669, 'income', 0);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000012', 'Extra', 'sparkle', 0xFF06B6D4, 0xFF0891B2, 'income', 1);

      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000013', 'Otros ingresos', 'arrow-circle-down', 0xFF6366F1, 0xFF4338CA, 'income', 2);

      -- 2. Categoría de fábrica pero con color personalizado por el usuario (Ocio)
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('018f0000-0000-7000-8000-000000000005', 'Ocio custom', 'popcorn', 0xFF123456, 0xFF65436D, 'expense', 4);

      -- 3. Categoría personalizada creada por el usuario
      INSERT INTO categories (id, name, icon, color_dark, color_light, kind, sort_order)
      VALUES ('cat-custom-gym', 'Gimnasio', 'barbell', 0xFF112233, 0xFF445566, 'expense', 10);

      -- Transacción existente
      INSERT INTO transactions (id, type, amount, category_id, occurred_at, created_at, updated_at, source, merchant)
      VALUES ('tx-1', 'expense', 50000, '018f0000-0000-7000-8000-000000000001', 1728432000000, 1728432000000, 1728432000000, 'manual', 'Superseis');
    ''');

    rawDb.close();
  }

  test('base nueva se crea con la paleta nueva de §6.2b', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, equals(9));

    final cats = await db.select(db.categories).get();
    expect(cats.length, equals(14));

    final expectedColors = <String, ({int dark, int light})>{
      'Comida': (dark: 0xFFE4A067, light: 0xFF9A5505),
      'Transporte': (dark: 0xFF6BBAF0, light: 0xFF0070A6),
      'Hogar': (dark: 0xFF93C179, light: 0xFF49782A),
      'Salud': (dark: 0xFF49C7C0, light: 0xFF007E78),
      'Ocio': (dark: 0xFFC19FE9, light: 0xFF7955A0),
      'Servicios': (dark: 0xFF8FB0F8, light: 0xFF4665AE),
      'Educación': (dark: 0xFFAAA7F4, light: 0xFF635DAB),
      'Regalos': (dark: 0xFFDD96CD, light: 0xFF924B84),
      'Ropa': (dark: 0xFFC1B35B, light: 0xFF796900),
      'Otros': (dark: 0xFF9BA6B1, light: 0xFF606A74),
      'Préstamos': (dark: 0xFF5FC8A6, light: 0xFF007E5E),
      'Sueldo': (dark: 0xFF74C692, light: 0xFF187C49),
      'Extra': (dark: 0xFF47C5D2, light: 0xFF007B89),
      'Otros ingresos': (dark: 0xFF9BA6B1, light: 0xFF606A74),
    };

    for (final cat in cats) {
      final expected = expectedColors[cat.name];
      expect(expected, isNotNull, reason: 'Categoría inesperada ${cat.name}');
      expect(
        cat.colorDark,
        equals(expected!.dark),
        reason: 'colorDark incorrecto para ${cat.name}',
      );
      expect(
        cat.colorLight,
        equals(expected.light),
        reason: 'colorLight incorrecto para ${cat.name}',
      );
    }

    await db.close();
  });

  test('migración v6 a v7 actualiza categorías de fábrica intactas y conserva las personalizadas', () async {
    createV6DatabaseWithData(dbFile);

    final db = AppDatabase.forTesting(
      NativeDatabase(dbFile),
    );

    // 1. Schema version actualizado a 9
    expect(db.schemaVersion, equals(9));

    final cats = await db.select(db.categories).get();
    final catsById = {for (final c in cats) c.id: c};

    // 2. Categorías de fábrica intactas deben tener colores nuevos de §6.2b
    final comida = catsById['018f0000-0000-7000-8000-000000000001']!;
    expect(comida.colorDark, equals(0xFFE4A067));
    expect(comida.colorLight, equals(0xFF9A5505));

    final transporte = catsById['018f0000-0000-7000-8000-000000000002']!;
    expect(transporte.colorDark, equals(0xFF6BBAF0));
    expect(transporte.colorLight, equals(0xFF0070A6));

    final hogar = catsById['018f0000-0000-7000-8000-000000000003']!;
    expect(hogar.colorDark, equals(0xFF93C179));
    expect(hogar.colorLight, equals(0xFF49782A));

    final salud = catsById['018f0000-0000-7000-8000-000000000004']!;
    expect(salud.colorDark, equals(0xFF49C7C0));
    expect(salud.colorLight, equals(0xFF007E78));

    final servicios = catsById['018f0000-0000-7000-8000-000000000006']!;
    expect(servicios.colorDark, equals(0xFF8FB0F8));
    expect(servicios.colorLight, equals(0xFF4665AE));

    final educacion = catsById['018f0000-0000-7000-8000-000000000007']!;
    expect(educacion.colorDark, equals(0xFFAAA7F4));
    expect(educacion.colorLight, equals(0xFF635DAB));

    final regalos = catsById['018f0000-0000-7000-8000-000000000008']!;
    expect(regalos.colorDark, equals(0xFFDD96CD));
    expect(regalos.colorLight, equals(0xFF924B84));

    final ropa = catsById['018f0000-0000-7000-8000-000000000009']!;
    expect(ropa.colorDark, equals(0xFFC1B35B));
    expect(ropa.colorLight, equals(0xFF796900));

    final otros = catsById['018f0000-0000-7000-8000-000000000010']!;
    expect(otros.colorDark, equals(0xFF9BA6B1));
    expect(otros.colorLight, equals(0xFF606A74));

    final sueldo = catsById['018f0000-0000-7000-8000-000000000011']!;
    expect(sueldo.colorDark, equals(0xFF74C692));
    expect(sueldo.colorLight, equals(0xFF187C49));

    final extra = catsById['018f0000-0000-7000-8000-000000000012']!;
    expect(extra.colorDark, equals(0xFF47C5D2));
    expect(extra.colorLight, equals(0xFF007B89));

    final otrosIngresos = catsById['018f0000-0000-7000-8000-000000000013']!;
    expect(otrosIngresos.colorDark, equals(0xFF9BA6B1));
    expect(otrosIngresos.colorLight, equals(0xFF606A74));

    // 3. Categoría de fábrica pero con color personalizado por usuario: NO SE TOCA
    final ocioCustom = catsById['018f0000-0000-7000-8000-000000000005']!;
    expect(ocioCustom.colorDark, equals(0xFF123456));
    expect(ocioCustom.colorLight, equals(0xFF65436D));

    // 4. Categoría personalizada por usuario: NO SE TOCA
    final customGym = catsById['cat-custom-gym']!;
    expect(customGym.colorDark, equals(0xFF112233));
    expect(customGym.colorLight, equals(0xFF445566));

    // 5. Datos existentes de transacciones intactos
    final txs = await db.select(db.transactions).get();
    expect(txs.length, equals(1));
    expect(txs.first.merchant, equals('Superseis'));

    await db.close();

    // 6. Verificar PRAGMA en SQLite raw
    final rawDb = sqlite.sqlite3.open(dbFile.path);
    final userVersionResult = rawDb.select('PRAGMA user_version;');
    expect(userVersionResult.first['user_version'], equals(9));
    rawDb.close();
  });
}
