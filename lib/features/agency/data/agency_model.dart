/// Agency profile + edit-input types. Mirrors the web's `agency` types in
/// `foxy_ads_web/src/lib/agency.ts`. Used by the agency dashboard, public
/// agency page, and leads inbox (Tasks 3, 7, 10, 12).
class AgencyProfile {
  final String userId;
  final String name;
  final String createdAt;
  final String? logoUrl;
  final String? description;
  final String? website;
  final String? phone;
  final String? location;
  final bool isVerified;

  const AgencyProfile({
    required this.userId,
    required this.name,
    required this.createdAt,
    this.logoUrl,
    this.description,
    this.website,
    this.phone,
    this.location,
    required this.isVerified,
  });

  factory AgencyProfile.fromRow(Map<String, dynamic> r) => AgencyProfile(
        userId: r['user_id'] as String? ?? '',
        name: (r['name'] ?? '') as String,
        logoUrl: r['logo_url'] as String?,
        description: r['description'] as String?,
        website: r['website'] as String?,
        phone: r['phone'] as String?,
        location: r['location'] as String?,
        isVerified: (r['is_verified'] as bool?) ?? false,
        createdAt: (r['created_at'] ?? '') as String,
      );
}

/// Mutable edit-input for the agency profile form. `toColumns` produces the
/// snake_case payload accepted by the Supabase `agencies` upsert.
class AgencyInput {
  final String name;
  final String? logoUrl;
  final String? description;
  final String? website;
  final String? phone;
  final String? location;

  const AgencyInput({
    required this.name,
    this.logoUrl,
    this.description,
    this.website,
    this.phone,
    this.location,
  });

  Map<String, dynamic> toColumns() => {
        'name': name.trim(),
        'logo_url': logoUrl,
        'description':
            (description?.trim().isEmpty ?? true) ? null : description!.trim(),
        'website':
            (website?.trim().isEmpty ?? true) ? null : website!.trim(),
        'phone': (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
        'location':
            (location?.trim().isEmpty ?? true) ? null : location!.trim(),
      };
}

enum AgencyValidationError { name, website, length }

/// Validation bounds are parity-locked to the web's `validateAgency` in
/// `foxy_ads_web/src/lib/agency.ts`. Tests in `test/agency_validation_test.dart`
/// pin these bounds.
AgencyValidationError? validateAgencyInput(AgencyInput input) {
  final name = input.name.trim();
  if (name.length < 2 || name.length > 120) {
    return AgencyValidationError.name;
  }
  final website = input.website?.trim();
  if (website != null && website.isNotEmpty) {
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(website)) {
      return AgencyValidationError.website;
    }
    if (website.length > 300) return AgencyValidationError.length;
  }
  if ((input.description?.length ?? 0) > 2000) {
    return AgencyValidationError.length;
  }
  if ((input.location?.length ?? 0) > 200) {
    return AgencyValidationError.length;
  }
  if ((input.phone?.length ?? 0) > 40) {
    return AgencyValidationError.length;
  }
  return null;
}
