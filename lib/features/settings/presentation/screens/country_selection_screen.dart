import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/country_service.dart';

class CountrySelectionScreen extends ConsumerWidget {
  const CountrySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCountry = ref.watch(selectedCountryProvider);
    final countriesAsync = ref.watch(countriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar País'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: countriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error al cargar países'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(countriesProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (countries) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: countries.length,
          itemBuilder: (context, index) {
            final country = countries[index];
            final isSelected = country.code == selectedCountry.code;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected
                    ? BorderSide(color: AppColors.primary, width: 2)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: Text(
                  country.flag,
                  style: const TextStyle(fontSize: 32),
                ),
                title: Text(
                  country.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                subtitle: Text(
                  '${country.currency} (${country.currencySymbol})',
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  await ref
                      .read(selectedCountryProvider.notifier)
                      .setCountry(country);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('País cambiado a ${country.name}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    context.pop();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
