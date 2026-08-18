// OpenStreetMap view of the real-estate search results.
//
// Plots one marker per listing that has coordinates (see
// `Listing.hasCoordinates`). Tapping a marker opens the listing detail.
// Uses `flutter_map` with raw OSM raster tiles — pure Dart, no API key, no
// native (Android/iOS) config. This is why it was chosen over
// `google_maps_flutter`, which would require an API key wired into the
// WIP-protected AndroidManifest.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../l10n/app_localizations.dart';

class ReMapView extends StatelessWidget {
  const ReMapView({super.key, required this.listings});
  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final withCoords = listings.where((l) => l.hasCoordinates).toList();

    if (withCoords.isEmpty) {
      return Center(child: Text(l10n.realEstateMapNoCoords));
    }

    // Center on the mean of the coordinates.
    final avgLat =
        withCoords.map((l) => l.latitude!).reduce((a, b) => a + b) /
        withCoords.length;
    final avgLng =
        withCoords.map((l) => l.longitude!).reduce((a, b) => a + b) /
        withCoords.length;

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(avgLat, avgLng),
        initialZoom: 11,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.wildfoxy.foxy_ads',
        ),
        MarkerLayer(
          markers: withCoords.map((listing) {
            return Marker(
              point: LatLng(listing.latitude!, listing.longitude!),
              width: 80,
              height: 40,
              child: GestureDetector(
                onTap: () => context.push('/listing/${listing.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formatPrice(
                      listing.price,
                      listing.currency,
                      l10n.localeName,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // OSM attribution is required by the tile usage policy.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
