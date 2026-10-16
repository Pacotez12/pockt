import 'package:flutter/material.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';

Future<Category?> showSuggestionCategoryPicker(
  BuildContext context,
  List<Category> categories,
) {
  return showModalBottomSheet<Category>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final colors = sheetCtx.pockt;
      final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
      return Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(colors.glassFill, colors.background),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PocktRadii.xl),
          ),
          border: Border.all(color: colors.glassBorder),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Elegí una categoría',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: PocktType.title,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in categories)
                        Pressable(
                          semanticLabel: cat.name,
                          onTap: () => Navigator.of(sheetCtx).pop(cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.glassFill,
                              borderRadius: BorderRadius.circular(PocktRadii.m),
                              border: Border.all(color: colors.glassBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                categoryIcon(
                                  cat.icon,
                                  size: 16,
                                  color: Color(
                                    isDark ? cat.colorDark : cat.colorLight,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: PocktType.caption,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
