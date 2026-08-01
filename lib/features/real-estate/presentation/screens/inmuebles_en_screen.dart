// Real-estate faceted search screen at /inmuebles-en.
//
// Three regions:
//   1. Country + city pickers (top, always visible).
//   2. Operation chip row (3 options: venta / alquiler / alquiler_temporal).
//   3. A "Filtros" expansion tile with the rest of the controls
//      (property type / condition / features / orientation / floor /
//      energy band / energy letter / pets / posted-within / m² range /
//      price range) wrapped in a debounced 300ms search.
//   4. Sort dropdown (above the grid).
//   5. Results grid (2 columns of `ListingCard`).
//
// The screen renders its "pick a country and operation to start" prompt
// when [ReSearchFilters.isActive] is `false`. When results are 0 with
// active filters, it shows "Sin resultados".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/city_model.dart';
import '../../../../core/models/country_model.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/listing_card.dart';
import '../../data/re_attributes.dart';
import '../../data/re_models.dart';
import '../providers/re_search_provider.dart';

class InmueblesEnScreen extends ConsumerStatefulWidget {
  const InmueblesEnScreen({super.key});

  @override
  ConsumerState<InmueblesEnScreen> createState() => _InmueblesEnScreenState();
}

class _InmueblesEnScreenState extends ConsumerState<InmueblesEnScreen> {
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();
  final _m2MinController = TextEditingController();
  final _m2MaxController = TextEditingController();

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _m2MinController.dispose();
    _m2MaxController.dispose();
    super.dispose();
  }

  void _commitPriceFields() {
    final notifier = ref.read(reSearchFiltersProvider.notifier);
    notifier.setPriceMin(num.tryParse(_priceMinController.text.trim()));
    notifier.setPriceMax(num.tryParse(_priceMaxController.text.trim()));
    notifier.setM2Min(num.tryParse(_m2MinController.text.trim()));
    notifier.setM2Max(num.tryParse(_m2MaxController.text.trim()));
  }

  void _clearAll() {
    _priceMinController.clear();
    _priceMaxController.clear();
    _m2MinController.clear();
    _m2MaxController.clear();
    ref.read(reSearchFiltersProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(reSearchFiltersProvider);
    final country = ref.watch(selectedCountryProvider);
    final results = ref.watch(reSearchResultsProvider);
    final facetCounts = ref.watch(reFacetCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inmuebles'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (filters.isActive)
            IconButton(
              tooltip: 'Limpiar filtros',
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Country + city pickers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _CountryChip(country: country),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CityDropdown(
                    countryCode: country.code,
                    selected: filters.city,
                    onChanged: (value) => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setCity(value),
                  ),
                ),
              ],
            ),
          ),

          // Operation chip row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _OperationChip(
                    label: 'Venta',
                    value: 'venta',
                    selected: filters.operation == 'venta',
                    onSelected: () => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setOperation(
                          filters.operation == 'venta' ? null : 'venta',
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OperationChip(
                    label: 'Alquiler',
                    value: 'alquiler',
                    selected: filters.operation == 'alquiler',
                    onSelected: () => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setOperation(
                          filters.operation == 'alquiler' ? null : 'alquiler',
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OperationChip(
                    label: 'Temporal',
                    value: 'alquiler_temporal',
                    selected: filters.operation == 'alquiler_temporal',
                    onSelected: () => ref
                        .read(reSearchFiltersProvider.notifier)
                        .setOperation(
                          filters.operation == 'alquiler_temporal'
                              ? null
                              : 'alquiler_temporal',
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Filters panel + results
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _FiltersExpansionTile(
                  filters: filters,
                  facetCounts: facetCounts,
                  currencySymbol: country.currencySymbol,
                  priceMinController: _priceMinController,
                  priceMaxController: _priceMaxController,
                  m2MinController: _m2MinController,
                  m2MaxController: _m2MaxController,
                  onCommitPrice: _commitPriceFields,
                ),
                const SizedBox(height: 12),

                // Sort dropdown
                _SortDropdown(
                  value: filters.sort,
                  onChanged: (value) => ref
                      .read(reSearchFiltersProvider.notifier)
                      .setSort(value),
                ),
                const SizedBox(height: 12),

                // Results grid OR prompt
                if (!filters.isActive)
                  const _Prompt()
                else
                  _ResultsGrid(results: results),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryChip extends ConsumerWidget {
  final Country country;
  const _CountryChip({required this.country});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/select-country'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                country.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CityDropdown extends ConsumerWidget {
  final String countryCode;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({
    required this.countryCode,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(citiesProvider(countryCode));
    return citiesAsync.when(
      loading: () => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
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
        selected: selected,
        onChanged: onChanged,
        placeholder: 'Error al cargar ciudades',
      ),
      data: (cities) {
        final enabled = cities.where((c) => c.isEnabled).toList();
        return _CityDropdownBody(
          cities: enabled,
          selected: selected,
          onChanged: onChanged,
          placeholder: 'Todas las ciudades',
        );
      },
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: matched?.name,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          hint: Text(placeholder, overflow: TextOverflow.ellipsis),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todas las ciudades'),
            ),
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

class _OperationChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _OperationChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Center(child: Text(label)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}

class _FiltersExpansionTile extends ConsumerWidget {
  final ReSearchFilters filters;
  final AsyncValue<ReFacetCounts> facetCounts;
  final String currencySymbol;
  final TextEditingController priceMinController;
  final TextEditingController priceMaxController;
  final TextEditingController m2MinController;
  final TextEditingController m2MaxController;
  final VoidCallback onCommitPrice;

  const _FiltersExpansionTile({
    required this.filters,
    required this.facetCounts,
    required this.currencySymbol,
    required this.priceMinController,
    required this.priceMaxController,
    required this.m2MinController,
    required this.m2MaxController,
    required this.onCommitPrice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reSearchFiltersProvider.notifier);
    final counts = facetCounts.maybeWhen(
      data: (c) => c,
      orElse: () => const ReFacetCounts(),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        // Remove the default expansion-tile divider line.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Filtros',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            'Tipo, precio, m², habitaciones y más',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          children: [
            _SectionLabel('Tipo de propiedad'),
            _CountedChipWrap<String>(
              values: RE_PROPERTY_TYPES,
              labels: _propertyTypeLabels,
              selected: filters.propertyTypes,
              counts: counts.propertyType,
              onToggle: (v) => notifier.toggleString(
                'propertyTypes',
                value: v,
              ),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Rango de precio'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceMinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Mín',
                      prefixText: '$currencySymbol ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onCommitPrice(),
                    onEditingComplete: onCommitPrice,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-'),
                ),
                Expanded(
                  child: TextField(
                    controller: priceMaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Máx',
                      prefixText: '$currencySymbol ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onCommitPrice(),
                    onEditingComplete: onCommitPrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel('Superficie (m²)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: m2MinController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Mín',
                      suffixText: 'm²',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onCommitPrice(),
                    onEditingComplete: onCommitPrice,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-'),
                ),
                Expanded(
                  child: TextField(
                    controller: m2MaxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Máx',
                      suffixText: 'm²',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onCommitPrice(),
                    onEditingComplete: onCommitPrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel('Habitaciones'),
            _IntChipWrap(
              values: const [1, 2, 3, 4],
              selected: filters.rooms,
              onToggle: (v) => notifier.toggleInt('rooms', v),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Baños'),
            _IntChipWrap(
              values: const [1, 2, 3],
              selected: filters.bathrooms,
              onToggle: (v) => notifier.toggleInt('bathrooms', v),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Estado'),
            _CountedChipWrap<String>(
              values: RE_CONDITIONS,
              labels: _conditionLabels,
              selected: filters.conditions,
              counts: counts.condition,
              onToggle: (v) => notifier.toggleString('conditions', value: v),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Características'),
            _CountedChipWrap<String>(
              values: RE_FEATURE_KEYS,
              labels: _featureLabels,
              selected: filters.features,
              counts: null, // facets not exposed for features
              onToggle: (v) => notifier.toggleString('features', value: v),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Orientación'),
            _SimpleChipWrap<String>(
              values: RE_ORIENTATIONS,
              labels: _orientationLabels,
              selected: filters.orientation,
              onToggle: (v) => notifier.toggleString('orientation', value: v),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Planta'),
            _SimpleChipWrap<String>(
              values: RE_FLOOR_BUCKETS,
              labels: _floorBucketLabels,
              selected: filters.floorBuckets,
              onToggle: (v) => notifier.toggleString('floorBuckets', value: v),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Certificado energético'),
            _SimpleChipWrap<String>(
              values: const ['alta', 'media', 'baja'],
              labels: const {
                'alta': 'Alta (A-C)',
                'media': 'Media (D-E)',
                'baja': 'Baja (F-G)',
              },
              selected: filters.energyBands,
              onToggle: (v) => notifier.toggleString('energyBands', value: v),
            ),
            const SizedBox(height: 8),
            _SectionLabel('Letra específica'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: filters.energyLetter,
                  hint: const Text('No especificado'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No especificado'),
                    ),
                    ...RE_ENERGY_CERTS.map(
                      (l) => DropdownMenuItem<String?>(
                        value: l,
                        child: Text(l),
                      ),
                    ),
                  ],
                  onChanged: (v) => notifier.setEnergyLetter(v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Acepta mascotas'),
              value: filters.petsAllowed == true,
              onChanged: (v) => notifier.setPetsAllowed(v ? true : null),
            ),
            const SizedBox(height: 4),
            _SectionLabel('Publicado en los últimos'),
            _SimpleChipWrap<int>(
              values: const [7, 30, 90],
              labels: const {7: '7 días', 30: '30 días', 90: '90 días'},
              selected: filters.postedWithinDays == null
                  ? const []
                  : [filters.postedWithinDays!],
              onToggle: (v) => notifier.setPostedWithinDays(
                filters.postedWithinDays == v ? null : v,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _CountedChipWrap<T> extends StatelessWidget {
  final List<T> values;
  final Map<T, String> labels;
  final List<T> selected;
  final Map<String, int>? counts;
  final ValueChanged<T> onToggle;

  const _CountedChipWrap({
    required this.values,
    required this.labels,
    required this.selected,
    required this.counts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = selected.contains(v);
        final count = counts?[v.toString()];
        final labelText = count == null
            ? (labels[v] ?? v.toString())
            : '${labels[v] ?? v.toString()} ($count)';
        return FilterChip(
          label: Text(labelText),
          selected: isSelected,
          onSelected: (_) => onToggle(v),
        );
      }).toList(),
    );
  }
}

class _SimpleChipWrap<T> extends StatelessWidget {
  final List<T> values;
  final Map<T, String> labels;
  final List<T> selected;
  final ValueChanged<T> onToggle;

  const _SimpleChipWrap({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = selected.contains(v);
        return FilterChip(
          label: Text(labels[v] ?? v.toString()),
          selected: isSelected,
          onSelected: (_) => onToggle(v),
        );
      }).toList(),
    );
  }
}

class _IntChipWrap extends StatelessWidget {
  final List<int> values;
  final List<int> selected;
  final ValueChanged<int> onToggle;

  const _IntChipWrap({
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = selected.contains(v);
        return FilterChip(
          label: Text(v == values.last ? '$v+' : v.toString()),
          selected: isSelected,
          onSelected: (_) => onToggle(v),
        );
      }).toList(),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final ReSort value;
  final ValueChanged<ReSort> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Ordenar:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReSort>(
                isExpanded: true,
                value: value,
                items: const [
                  DropdownMenuItem(
                    value: ReSort.relevance,
                    child: Text('Relevancia'),
                  ),
                  DropdownMenuItem(
                    value: ReSort.recent,
                    child: Text('Más recientes'),
                  ),
                  DropdownMenuItem(
                    value: ReSort.priceAsc,
                    child: Text('Precio: menor a mayor'),
                  ),
                  DropdownMenuItem(
                    value: ReSort.priceDesc,
                    child: Text('Precio: mayor a menor'),
                  ),
                  DropdownMenuItem(
                    value: ReSort.sizeDesc,
                    child: Text('Mayor superficie'),
                  ),
                  DropdownMenuItem(
                    value: ReSort.pricePerM2,
                    child: Text('€/m²'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final AsyncValue<List<Listing>> results;
  const _ResultsGrid({required this.results});

  @override
  Widget build(BuildContext context) {
    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('Error: $e', style: TextStyle(color: AppColors.error)),
        ),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const Text('🏚️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'Sin resultados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prueba a quitar filtros.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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

class _Prompt extends StatelessWidget {
  const _Prompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('🏠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Selecciona un país y operación para empezar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Opcionalmente, elige una ciudad o usa el panel de filtros.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---- Localized label maps for the RE constant lists ----

const Map<String, String> _propertyTypeLabels = {
  'piso': 'Piso',
  'casa': 'Casa',
  'atico': 'Ático',
  'estudio': 'Estudio',
  'duplex': 'Dúplex',
  'chalet': 'Chalet',
  'loft': 'Loft',
  'local': 'Local',
  'oficina': 'Oficina',
  'terreno': 'Terreno',
  'garaje': 'Garaje',
};

const Map<String, String> _conditionLabels = {
  'obra_nueva': 'Obra nueva',
  'buen_estado': 'Buen estado',
  'a_reformar': 'A reformar',
};

const Map<String, String> _orientationLabels = {
  'norte': 'Norte',
  'sur': 'Sur',
  'este': 'Este',
  'oeste': 'Oeste',
};

const Map<String, String> _floorBucketLabels = {
  'bajos': 'Plantas bajas',
  'intermedias': 'Plantas intermedias',
  'ultima': 'Última planta',
};

const Map<String, String> _featureLabels = {
  'elevator': 'Ascensor',
  'parking': 'Parking',
  'terrace': 'Terraza',
  'balcony': 'Balcón',
  'garden': 'Jardín',
  'pool': 'Piscina',
  'storage_room': 'Trastero',
  'air_conditioning': 'Aire acondicionado',
  'heating': 'Calefacción',
  'built_in_wardrobes': 'Armarios empotrados',
  'furnished': 'Amueblado',
  'exterior': 'Exterior',
  'accessible': 'Accesible',
  'luxury': 'Lujo',
};
