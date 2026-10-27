import 'package:youwell/core/types/json_map.dart';

/// Researcher dashboard data. Every call is for allowlisted admins with MFA;
/// the server refuses anyone else.
abstract interface class ResearchStore {
  /// Every account's synced progress, with its alias and assigned code.
  Future<List<JsonMap>> progressOverview();

  /// Assigns P1–P10 to an account; null removes its code.
  Future<void> setParticipantCode(String account, String? code);

  /// Saves an admin-edited snapshot. False when the participant synced in
  /// the meantime (reload and edit again).
  Future<bool> writeProgress({
    required String account,
    required int expectedRevision,
    required JsonMap payload,
    required String reason,
    required List<JsonMap> changes,
  });

  /// Every admin intervention, newest first.
  Future<List<JsonMap>> interventions();

  /// Earlier snapshots of one account, newest first.
  Future<List<JsonMap>> history(String account);

  /// Puts an earlier snapshot back as an admin intervention.
  Future<void> restoreRevision(String account, int revision, String reason);
}

/// Weekly research columns (proposal §3.3), one row per code and week.
const researchCsvColumns = [
  'participant_code',
  'week',
  'week_complete',
  'opened_days',
  'active_days',
  'active',
  'quests_done',
  'ladder_gerak',
  'ladder_istirahat',
  'ladder_tidur',
  'ladder_hidrasi',
  'ladder_makan',
  'ladder_jeda',
  'delay_craving_count',
  'delay_craving_completed',
  'habit_swap_count',
  'synced_at',
  // Added 27 Oct 2026 (latest proposal, admin Overview).
  'quests_by_admin',
  'cigarettes_total',
  'vape_total',
  'usage_days_logged',
  'admin_intervention',
  'opened_days_by_admin',
];

/// Daily smoking/vaping totals per code (latest proposal): numbers only.
const usageCsvColumns = [
  'participant_code',
  'day',
  'study_day',
  'type',
  'total',
  'confirmed',
  'source',
];

/// Plain CSV for spreadsheets; values are quoted when needed.
String toCsv(List<String> columns, List<JsonMap> rows) {
  String cell(Object? value) {
    final text = value?.toString() ?? '';
    return RegExp(r'[",\n\r]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  return [
    columns.join(','),
    for (final row in rows)
      columns.map((column) => cell(row[column])).join(','),
  ].join('\n');
}
