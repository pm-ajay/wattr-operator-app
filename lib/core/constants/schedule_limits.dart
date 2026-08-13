/// Duration & gap guardrails for Scheduling and Auto Mode, per Phase 2 PRD
/// §2.2 — shared so the Schedule form and Auto Max Duration setting agree.
const scheduleMinDurationMinutes = 10;
const scheduleMaxDurationMinutes = 11 * 60;

/// Minimum gap required between two schedules on the same pump, even when
/// they don't technically overlap.
const scheduleMinGapMinutes = 30;
