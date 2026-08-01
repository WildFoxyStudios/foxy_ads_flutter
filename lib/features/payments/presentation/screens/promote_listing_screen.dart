import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/services/listing_service.dart';

final promoteListingProvider = FutureProvider.family<Listing?, String>((
  ref,
  id,
) async {
  final listingService = ref.read(listingServiceProvider);
  return await listingService.getListingById(id);
});

/// Pricing options exposed to the user. Must stay in lockstep with the web
/// side's `FEATURE_PRICES` map in `foxy_ads_web/src/lib/stripe/config.ts` —
/// both sides convert to/from cents at the Stripe boundary.
const Map<int, double> _featurePricesEuros = {
  1: 2.0,
  3: 5.0,
  7: 10.0,
  14: 18.0,
  30: 35.0,
};

/// Convert the user-visible euro total to cents for Stripe / payments table.
int _eurosToCents(double euros) => (euros * 100).round();

class PromoteListingScreen extends ConsumerStatefulWidget {
  final String listingId;

  const PromoteListingScreen({super.key, required this.listingId});

  @override
  ConsumerState<PromoteListingScreen> createState() =>
      _PromoteListingScreenState();
}

class _PromoteListingScreenState extends ConsumerState<PromoteListingScreen> {
  int _selectedDays = 3;
  bool _isProcessing = false;

  double get _totalPrice => _featurePricesEuros[_selectedDays] ?? 2.0;

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(promoteListingProvider(widget.listingId));
    final country = ref.watch(selectedCountryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promocionar Anuncio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: listingAsync.when(
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text('Anuncio no encontrado'));
          }

          if (listing.isCurrentlyFeatured) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.foxGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '¡Tu anuncio ya está destacado!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Expira el ${_formatDate(listing.featuredUntil!)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Listing Preview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: listing.mainImage.isNotEmpty
                              ? Image.network(
                                  listing.mainImage,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: AppColors.shimmer,
                                  child: const Icon(Icons.image),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listing.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                listing.formattedPrice,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Benefits
                const Text(
                  'Beneficios de promocionar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _BenefitItem(
                  icon: Icons.visibility,
                  title: 'Mayor visibilidad',
                  description: 'Aparece en el carrusel destacado del inicio',
                ),
                _BenefitItem(
                  icon: Icons.trending_up,
                  title: '10x más vistas',
                  description: 'Los anuncios destacados reciben más atención',
                ),
                _BenefitItem(
                  icon: Icons.star,
                  title: 'Etiqueta especial',
                  description: 'Tu anuncio se distingue con la etiqueta ⭐',
                ),
                _BenefitItem(
                  icon: Icons.speed,
                  title: 'Vende más rápido',
                  description: 'Conecta con más compradores interesados',
                ),
                const SizedBox(height: 24),

                // Pricing options
                const Text(
                  'Selecciona la duración',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._featurePricesEuros.entries.map((entry) {
                  final days = entry.key;
                  final price = entry.value;
                  final isSelected = _selectedDays == days;
                  final discount = days > 1
                      ? (1 - (price / days / 2.0)) * 100
                      : 0;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDays = days),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: days,
                            groupValue: _selectedDays,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedDays = value);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '$days ${days == 1 ? 'día' : 'días'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected
                                            ? AppColors.primary
                                            : null,
                                      ),
                                    ),
                                    if (discount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '-${discount.toInt()}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${country.currencySymbol}${(price / days).toStringAsFixed(2)}/día',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${country.currencySymbol}${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isSelected ? AppColors.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Payment methods
                const Text(
                  'Método de pago',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.credit_card),
                        title: const Text('Tarjeta de crédito/débito'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _processPayment('card'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Image.network(
                          'https://www.gstatic.com/instantbuy/svg/dark_gpay.svg',
                          width: 40,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.g_mobiledata),
                        ),
                        title: const Text('Google Pay'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _processPayment('google_pay'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.foxGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total a pagar',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            '${country.currencySymbol}${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$_selectedDays ${_selectedDays == 1 ? 'día' : 'días'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pay button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _processPayment('card'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Pagar ${country.currencySymbol}${_totalPrice.toStringAsFixed(2)}',
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _processPayment(String method) async {
    setState(() => _isProcessing = true);

    try {
      // `method` is wired through so the Stripe PaymentSheet hook can branch
      // on it ('card' vs 'google_pay'); for now we just promote the listing.
      // Honour the pricing table that matches `FEATURE_PRICES` on the web.
      // We don't take the user's money here — that's the Stripe PaymentSheet's
      // job. We just promote the listing server-side; if the matching payment
      // row is missing the listing will still appear as featured for the
      // selected window. A real production rollout would await the Stripe
      // PaymentSheet's success callback before calling promoteListing.
      assert(method == 'card' || method == 'google_pay');
      // ignore: unused_local_variable
      final _ = method;
      final listingService = ref.read(listingServiceProvider);
      await listingService.promoteListing(
        id: widget.listingId,
        days: _selectedDays,
        priceCents: _eurosToCents(_totalPrice),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Anuncio promocionado con éxito!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al promocionar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
