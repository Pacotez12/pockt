import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:share_plus/share_plus.dart';

String escapeCsvField(String field) {
  if (field.contains(';') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

/// Genera el contenido CSV con encabezado y una fila por movimiento con montos enteros.
/// Prefijo UTF-8 BOM (\uFEFF) y separador punto y coma (;) para compatibilidad con Excel.
String generateTransactionsCsv(List<TxView> items) {
  final buffer = StringBuffer('\uFEFFFecha;Tipo;Monto;Categoría;Nota;Comercio\n');
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  for (final item in items) {
    final tx = item.tx;
    final cat = item.category;
    final fecha = dateFormat.format(toLocal(tx.occurredAt));
    final tipo = tx.type == TxType.expense ? 'Gasto' : 'Ingreso';
    final monto = tx.amount.toString();
    final categoria = escapeCsvField(cat.name);
    final nota = escapeCsvField(tx.note ?? '');
    final comercio = escapeCsvField(tx.merchant ?? '');

    buffer.write('$fecha;$tipo;$monto;$categoria;$nota;$comercio\n');
  }

  return buffer.toString();
}

Future<void> exportAndShareCsv(
  List<TxView> items, {
  Future<ShareResult> Function(List<XFile> files)? shareFn,
  Future<Directory> Function() tempDirectory = getTemporaryDirectory,
}) async {
  final csvContent = generateTransactionsCsv(items);
  final tempDir = await tempDirectory();
  final filePath = '${tempDir.path}/pockt_movimientos.csv';
  final file = File(filePath);
  await file.writeAsString(csvContent, encoding: utf8);

  final xFile = XFile(filePath, mimeType: 'text/csv', name: 'pockt_movimientos.csv');
  if (shareFn != null) {
    await shareFn([xFile]);
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: [xFile], text: 'Movimientos de Pockt'),
  );
}
