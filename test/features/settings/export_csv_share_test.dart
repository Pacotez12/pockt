import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/settings/domain/export_csv.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('exportar comparte el archivo CSV generado', () async {
    final dir = await Directory.systemTemp.createTemp('pockt_csv_');
    addTearDown(() => dir.delete(recursive: true));
    List<XFile>? shared;

    await exportAndShareCsv(
      const [],
      tempDirectory: () async => dir,
      shareFn: (files) async {
        shared = files;
        return const ShareResult('ok', ShareResultStatus.success);
      },
    );

    expect(shared, hasLength(1));
    final bytes = await File(shared!.single.path).readAsBytes();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]); // BOM UTF-8 para Excel
    expect(String.fromCharCodes(bytes.skip(3).take(10)), 'Fecha;Tipo');
  });
}
