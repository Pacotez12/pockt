import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/settings/settings_repository.dart';

class HomeCardItem {
  final String id;
  final String label;
  final bool visible;

  const HomeCardItem({
    required this.id,
    required this.label,
    this.visible = true,
  });

  HomeCardItem copyWith({bool? visible}) =>
      HomeCardItem(id: id, label: label, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {'id': id, 'visible': visible};

  factory HomeCardItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final visible = json['visible'] as bool? ?? true;
    return HomeCardItem(id: id, label: labelForId(id), visible: visible);
  }

  static String labelForId(String id) {
    switch (id) {
      case 'period':
        return 'Quincena y cobros';
      case 'loans':
        return 'Préstamos y cuotas';
      case 'goals':
        return 'Metas';
      case 'suggestions':
        return 'Sugerencias';
      case 'calendar':
        return 'Calendario de calor';
      case 'recent':
        return 'Últimos movimientos';
      default:
        return id;
    }
  }

  static List<HomeCardItem> defaultCards() => const [
    HomeCardItem(id: 'calendar', label: 'Calendario de calor', visible: true),
    HomeCardItem(id: 'period', label: 'Quincena y cobros', visible: true),
    HomeCardItem(id: 'suggestions', label: 'Sugerencias', visible: true),
    HomeCardItem(id: 'recent', label: 'Últimos movimientos', visible: true),
  ];

  static String encode(List<HomeCardItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<HomeCardItem> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaultCards();
    try {
      final list = jsonDecode(raw) as List;
      final parsed = list
          .map((e) => HomeCardItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.id != 'loans' && e.id != 'goals')
          .toList();
      final existingIds = parsed.map((e) => e.id).toSet();
      for (final def in defaultCards()) {
        if (!existingIds.contains(def.id)) {
          parsed.add(def);
        }
      }
      return parsed;
    } catch (_) {
      return defaultCards();
    }
  }
}

final defaultHomeCards = HomeCardItem.defaultCards();

final homeCardsConfigProvider = StreamProvider<List<HomeCardItem>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.homeCards).map(HomeCardItem.decode);
});
