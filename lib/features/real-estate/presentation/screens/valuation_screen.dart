// Property valuation form at `/valorar`.
//
// Asks the user for a city (from the enabled list for the selected country),
// a surface area in m², and an operation (Venta / Alquiler). Pressing
// "Valorar" calls `ListingService.estimateFromCityStats(...)` — the same
// RPC-backed estimate the listing-detail "zone price" widget uses. The
// result is shown as a card with the avg estimate (price × m²), a ±12%
// low/high band, the underlying €/m² figure, and the sample size. Below
// the min-sample threshold, the empty state ("No hay datos suficientes
// para esta zona.") is shown instead of a misleading number.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/city_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/theme/app_colors.dart';

class ValuationScreen extends ConsumerStatefulWidget {
  const ValuationScreen({super.key});

  @override
  ConsumerState<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends ConsumerState<ValuationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _m2Controller = TextEditingController();

  String? _city;
  String? _operation; // 'venta' | 'alquiler'
  AsyncValue<({double avgPricePerM2, int sampleSize})?>? _estimate;

  @override
  void dispose() {
    _m2Controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_city == null || _operation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona Venta o Alquiler')),
      );
      return;
    }

    final country = ref.read(selectedCountryProvider);
    final m2 = double.parse(_m2Controller.text.trim());
    // Mirror the web's bound: 1..100000. Validated above.
    if (m2 < 1 || m2 > 100000) return;

    setState(() {
      _estimate = const AsyncValue.loading();
    });

    () async {
      try {
        final service = ref.read(listingServiceProvider);
        final result = await service.estimateFromCityStats(
          countryCode: country.code,
          city: _city!,
          operation: _operation,
          minSample: 3,
        );
        if (!mounted) return;
        setState(() {
          _estimate = AsyncValue.data(result);
        });
      } catch (e, st) {
        if (!mounted) return;
        setState(() {
          _estimate = AsyncValue.error(e, st);
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final country = ref.watch(selectedCountryProvider);
    final citiesAsync = ref.watch(citiesProvider(country.code));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valorar mi inmueble'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Obtén una estimación orientativa del precio de tu vivienda '
                'según los anuncios activos en la zona.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // City dropdown
              const _FieldLabel('Ciudad'),
              citiesAsync.when(
                loading: () => Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => _CityDropdownBody(
                  cities: const [],
                  selected: _city,
                  onChanged: (v) => setState(() => _city = v),
                  placeholder: 'Error al cargar ciudades',
                ),
                data: (cities) {
                  final enabled = cities.where((c) => c.isEnabled).toList();
                  return _CityDropdownBody(
                    cities: enabled,
                    selected: _city,
                    onChanged: (v) => setState(() => _city = v),
                    placeholder: 'Selecciona una ciudad',
                  );
                },
              ),
              const SizedBox(height: 16),

              // m² input
              const _FieldLabel('Superficie (m²)'),
              TextFormField(
                controller: _m2Controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Ej. 80',
                  suffixText: 'm²',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Introduce la superficie';
                  }
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Valor no válido';
                  if (n < 1) return 'Mínimo 1 m²';
                  if (n > 100000) return 'Máximo 100000 m²';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Operation chips
              const _FieldLabel('Operación'),
              Row(
                children: [
                  Expanded(
                    child: _OpChoice(
                      label: 'Venta',
                      selected: _operation == 'venta',
                      onTap: () => setState(() => _operation = 'venta'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _OpChoice(
                      label: 'Alquiler',
                      selected: _operation == 'alquiler',
                      onTap: () => setState(() => _operation = 'alquiler'),
                    ),
                  ),
                ],
              ),
              if (_operation == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Selecciona Venta o Alquiler',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Valorar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Result card
              if (_estimate != null) _ResultCard(
                estimate: _estimate!,
                city: _city!,
                operation: _operation!,
                m2: int.parse(_m2Controller.text.trim()),
                currency: country.currency,
                currencySymbol: country.currencySymbol,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityDropdownBody extends StatelessWidget {
  final List<City> cities;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String placeholder;

  const _CityDropdownBody({
    required this.cities,
    required this.selected,
    required this.onChanged,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    // Match the dropdown value to an actual City entry so changing the
    // country (which resets the stored string) doesn't crash the lookup.
    City? matched;
    if (selected != null) {
      for (final c in cities) {
        if (c.name == selected) {
          matched = c;
          break;
        }
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: matched?.name,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          hint: Text(placeholder, overflow: TextOverflow.ellipsis),
          items: [
            ...cities.map(
              (c) => DropdownMenuItem<String?>(
                value: c.name,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _OpChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OpChoice({
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AsyncValue<({double avgPricePerM2, int sampleSize})?> estimate;
  final String city;
  final String operation;
  final int m2;
  final String currency;
  final String currencySymbol;

  const _ResultCard({
    required this.estimate,
    required this.city,
    required this.operation,
    required this.m2,
    required this.currency,
    required this.currencySymbol,
  });

  String _money(num value) =>
      '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} $currency';

  @override
  Widget build(BuildContext context) {
    return estimate.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Error: $e',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (stats) {
        if (stats == null || stats.sampleSize < 3) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text('📊', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  'No hay datos suficientes para esta zona.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final low = stats.avgPricePerM2 * 0.88 * m2;
        final high = stats.avgPricePerM2 * 1.12 * m2;
        final est = stats.avgPricePerM2 * m2;
        final opLabel =
            operation == 'venta' ? 'venta' : 'alquiler';
        final operationNote =
            'Valor orientativo para un inmueble tipo en $city.';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimación para $m2 m² en $opLabel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _money(est),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                operationNote,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      label: 'Mínimo',
                      value: _money(low),
                      tone: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCell(
                      label: 'Máximo',
                      value: _money(high),
                      tone: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precio medio/m²',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stats.avgPricePerM2.toStringAsFixed(0)} $currencySymbol/m²',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Muestra',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stats.sampleSize} anuncios',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;

  const _StatCell({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
