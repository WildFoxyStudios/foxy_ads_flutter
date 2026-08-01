// City landing page at `/inmuebles-en/:city`.
//
// A read-only, pre-filtered view for one city: the city is the URL segment
// so no typeahead picker is rendered. A two-chip operation row (Venta /
// Alquiler) toggles between the two values and re-fetches the search
// when changed. Results render in the same 2-col grid used by the main
// /inmuebles-en screen. Empty state links back to the faceted search.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../../data/re_models.dart';

class CityLandingScreen extends ConsumerStatefulWidget {
  final String city;

  const CityLandingScreen({super.key, required this.city});

  @override
  ConsumerState<CityLandingScreen> createState() => _CityLandingScreenState();
}

class _CityLandingScreenState extends ConsumerState<CityLandingScreen> {
  String? _operation; // null = no filter

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final decodedCity = Uri.decodeComponent(widget.city);
    final country = ref.watch(selectedCountryProvider);
    final results = ref.watch(_cityListingsProvider(
      CityListingsArgs(
        countryCode: country.code,
        city: decodedCity,
        operation: _operation,
      ),
    ));

    final operationLabel = switch (_operation) {
      'venta' => l10n.cityLandingSale,
      'alquiler' => l10n.cityLandingRent,
      _ => l10n.cityLandingBoth,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cityLandingTitle(decodedCity)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Hero header + operation chip row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  decodedCity,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.cityLandingPropertiesLine(operationLabel),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OpChip(
                        label: l10n.cityLandingOpSale,
                        selected: _operation == 'venta',
                        onTap: () => setState(() {
                          _operation = _operation == 'venta' ? null : 'venta';
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OpChip(
                        label: l10n.cityLandingOpRent,
                        selected: _operation == 'alquiler',
                        onTap: () => setState(() {
                          _operation =
                              _operation == 'alquiler' ? null : 'alquiler';
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _ResultsBody(
              results: results,
              city: decodedCity,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OpChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  final AsyncValue<List<Listing>> results;
  final String city;

  const _ResultsBody({required this.results, required this.city});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.commonErrorWithMessage(e.toString()),
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏘️', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text(
                    l10n.cityLandingEmpty(city),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/inmuebles-en'),
                    child: Text(l10n.cityLandingBrowseOther),
                  ),
                ],
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return ListingCard(
              listing: listing,
              onTap: () => context.push('/listing/${listing.id}'),
            );
          },
        );
      },
    );
  }
}

/// Args record for the city-listing provider. Held as a record so the
/// FutureProvider can be `.family`'d by a single key while still changing
/// when any of its fields changes (Riverpod compares records by value).
class CityListingsArgs {
  final String countryCode;
  final String city;
  final String? operation;

  const CityListingsArgs({
    required this.countryCode,
    required this.city,
    required this.operation,
  });

  @override
  bool operator ==(Object other) =>
      other is CityListingsArgs &&
      other.countryCode == countryCode &&
      other.city == city &&
      other.operation == operation;

  @override
  int get hashCode => Object.hash(countryCode, city, operation);
}

/// One-shot RE search for a specific city. Re-fires whenever the city's
/// URL segment or the operation-chip state changes (debounced 300ms to
/// coalesce rapid double-taps on the same chip).
final _cityListingsProvider = FutureProvider.family<
  List<Listing>,
  CityListingsArgs
>((ref, args) async {
  // Watch the country so the user can swap countries and re-trigger this
  // query (city names aren't unique across LATAM + ES).
  ref.watch(selectedCountryProvider);

  final completer = Completer<List<Listing>>();
  final timer = Timer(const Duration(milliseconds: 300), () async {
    try {
      final service = ref.read(listingServiceProvider);
      final f = ReFilters(
        countryCode: args.countryCode,
        city: args.city,
        operation: args.operation,
        cityExact: true,
        sort: ReSort.relevance,
      );
      final result = await service.searchRealEstate(f);
      if (!completer.isCompleted) completer.complete(result.items);
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  });
  ref.onDispose(() {
    timer.cancel();
    if (!completer.isCompleted) completer.complete(const <Listing>[]);
  });
  return completer.future;
});
