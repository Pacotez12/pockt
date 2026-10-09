import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';

/// Pantalla de configuración de palabras clave por categoría (spec §5.5).
class CategoryKeywordsScreen extends ConsumerWidget {
  const CategoryKeywordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final catRepo = ref.watch(categoriesRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.glassFill,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Palabras clave',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Asignación automática por categoría',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Category>>(
                stream: catRepo.watchActive(CategoryKind.expense),
                builder: (context, expSnapshot) {
                  final expenseCats = expSnapshot.data ?? const [];

                  return StreamBuilder<List<Category>>(
                    stream: catRepo.watchActive(CategoryKind.income),
                    builder: (context, incSnapshot) {
                      final incomeCats = incSnapshot.data ?? const [];
                      final allCats = [...expenseCats, ...incomeCats];

                      if (allCats.isEmpty) {
                        return Center(
                          child: Text(
                            'Sin categorías',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.textTertiary,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: allCats.length,
                        itemBuilder: (context, index) {
                          final cat = allCats[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CategoryTile(category: cat),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final Category category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = Color(isDark ? category.colorDark : category.colorLight);
    final kwRepo = ref.watch(keywordsRepositoryProvider);

    return Pressable(
      key: ValueKey('category-tile-${category.id}'),
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryKeywordsDetailScreen(category: category),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: catColor.withValues(alpha: isDark ? 0.16 : 0.12),
              ),
              child: Center(
                child: categoryIcon(category.icon, size: 18, color: catColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            StreamBuilder<List<CategoryKeyword>>(
              stream: kwRepo.watchFor(category.id),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Text(
                  '$count palabras',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Icon(
              uiIcon('caret-right'),
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de palabras de una categoría específica: ver chips, agregar y borrar.
class CategoryKeywordsDetailScreen extends ConsumerStatefulWidget {
  final Category category;

  const CategoryKeywordsDetailScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryKeywordsDetailScreen> createState() =>
      _CategoryKeywordsDetailScreenState();
}

class _CategoryKeywordsDetailScreenState
    extends ConsumerState<CategoryKeywordsDetailScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final kwRepo = ref.read(keywordsRepositoryProvider);
    Haptics.tick();
    kwRepo.addUserKeyword(widget.category.id, text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = Color(
      isDark ? widget.category.colorDark : widget.category.colorLight,
    );
    final kwRepo = ref.watch(keywordsRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.glassFill,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: catColor.withValues(alpha: isDark ? 0.16 : 0.12),
                    ),
                    child: Center(
                      child: categoryIcon(widget.category.icon, size: 17, color: catColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.category.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Reconocer también como…',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Campo para agregar nueva palabra
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('add-keyword-input'),
                        controller: _inputController,
                        onSubmitted: (_) => _submit(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Agregar palabra (ej. farmacia)...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: colors.textTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    Pressable(
                      key: const ValueKey('add-keyword-button'),
                      onTap: _submit,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: catColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          uiIcon('plus'),
                          size: 16,
                          color: catColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Lista de palabras clave en chips
            Expanded(
              child: StreamBuilder<List<CategoryKeyword>>(
                stream: kwRepo.watchFor(widget.category.id),
                builder: (context, snapshot) {
                  final keywords = snapshot.data ?? const [];

                  if (keywords.isEmpty) {
                    return Center(
                      child: Text(
                        'Sin palabras asignadas aún',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        for (final kw in keywords)
                          _KeywordChip(
                            keyword: kw,
                            onDelete: kw.source == KeywordSource.user
                                ? () {
                                    Haptics.tick();
                                    kwRepo.remove(kw.id);
                                  }
                                : null,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final CategoryKeyword keyword;
  final VoidCallback? onDelete;

  const _KeywordChip({
    required this.keyword,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isUser = keyword.source == KeywordSource.user;

    return Container(
      key: ValueKey('keyword-chip-${keyword.keyword}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUser
              ? colors.brandStart.withValues(alpha: 0.35)
              : colors.glassBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyword.keyword,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: isUser
                  ? colors.brandStart.withValues(alpha: 0.15)
                  : colors.textTertiary.withValues(alpha: 0.12),
            ),
            child: Text(
              isUser ? 'tuya' : 'seed',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isUser ? colors.brandStart : colors.textTertiary,
              ),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              key: ValueKey('delete-keyword-${keyword.keyword}'),
              onTap: onDelete,
              child: Icon(
                uiIcon('x'),
                size: 14,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
