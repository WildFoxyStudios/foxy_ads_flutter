// Unit tests for `mapReportSubmitError` (P12 F2) — the pure function that
// maps a `submit_listing_report` RPC failure (Postgrest error code +
// message) to a stable `ReportSubmitError` UI code.
//
// The RPC (foxy_ads_web/supabase/migrations/
// 20260722_listing_reports_validate_rpc.sql) raises SQLSTATE 22023 for TWO
// distinct conditions:
//   - "Listing not eligible for reports" (moderation-hidden listing)
//   - "Reporting is disabled" (app_settings.moderation_enabled = false)
// Both share the same SQLSTATE, so disambiguation must happen on the
// message text, not the code alone. These tests pin that behavior and the
// pre-existing 23505/42501/P0002/P0001 mappings.

import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/services/reports_service.dart';

void main() {
  group('mapReportSubmitError', () {
    test('23505 -> alreadyReported', () {
      expect(
        mapReportSubmitError('23505', 'duplicate key value'),
        ReportSubmitError.alreadyReported,
      );
    });

    test('42501 -> unauthenticated', () {
      expect(
        mapReportSubmitError('42501', 'Reporter identity mismatch'),
        ReportSubmitError.unauthenticated,
      );
    });

    test('P0002 -> listingUnavailable', () {
      expect(
        mapReportSubmitError('P0002', 'Listing not found'),
        ReportSubmitError.listingUnavailable,
      );
    });

    test('P0001 -> selfReport', () {
      expect(
        mapReportSubmitError('P0001', 'Cannot report your own listing'),
        ReportSubmitError.selfReport,
      );
    });

    test(
      '22023 with "Reporting is disabled" message -> moderationDisabled',
      () {
        expect(
          mapReportSubmitError('22023', 'Reporting is disabled'),
          ReportSubmitError.moderationDisabled,
        );
      },
    );

    test(
      '22023 with "Reporting is disabled" is matched case-insensitively',
      () {
        expect(
          mapReportSubmitError('22023', 'REPORTING IS DISABLED'),
          ReportSubmitError.moderationDisabled,
        );
      },
    );

    test(
      '22023 with a different message (moderation-hidden listing) does NOT '
      'map to moderationDisabled -- disambiguated by message substring, not '
      'the shared SQLSTATE',
      () {
        expect(
          mapReportSubmitError('22023', 'Listing not eligible for reports'),
          isNot(ReportSubmitError.moderationDisabled),
        );
      },
    );

    test('unknown code -> databaseError', () {
      expect(
        mapReportSubmitError('XXXXX', 'something unexpected'),
        ReportSubmitError.databaseError,
      );
    });

    test('null code/message -> databaseError', () {
      expect(
        mapReportSubmitError(null, null),
        ReportSubmitError.databaseError,
      );
    });
  });
}
