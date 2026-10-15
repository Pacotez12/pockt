/// Representa un atajo rápido de carga (sugerido o fijado).
class EntryShortcutItem {
  final String id;
  final String? merchant;
  final String? note;
  final int amount;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final int colorDark;
  final int colorLight;
  final bool isPinned;
  final int count;

  String get label {
    if (merchant != null && merchant!.trim().isNotEmpty) {
      return merchant!.trim();
    }
    if (note != null && note!.trim().isNotEmpty) {
      return note!.trim();
    }
    return categoryName;
  }

  const EntryShortcutItem({
    required this.id,
    this.merchant,
    this.note,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.colorDark,
    required this.colorLight,
    required this.isPinned,
    this.count = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryShortcutItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          merchant == other.merchant &&
          note == other.note &&
          amount == other.amount &&
          categoryId == other.categoryId &&
          isPinned == other.isPinned;

  @override
  int get hashCode =>
      Object.hash(id, merchant, note, amount, categoryId, isPinned);
}
