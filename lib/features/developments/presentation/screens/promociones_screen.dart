import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/developments_service.dart';
import '../widgets/development_card.dart';

/// Public `/promociones` index — a grid of published developments (obra
/// nueva) for the currently selected country.
class PromocionesScreen extends ConsumerWidget {
  const PromocionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final developmentsAsync = ref.watch(developmentsForCountryProvider);
    final country = ref.watch(selectedCountryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.promocionesTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: developmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(l10n.commonErrorWithMessage(error.toString())),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(developmentsForCountryProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (developments) {
          if (developments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏗️', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.promocionesEmpty(country.name),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: developments.length,
            itemBuilder: (context, index) {
              return DevelopmentCard(development: developments[index]);
            },
          );
        },
      ),
    );
  }
}
