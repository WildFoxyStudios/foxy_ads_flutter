import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';

class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(categoriesWithSubcategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allCategoriesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(l10n.commonErrorWithMessage(error.toString())),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(categoriesWithSubcategoriesProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (categories) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length + 3,
          itemBuilder: (context, index) {
            if (index == categories.length + 2) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('📋', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(
                    l10n.allListingsViewAll,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push(AppRoutes.allListings),
                ),
              );
            }
            if (index == categories.length) {
              return Card(
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.properties.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🏠', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(
                    l10n.allCategoriesRealEstate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    l10n.allCategoriesRealEstateSubtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/inmuebles-en'),
                ),
              );
            }
            if (index == categories.length + 1) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.properties.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🏗️', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(
                    l10n.allCategoriesPromotions,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    l10n.allCategoriesPromotionsSubtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push(AppRoutes.promociones),
                ),
              );
            }
            final category = categories[index];
            final hasSubcategories =
                category.subcategories != null &&
                category.subcategories!.isNotEmpty;
            final categoryName = category.nameEs.isNotEmpty
                ? category.nameEs
                : category.name;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasSubcategories
                  ? ExpansionTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _parseColor(
                            category.color,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            category.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      title: Text(
                        categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        l10n.allCategoriesSubcategoriesCount(
                          category.subcategories!.length,
                        ),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      children: [
                        // "Ver todo en X" link — mirrors web's
                        // CategoriesClient.tsx view-all button.
                        TextButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.categoryListings(
                              category.id,
                              categoryName,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(
                            l10n.allCategoriesViewAllIn(categoryName),
                          ),
                        ),
                        // Subcategory chip wrap — mirrors web's chip grid.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: category.subcategories!.map((sub) {
                              final subLabel = sub.nameEs.isNotEmpty
                                  ? sub.nameEs
                                  : sub.name;
                              return ActionChip(
                                label: Text(subLabel),
                                avatar: sub.icon.isNotEmpty
                                    ? Text(sub.icon)
                                    : null,
                                onPressed: () => context.push(
                                  AppRoutes.categorySubcategoryListings(
                                    category.id,
                                    sub.id,
                                    subLabel,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _parseColor(
                            category.color,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            category.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      title: Text(
                        category.nameEs.isNotEmpty
                            ? category.nameEs
                            : category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => context.push(
                        '/category/${category.id}?name=${category.nameEs.isNotEmpty ? category.nameEs : category.name}',
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return AppColors.primary;
    }
  }
}
