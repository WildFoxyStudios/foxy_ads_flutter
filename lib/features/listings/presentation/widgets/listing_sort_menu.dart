import 'package:flutter/material.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared sort dropdown for /anuncios + /category/:id + /category/:id/:subId.
/// Mirrors the web's `SortSelect` component (newest/oldest/price_low/price_high).
class ListingSortMenu extends StatelessWidget {
  const ListingSortMenu({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ListingSort value;
  final ValueChanged<ListingSort> onChanged;

  String _label(AppLocalizations l10n, ListingSort sort) {
    switch (sort) {
      case ListingSort.newest:
        return l10n.allListingsSortNewest;
      case ListingSort.oldest:
        return l10n.allListingsSortOldest;
      case ListingSort.priceLow:
        return l10n.allListingsSortPriceLow;
      case ListingSort.priceHigh:
        return l10n.allListingsSortPriceHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<ListingSort>(
      icon: const Icon(Icons.sort),
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => ListingSort.values
          .map(
            (s) => PopupMenuItem<ListingSort>(
              value: s,
              child: Text(_label(l10n, s)),
            ),
          )
          .toList(),
    );
  }
}
