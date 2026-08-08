// Jobs attribute form widget (P9 B3: jobs create attribute form).
//
// Renders the structured jobs fields that match the CANONICAL `attributes`
// JSONB schema read by `JobsKeyFacts` (`jobs_key_facts.dart`), the web
// detail page, and the `validate_listing_attributes()` DB trigger:
//
//   Required: contract_type, modality.
//   Optional: schedule, salary_min, salary_max, salary_period (default
//     'mes' when a salary bound is set but no period is chosen),
//     experience_required, category_professional.
//
// Mirrors `ReAttributeForm`'s structure/API 1:1 (see
// `../../../real-estate/presentation/widgets/re_attribute_form.dart`):
//   - constructor takes `initialAttributes`, `onChanged`, `onValidityChanged`
//   - `_encode()` builds the canonical map, omitting unset optional keys
//     (no `null` leaks)
//   - `_isValid` gates on the required fields only
//   - `_emit()` fires both callbacks after every change, and once after the
//     first frame so the parent always has a (possibly empty) map + validity
//     flag even on a no-op submit.
//
// The parent (`create_listing_screen.dart`) stores the latest map in its
// `_jobsAttributes` field and writes it to `updates['attributes']` /
// `extraFields['attributes']` at submit time, gated on
// `_jobsAttributesValid`.

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Canonical wire values, mirrored from
/// `foxy_ads_web/src/app/[locale]/publicar/_attributes/schema.ts`
/// (JOB_CONTRACT_TYPES / JOB_MODALITIES / JOB_SCHEDULES /
/// JOB_EXPERIENCE_LEVELS / JOB_SALARY_PERIODS).
const List<String> JOBS_CONTRACT_TYPES = [
  'tiempo_completo',
  'medio_tiempo',
  'freelance',
  'practicas',
  'temporal',
];

const List<String> JOBS_MODALITIES = [
  'presencial',
  'remoto',
  'hibrido',
];

const List<String> JOBS_SCHEDULES = [
  'a_convenir',
  'diurno',
  'nocturno',
  'fines_semana',
];

const List<String> JOBS_EXPERIENCE_LEVELS = [
  'sin_experiencia',
  'junior',
  'senior',
  'experto',
];

const List<String> JOBS_SALARY_PERIODS = [
  'mes',
  'hora',
  'año',
];

Map<String, String> _contractTypeLabels(AppLocalizations l10n) => {
      'tiempo_completo': l10n.jobsContractTypeFullTime,
      'medio_tiempo': l10n.jobsContractTypePartTime,
      'freelance': l10n.jobsContractTypeFreelance,
      'practicas': l10n.jobsContractTypeInternship,
      'temporal': l10n.jobsContractTypeTemporary,
    };

Map<String, String> _modalityLabels(AppLocalizations l10n) => {
      'presencial': l10n.jobsModalityOnsite,
      'remoto': l10n.jobsModalityRemote,
      'hibrido': l10n.jobsModalityHybrid,
    };

Map<String, String> _scheduleLabels(AppLocalizations l10n) => {
      'a_convenir': l10n.jobsScheduleToBeAgreed,
      'diurno': l10n.jobsScheduleDaytime,
      'nocturno': l10n.jobsScheduleNighttime,
      'fines_semana': l10n.jobsScheduleWeekends,
    };

Map<String, String> _experienceLabels(AppLocalizations l10n) => {
      'sin_experiencia': l10n.jobsExperienceNone,
      'junior': l10n.jobsExperienceJunior,
      'senior': l10n.jobsExperienceSenior,
      'experto': l10n.jobsExperienceExpert,
    };

Map<String, String> _salaryPeriodLabels(AppLocalizations l10n) => {
      'mes': l10n.jobsSalaryPeriodMonth,
      'hora': l10n.jobsSalaryPeriodHour,
      'año': l10n.jobsSalaryPeriodYear,
    };

class JobsAttributeForm extends StatefulWidget {
  const JobsAttributeForm({
    super.key,
    this.initialAttributes,
    required this.onChanged,
    this.onValidityChanged,
  });

  /// Prefill values (edit mode). The map keys match the canonical schema:
  /// `contract_type`, `modality`, `schedule`, `salary_min`, `salary_max`,
  /// `salary_period`, `experience_required`, `category_professional`.
  final Map<String, dynamic>? initialAttributes;

  /// Fired on every change with the latest encoded map (empty when nothing
  /// is set).
  final void Function(Map<String, dynamic> attributes) onChanged;

  /// Fired alongside `onChanged` with whether the required fields
  /// (contract_type, modality) are both set. The create/edit screen uses
  /// this to block submit.
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<JobsAttributeForm> createState() => _JobsAttributeFormState();
}

class _JobsAttributeFormState extends State<JobsAttributeForm> {
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _categoryProfessionalController = TextEditingController();

  String? _contractType;
  String? _modality;
  String? _schedule;
  String? _salaryPeriod;
  String? _experienceRequired;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAttributes;
    if (init != null) {
      _contractType = init['contract_type'] as String?;
      _modality = init['modality'] as String?;
      _schedule = init['schedule'] as String?;
      _salaryMinController.text = _numToText(init['salary_min']);
      _salaryMaxController.text = _numToText(init['salary_max']);
      _salaryPeriod = init['salary_period'] as String?;
      _experienceRequired = init['experience_required'] as String?;
      _categoryProfessionalController.text =
          (init['category_professional'] as String?) ?? '';
    }
    // Fire onChanged/onValidityChanged once after the first frame so the
    // parent always has a map (possibly empty) + validity flag to work with
    // even on a no-op submit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  @override
  void dispose() {
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _categoryProfessionalController.dispose();
    super.dispose();
  }

  static String _numToText(dynamic v) => v == null ? '' : v.toString();

  /// Required fields per the canonical schema: contract_type, modality.
  bool get _isValid => _contractType != null && _modality != null;

  /// Encode the current form state into the canonical JSONB map. Omit any
  /// key whose value is empty/null. `salary_period` defaults to 'mes' when a
  /// salary bound is set but no period was chosen; it is omitted entirely
  /// when neither salary bound is set.
  Map<String, dynamic> _encode() {
    final out = <String, dynamic>{};

    if (_contractType != null) out['contract_type'] = _contractType;
    if (_modality != null) out['modality'] = _modality;
    if (_schedule != null) out['schedule'] = _schedule;

    final salaryMin = num.tryParse(_salaryMinController.text.trim());
    if (salaryMin != null) out['salary_min'] = salaryMin;

    final salaryMax = num.tryParse(_salaryMaxController.text.trim());
    if (salaryMax != null) out['salary_max'] = salaryMax;

    if (salaryMin != null || salaryMax != null) {
      out['salary_period'] = _salaryPeriod ?? 'mes';
    }

    if (_experienceRequired != null) {
      out['experience_required'] = _experienceRequired;
    }

    final categoryProfessional = _categoryProfessionalController.text.trim();
    if (categoryProfessional.isNotEmpty) {
      out['category_professional'] = categoryProfessional;
    }

    return out;
  }

  void _emit() {
    widget.onChanged(_encode());
    widget.onValidityChanged?.call(_isValid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contractTypes = _contractTypeLabels(l10n);
    final modalities = _modalityLabels(l10n);
    final schedules = _scheduleLabels(l10n);
    final experienceLevels = _experienceLabels(l10n);
    final salaryPeriods = _salaryPeriodLabels(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading so the parent form has a visual divider for the
        // jobs-specific block (the parent renders this widget conditionally).
        Text(
          l10n.jobsFormHeading,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // contract_type (chips, required).
        Text(
          '${l10n.jobsContractLabel} *',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: JOBS_CONTRACT_TYPES.map((c) {
            final selected = _contractType == c;
            return ChoiceChip(
              label: Text(contractTypes[c] ?? c),
              selected: selected,
              onSelected: (_) {
                setState(() => _contractType = c);
                _emit();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // modality (chips, required).
        Text(
          '${l10n.jobsModalityLabel} *',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: JOBS_MODALITIES.map((m) {
            final selected = _modality == m;
            return ChoiceChip(
              label: Text(modalities[m] ?? m),
              selected: selected,
              onSelected: (_) {
                setState(() => _modality = m);
                _emit();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // schedule (dropdown, optional).
        DropdownButtonFormField<String>(
          initialValue: _schedule,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.jobsScheduleLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...JOBS_SCHEDULES.map(
              (s) => DropdownMenuItem<String>(
                value: s,
                child: Text(schedules[s] ?? s),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _schedule = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // salary_min + salary_max in a row (both optional).
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _salaryMinController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: l10n.jobsFormSalaryMinLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _salaryMaxController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: l10n.jobsFormSalaryMaxLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // salary_period (dropdown, optional; defaults to 'mes' at encode
        // time when a salary bound is set but no period is chosen here).
        DropdownButtonFormField<String>(
          initialValue: _salaryPeriod,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.jobsFormSalaryPeriodLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...JOBS_SALARY_PERIODS.map(
              (p) => DropdownMenuItem<String>(
                value: p,
                child: Text(salaryPeriods[p] ?? p),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _salaryPeriod = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // experience_required (dropdown, optional).
        DropdownButtonFormField<String>(
          initialValue: _experienceRequired,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.jobsExperienceLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.realEstateEnergyLetterNone),
            ),
            ...JOBS_EXPERIENCE_LEVELS.map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(experienceLevels[e] ?? e),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _experienceRequired = v);
            _emit();
          },
        ),
        const SizedBox(height: 16),

        // category_professional (free text, optional).
        TextFormField(
          controller: _categoryProfessionalController,
          decoration: InputDecoration(
            labelText: l10n.jobsCategoryLabel,
            hintText: l10n.jobsFormCategoryProfessionalHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
