// Offline preview only. Does not connect to Supabase or write participant data.
// node scripts/prepare-reduction-corrections.cjs SOURCE OVERVIEW YYYY-MM-DD OUT
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');

const mapping = { P5: ['R1', 'rokok'], P6: ['R2', 'rokok'], P7: ['R3', 'rokok'], P8: ['V1', 'vape'], P9: ['V2', 'vape'], P10: ['V3', 'vape'] };
function date(day) {
  assert.match(day ?? '', /^\d{4}-\d{2}-\d{2}$/, 'Expected calendar date YYYY-MM-DD');
  const time = Date.parse(`${day}T00:00:00Z`);
  assert.ok(Number.isFinite(time) && new Date(time).toISOString().slice(0, 10) === day, 'Invalid calendar date');
  return time;
}
function validateSource(source) {
  assert.equal(source.participants?.length, 6, 'Exactly P5-P10 are required');
  assert.equal(new Set(source.participants.map(p => p.code)).size, 6, 'Duplicate code');
  for (const p of source.participants) {
    assert.deepEqual([p.sourceId, p.type], mapping[p.code], `Incorrect mapping for ${p.code}`);
    assert.equal(p.consumption.length, 4);
    assert.equal(p.swaps.length, 4);
    assert.equal(p.claimedWeekly.length, 4);
    for (let week = 0; week < 4; week++) {
      assert.equal(p.consumption[week].length, 7);
      assert.equal(p.swaps[week].length, 7);
      for (const total of p.consumption[week]) {
        assert.ok(Number.isInteger(total) && total >= 0 && total <= (p.type === 'rokok' ? 15 : 500), 'Consumption outside supplied limits');
      }
      let skipped = 0, used = 0;
      for (const pair of p.swaps[week]) {
        assert.equal(pair.length, 2);
        assert.ok(pair.every(n => Number.isInteger(n) && n >= 0 && n <= 100), 'Invalid Habit Swap pair');
        skipped += pair[0]; used += pair[1];
      }
      assert.deepEqual([skipped + used, skipped, used], p.claimedWeekly[week], `${p.code} week ${week + 1}: daily pairs do not match supplied weekly sums`);
    }
  }
}
function prepare(source, overview, asOf) {
  validateSource(source);
  const until = date(asOf);
  assert.ok(Array.isArray(overview), 'Expected an array from the admin overview export');
  const accounts = new Set();
  const participants = source.participants.map(p => {
    const matches = overview.filter(row => row.code === p.code);
    assert.equal(matches.length, 1, `Need exactly one current admin account for ${p.code}`);
    const row = matches[0];
    assert.match(row.account ?? '', /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, 'Missing account UUID');
    assert.ok(!accounts.has(row.account), 'Same account mapped to more than one code');
    accounts.add(row.account);
    assert.ok(Number.isSafeInteger(Number(row.revision)) && Number(row.revision) > 0, 'Missing revision');
    assert.ok(row.payload && typeof row.payload === 'object' && !Array.isArray(row.payload), 'Missing snapshot');
    assert.equal(row.study_path ?? row.payload.profile?.path, 'reduction', `${p.code} is not in the reduction study group`);
    const selected = row.payload.reductionSettings?.product ?? row.payload.profile?.nicotineProduct;
    const productChoice = p.type === 'rokok' ? 'cigarette' : 'vape';
    assert.ok(selected == null || selected === productChoice,
      `${p.code}: saved product conflicts with the supplied UAT mapping`);
    // Source values are Monday–Sunday. Preserve the participant's real
    // study dates and choose the matching weekday value for each login day.
    const started = row.study_started ?? row.payload.profile?.started;
    const start = date(started);
    const opened = row.payload.openedDays;
    assert.ok(Array.isArray(opened), `${p.code}: openedDays is missing or malformed`);
    const loginDays = [...new Set(opened.map(day => {
      const value = String(day);
      date(value);
      return value;
    }))].filter(day => day >= started && day <= asOf).sort();
    assert.ok(loginDays.length > 0 && loginDays.length <= 20,
      `${p.code}: expected 1–20 recorded login days; found ${loginDays.length}`);
    const dayMs = 86400000;
    const monday = start - ((new Date(start).getUTCDay() + 6) % 7) * dayMs;
    const daily = loginDays.map(day => {
      const offset = (date(day) - monday) / dayMs;
      const week = Math.floor(offset / 7), index = offset % 7;
      assert.ok(week >= 0 && week < 4, `${p.code}: login ${day} falls outside the 28-day source`);
      const [skipped, used] = p.swaps[week][index];
      return {
        studyDay: Math.floor((date(day) - start) / dayMs) + 1,
        sourceWeek: week + 1,
        sourceWeekday: index + 1,
        day,
        type: p.type, total: p.consumption[week][index],
        confirmed: true, source: 'admin',
        swapAttempted: skipped + used, swapSkipped: skipped, swapUsed: used,
        swapUnknown: 0,
      };
    });
    const existingUsage = row.payload.usageTotals ?? [];
    assert.ok(Array.isArray(existingUsage), 'Malformed usageTotals needs repair before preview');
    const studyWindow = new Set(Array.from({ length: 28 }, (_, offset) =>
      new Date(start + offset * dayMs).toISOString().slice(0, 10)));
    const usageTotals = [
      ...existingUsage.filter(r => !(['rokok', 'vape'].includes(r.type) && studyWindow.has(r.day))),
      ...daily.map(({ day, type, total, confirmed, source }) => ({ day, type, total, confirmed, source })),
    ].sort((a, b) => `${a.day}:${a.type}`.localeCompare(`${b.day}:${b.type}`));
    const existingResults = row.payload.swapResults ?? [];
    assert.ok(Array.isArray(existingResults), 'Malformed swapResults needs repair before preview');
    const swapResults = [
      ...existingResults.filter(r => !(['rokok', 'vape'].includes(r.type) && studyWindow.has(r.day))),
      ...daily.map(r => ({ day: r.day, type: r.type, tried: r.swapAttempted,
        skipped: r.swapSkipped, used: r.swapUsed, source: 'admin' })),
    ].sort((a, b) => `${a.day}:${a.type}`.localeCompare(`${b.day}:${b.type}`));
    const existingAttempts = row.payload.habitSwaps ?? [];
    assert.ok(Array.isArray(existingAttempts), 'Malformed habitSwaps needs repair before preview');
    const habitSwaps = [
      ...existingAttempts.filter(r => !studyWindow.has(r.day)),
      ...daily.flatMap(r => Array.from({ length: r.swapAttempted }, (_, i) => ({
        id: `admin-swap-${r.day}-${i}`, day: r.day,
      }))),
    ];
    const weeks = Array.from({ length: 4 }, (_, w) => {
      const days = daily.filter(d => d.sourceWeek === w + 1);
      return { week: w + 1, days: days.length,
        consumptionTotal: days.reduce((sum, d) => sum + d.total, 0),
        swaps: days.reduce((sum, d) => sum + d.swapAttempted, 0),
        skipped: days.reduce((sum, d) => sum + d.swapSkipped, 0),
        used: days.reduce((sum, d) => sum + d.swapUsed, 0) };
    }).filter(w => w.days > 0);
    const proposedPayload = JSON.parse(JSON.stringify(row.payload));
    proposedPayload.reductionSettings = {
      ...(proposedPayload.reductionSettings ?? {}), product: productChoice,
    };
    proposedPayload.usageTotals = usageTotals;
    proposedPayload.swapResults = swapResults;
    proposedPayload.habitSwaps = habitSwaps;
    const warnings = loginDays.length < 18
      ? [`${p.code} memiliki ${loginDays.length} hari login; ekspektasi pengguna 18–20.`]
      : [];
    return {
      code: p.code, sourceId: p.sourceId, account: row.account,
      expectedRevision: Number(row.revision), studyStarted: started,
      actualLoginDays: loginDays.length, loginDayKeys: loginDays,
      throughStudyDay: Math.max(...daily.map(d => d.studyDay)),
      warnings,
      studyWindowDays: [...studyWindow],
      originalPayloadSha256: crypto.createHash('sha256').update(JSON.stringify(row.payload)).digest('hex'),
      daily, weeks,
      proposedProductChoice: productChoice,
      proposedUsageTotals: usageTotals,
      proposedSwapResults: swapResults,
      proposedHabitSwaps: habitSwaps,
      proposedPayload,
      // A result is not a timestamp or a login. No quest/XP/card is inferred.
      unchanged: ['profile', 'openedDays', 'adminOpenedDays', 'activityDays', 'days', 'capacity', 'XP'],
      habitSwapPlan: {
        storage: 'swapResults daily aggregates; requires server migrations 13 and 14',
        countsIncludeExistingRecords: true,
        replaceCoveredCountsRatherThanAppend: true,
        includeUnknownSeparately: true,
        fabricateActivityOrTriggerOrTime: false,
      },
    };
  });
  return { mode: 'preview-only', asOf, applied: false, changesLoginDays: false,
    identitySource: 'existing admin overview, matched by participant code',
    rawSourceIsParticipantRecord: 'user attested; preserve source outside Git',
    warnings: participants.flatMap(p => p.warnings),
    requiredBeforeApply: ['fresh server revision checks', 'snapshot backup and audit reason', 'server migrations 13-15 applied and a reviewed preview'],
    participants };
}

module.exports = { prepare, validateSource };
if (require.main === module) {
  try {
    const [sourcePath, overviewPath, asOf, outputPath] = process.argv.slice(2);
    assert.ok(sourcePath && overviewPath && asOf && outputPath, 'Usage: node scripts/prepare-reduction-corrections.cjs SOURCE OVERVIEW YYYY-MM-DD OUT');
    const plan = prepare(JSON.parse(fs.readFileSync(sourcePath, 'utf8')), JSON.parse(fs.readFileSync(overviewPath, 'utf8')), asOf);
    // Never overwrite the source records or the snapshot backup.
    assert.ok(![sourcePath, overviewPath].includes(outputPath), 'Output must be a separate file');
    fs.writeFileSync(outputPath, JSON.stringify(plan, null, 2), { flag: 'wx' });
    console.log(JSON.stringify({ applied: false, changesLoginDays: false, participants: plan.participants.map(p => ({ code: p.code, actualLoginDays: p.actualLoginDays, throughStudyDay: p.throughStudyDay, weeks: p.weeks })) }, null, 2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
