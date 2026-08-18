import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/country_service.dart';
import '../../../../core/models/country_model.dart';
import '../../../../l10n/app_localizations.dart';

class CountrySelectionScreen extends ConsumerStatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  ConsumerState<CountrySelectionScreen> createState() =>
      _CountrySelectionScreenState();
}

class _CountrySelectionScreenState
    extends ConsumerState<CountrySelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> _filterCountries(List<Country> countries) {
    if (_query.isEmpty) return countries;
    return countries
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query) ||
              c.code.toLowerCase().contains(_query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final countriesAsync = ref.watch(countriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsSelectCountryTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.countrySelectionSearchHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: countriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.settingsLoadCountriesError),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(countriesProvider),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              data: (countries) {
                final filtered = _filterCountries(countries);
                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.countrySelectionNoResults));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final country = filtered[index];
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
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
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await ref
                              .read(selectedCountryProvider.notifier)
                              .setCountry(country);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.settingsCountryChanged(country.name),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            context.pop();
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
