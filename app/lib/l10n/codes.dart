/// Maps backend codes (spec/api/codes.json) to localized text. Generated from the spec; keep
/// in sync with it (test/localized_codes_test.dart fails otherwise).
library;

import '../data/models.dart';
import 'generated/app_localizations.dart';

/// Localized text for an error code, or null if the code is unknown.
String? localizeError(AppLocalizations l, String code) => switch (code) {
  'image_missing' => l.errImageMissing,
  'image_too_large' => l.errImageTooLarge,
  'image_unreadable' => l.errImageUnreadable,
  'image_format_unsupported' => l.errImageFormatUnsupported,
  'image_too_small' => l.errImageTooSmall,
  'not_a_prescription' => l.errNotAPrescription,
  'ai_not_configured' => l.errAiNotConfigured,
  'ai_rate_limited' => l.errAiRateLimited,
  'ai_unavailable' => l.errAiUnavailable,
  'ai_refused' => l.errAiRefused,
  'ai_failed' => l.errAiFailed,
  'prescription_too_long' => l.errPrescriptionTooLong,
  'drug_not_found' => l.errDrugNotFound,
  'invalid_dose_pattern' => l.errInvalidDosePattern,
  'invalid_interval' => l.errInvalidInterval,
  'invalid_duration' => l.errInvalidDuration,
  'invalid_weekdays' => l.errInvalidWeekdays,
  'invalid_meal_times' => l.errInvalidMealTimes,
  'invalid_timezone' => l.errInvalidTimezone,
  'missing_dose' => l.errMissingDose,
  'conflicting_dose' => l.errConflictingDose,
  'network_error' => l.errorNetwork,
  _ => null,
};

/// Localized text for a notice, with its parameters filled in.
String? localizeNotice(AppLocalizations l, Notice n) {
  String p(String key) => n.params[key] ?? '';
  return switch (n.code) {
    'name_unreadable' => l.noticeNameUnreadable,
    'name_not_in_catalog' => l.noticeNameNotInCatalog,
    'name_corrected' => l.noticeNameCorrected(p('written')),
    'strength_not_in_catalog' => l.noticeStrengthNotInCatalog(p('written')),
    'strength_suggested' => l.noticeStrengthSuggested(p('suggested')),
    'dose_unreadable' => l.noticeDoseUnreadable(p('written')),
    'dose_missing' => l.noticeDoseMissing,
    'dose_as_needed' => l.noticeDoseAsNeeded,
    'timing_not_specified' => l.noticeTimingNotSpecified,
    'duration_unclear' => l.noticeDurationUnclear,
    'duration_out_of_range' => l.noticeDurationOutOfRange(p('days')),
    'duration_missing' => l.noticeDurationMissing,
    'image_poor_quality' => l.noticeImagePoorQuality,
    'no_medicines_found' => l.noticeNoMedicinesFound,
    'review_highlighted_fields' => l.noticeReviewHighlightedFields,
    _ => null,
  };
}
