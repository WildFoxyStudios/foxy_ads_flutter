// Jobs key-facts table for the listing-detail screen (Task A3 of the P9
// sprint). Mirrors the web's `JobsKeyFacts`
// (foxy_ads_web/src/app/[locale]/anuncio/[id]/jobs/JobsKeyFacts.tsx), which
// reads the canonical jobs attributes JSONB map documented in the task
// spec:
//
//   Strings: contract_type (tiempo_completo | medio_tiempo | freelance |
//     practicas | temporal), modality (presencial | remoto | hibrido),
//     schedule (a_convenir | diurno | nocturno | fines_semana),
//     experience_required (sin_experiencia | junior | senior | experto),
//     category_professional (free text)
//   Numbers: salary_min, salary_max
//   String: salary_period (mes | hora | año, default 'mes' if absent)
//
// Visual style mirrors `ReKeyFacts`'s icon + value key-facts row (see
// `../../../real-estate/presentation/widgets/re_key_facts.dart`): each
// present fact renders as an icon + label/value block in a `Wrap`.
//
// Renders `SizedBox.shrink()` when `attributes` is null/empty or when none
// of the recognized keys are present.

import 'package:flutter/material.dart';

import '../../../../core/models/listing_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../l10n/app_localizations.dart';

num? _asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

String? _asString(dynamic v) => v is String && v.isNotEmpty ? v : null;

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

/// Formats a salary range as "min–max/period" (or a single bound when only
/// one of `min`/`max` is present). Returns null when neither bound is set.
String? formatSalaryRange({
  required num? min,
  required num? max,
  required String currency,
  required String locale,
  required String periodSuffix,
}) {
  if (min == null && max == null) return null;
  if (min != null && max != null) {
    return '${formatPrice(min, currency, locale)}–'
        '${formatPrice(max, currency, locale)}$periodSuffix';
  }
  return '${formatPrice((min ?? max)!, currency, locale)}$periodSuffix';
}

/// Jobs key-facts table for the listing-detail screen. Reads
/// `listing.attributes`; renders nothing for non-jobs listings or listings
/// without a recognized attribute set.
class JobsKeyFacts extends StatelessWidget {
  const JobsKeyFacts({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final attrs = listing.attributes;
    if (attrs == null || attrs.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    final contractType = _asString(attrs['contract_type']);
    final modality = _asString(attrs['modality']);
    final schedule = _asString(attrs['schedule']);
    final salaryMin = _asNum(attrs['salary_min']);
    final salaryMax = _asNum(attrs['salary_max']);
    final salaryPeriod = _asString(attrs['salary_period']) ?? 'mes';
    final experienceRequired = _asString(attrs['experience_required']);
    final categoryProfessional = _asString(attrs['category_professional']);

    final contractTypes = _contractTypeLabels(l10n);
    final modalities = _modalityLabels(l10n);
    final schedules = _scheduleLabels(l10n);
    final experienceLevels = _experienceLabels(l10n);
    final salaryPeriods = _salaryPeriodLabels(l10n);

    final salaryText = formatSalaryRange(
      min: salaryMin,
      max: salaryMax,
      currency: listing.currency,
      locale: l10n.localeName,
      periodSuffix: salaryPeriods[salaryPeriod] ?? salaryPeriods['mes']!,
    );

    final facts = <(IconData, String, String)>[
      if (contractType != null)
        (
          Icons.work_outline,
          l10n.jobsContractLabel,
          contractTypes[contractType] ?? contractType,
        ),
      if (modality != null)
        (
          Icons.home_work_outlined,
          l10n.jobsModalityLabel,
          modalities[modality] ?? modality,
        ),
      if (schedule != null)
        (
          Icons.schedule_outlined,
          l10n.jobsScheduleLabel,
          schedules[schedule] ?? schedule,
        ),
      if (salaryText != null)
        (Icons.payments_outlined, l10n.jobsSalaryLabel, salaryText),
      if (experienceRequired != null)
        (
          Icons.military_tech_outlined,
          l10n.jobsExperienceLabel,
          experienceLevels[experienceRequired] ?? experienceRequired,
        ),
      if (categoryProfessional != null)
        (
          Icons.category_outlined,
          l10n.jobsCategoryLabel,
          categoryProfessional,
        ),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 20,
      runSpacing: 16,
      children: facts
          .map(
            (f) => SizedBox(
              width: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.$1, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f.$2,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f.$3,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
