import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/backup/data/key_storage.dart';

void main() {
  group('KeyStorage (almacenamiento de clave de respaldo)', () {
    test('guarda, carga y borra la clave y sal en memoria', () async {
      final storage = KeyStorage.inMemory();

      // Inicialmente no hay clave guardada
      final initial = await storage.load();
      expect(initial, isNull);

      // Guardar clave y sal
      final sampleKey = List<int>.generate(32, (i) => i * 3);
      final sampleSalt = List<int>.generate(16, (i) => i + 10);

      await storage.saveKey(sampleKey, sampleSalt);

      // Cargar clave y verificar
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!.key, equals(sampleKey));
      expect(loaded.salt, equals(sampleSalt));

      // Sobrescribir con nuevos valores
      final newKey = List<int>.generate(32, (i) => 255 - i);
      final newSalt = List<int>.generate(16, (i) => 200 + i);

      await storage.saveKey(newKey, newSalt);
      final updated = await storage.load();
      expect(updated, isNotNull);
      expect(updated!.key, equals(newKey));
      expect(updated.salt, equals(newSalt));

      // Borrar y verificar que vuelve a null
      await storage.clear();
      final afterClear = await storage.load();
      expect(afterClear, isNull);
    });
  });
}
