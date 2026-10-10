import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';

/// Interfaz para abstraer la interacción con la plataforma de widgets nativos.
abstract class HomeWidgetPlatform {
  Future<Uri?> initiallyLaunchedUri();
  Stream<Uri?> get widgetClicks;
  Future<void> saveWidgetData<T>(String id, T? data);
  Future<void> updateWidget({required String name, required String androidName});
}

/// Implementación real que se comunica con Android vía [HomeWidget].
class MethodChannelHomeWidgetPlatform implements HomeWidgetPlatform {
  const MethodChannelHomeWidgetPlatform();

  @override
  Future<Uri?> initiallyLaunchedUri() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> get widgetClicks => HomeWidget.widgetClicked;

  @override
  Future<void> saveWidgetData<T>(String id, T? data) =>
      HomeWidget.saveWidgetData<T>(id, data);

  @override
  Future<void> updateWidget({
    required String name,
    required String androidName,
  }) =>
      HomeWidget.updateWidget(name: name, androidName: androidName);
}

/// Implementación en memoria para pruebas automáticas sin canales nativos.
class FakeHomeWidgetPlatform implements HomeWidgetPlatform {
  final _clicksController = StreamController<Uri?>.broadcast();
  final Map<String, dynamic> data = {};
  int updateCallCount = 0;

  FakeHomeWidgetPlatform();

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;

  @override
  Stream<Uri?> get widgetClicks => _clicksController.stream;

  @override
  Future<void> saveWidgetData<T>(String id, T? data) async {
    if (data == null) {
      this.data.remove(id);
    } else {
      this.data[id] = data;
    }
  }

  @override
  Future<void> updateWidget({
    required String name,
    required String androidName,
  }) async {
    updateCallCount++;
  }

  void emitClick(Uri uri) {
    _clicksController.add(uri);
  }

  void dispose() {
    _clicksController.close();
  }
}

/// Provider de la plataforma de widgets nativos.
/// En entorno de tests (FLUTTER_TEST) usa por defecto la implementación falsa.
final homeWidgetPlatformProvider = Provider<HomeWidgetPlatform>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return FakeHomeWidgetPlatform();
  }
  return const MethodChannelHomeWidgetPlatform();
});

/// Obtiene las categorías más usadas por cantidad de gastos en los últimos 60 días.
/// Excluye categorías archivadas y completa hasta [n] usando `sortOrder`.
Future<List<Category>> topCategories(
  AppDatabase db, {
  int n = 4,
  required DateTime nowLocal,
}) async {
  final cutoff = DateTime(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
  ).subtract(const Duration(days: 60));

  // 1. Obtener todas las categorías de gasto activas (no archivadas)
  final activeCats = await (db.select(db.categories)
        ..where((c) =>
            c.kind.equalsValue(CategoryKind.expense) &
            c.archived.equals(false))
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  if (activeCats.isEmpty) return const [];

  // 2. Contar gastos de los últimos 60 días por categoría
  final activeCatIds = activeCats.map((c) => c.id).toSet();
  final txCountByCat = <String, int>{};

  final recentTxs = await (db.select(db.transactions)
        ..where((t) =>
            t.type.equalsValue(TxType.expense) &
            t.deletedAt.isNull() &
            t.occurredAt.isBiggerOrEqualValue(cutoff)))
      .get();

  for (final tx in recentTxs) {
    if (activeCatIds.contains(tx.categoryId)) {
      txCountByCat[tx.categoryId] = (txCountByCat[tx.categoryId] ?? 0) + 1;
    }
  }

  // 3. Ordenar: mayor cantidad de gastos primero, desempatando por sortOrder ascendente
  final sorted = List<Category>.from(activeCats)
    ..sort((a, b) {
      final countA = txCountByCat[a.id] ?? 0;
      final countB = txCountByCat[b.id] ?? 0;
      if (countA != countB) {
        return countB.compareTo(countA); // mayor a menor
      }
      return a.sortOrder.compareTo(b.sortOrder); // menor a mayor
    });

  return sorted.take(n).toList();
}

/// Puente con el widget de pantalla de inicio nativo vía `home_widget`.
class HomeWidgetBridge {
  static const String appWidgetProvider = 'PocktWidgetProvider';

  /// Actualiza los datos del widget en SharedPreferences y solicita su redibujado.
  static Future<void> update({
    required AppDatabase db,
    required DateTime nowLocal,
    HomeWidgetPlatform? platform,
  }) async {
    final p = platform ?? const MethodChannelHomeWidgetPlatform();
    try {
      final categories = await topCategories(db, n: 4, nowLocal: nowLocal);
      for (var i = 0; i < 4; i++) {
        if (i < categories.length) {
          final cat = categories[i];
          await p.saveWidgetData<String>('category_id_$i', cat.id);
          await p.saveWidgetData<String>('category_name_$i', cat.name);
          await p.saveWidgetData<String>('category_icon_$i', cat.icon);
          await p.saveWidgetData<int>('category_color_$i', cat.colorDark);
        } else {
          await p.saveWidgetData<String?>('category_id_$i', null);
          await p.saveWidgetData<String?>('category_name_$i', null);
          await p.saveWidgetData<String?>('category_icon_$i', null);
          await p.saveWidgetData<int?>('category_color_$i', null);
        }
      }
      await p.saveWidgetData<int>('category_count', categories.length);
      await p.updateWidget(
        name: appWidgetProvider,
        androidName: appWidgetProvider,
      );
    } catch (_) {
      // Ignorar en caso de error
    }
  }
}

/// Procesa una URI de deep link para el flujo de carga (widget de inicio o quick settings tile).
Future<void> handleWidgetLaunchUri(BuildContext context, Uri uri) async {
  if (uri.scheme == 'pockt' && uri.host == 'entry') {
    final categoryId = uri.queryParameters['category'];
    await showEntryFlow(context, initialCategoryId: categoryId);
  }
}
