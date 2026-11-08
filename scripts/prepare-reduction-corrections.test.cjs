const { test } = require('node:test');
const assert = require('node:assert/strict');
const { prepare } = require('./prepare-reduction-corrections.cjs');

function fixture() {
  // Synthetic test data only; real participant records stay under .tools/.
  const participants = ['P5', 'P6', 'P7', 'P8', 'P9', 'P10'].map((code, i) => ({
    code, sourceId: i < 3 ? `R${i + 1}` : `V${i - 2}`, type: i < 3 ? 'rokok' : 'vape',
    consumption: Array.from({ length: 4 }, () => Array(7).fill(1)),
    swaps: Array.from({ length: 4 }, () => Array.from({ length: 7 }, () => [1, 1])),
    claimedWeekly: Array.from({ length: 4 }, () => [14, 7, 7]),
  }));
  const overview = participants.map((p, i) => ({ code: p.code,
    account: `00000000-0000-4000-8000-${String(i + 1).padStart(12, '0')}`,
    revision: 3, study_path: 'reduction', study_started: '2026-10-25',
    payload: { profile: { path: 'reduction', started: '2026-10-20' }, openedDays: [],
      usageTotals: [{ day: '2026-12-01', type: p.type, total: 10 }] },
  }));
  return { source: { participants }, overview };
}
test('Day 15 cutoff uses locked study date, no future days or inferred logins', () => {
  const { source, overview } = fixture(), before = JSON.stringify(overview);
  const plan = prepare(source, overview, '2026-11-08');
  assert.equal(plan.applied, false);
  assert.equal(plan.changesLoginDays, false);
  for (const p of plan.participants) {
    assert.equal(p.throughStudyDay, 15);
    assert.equal(p.daily[14].day, '2026-11-08');
    assert.equal(p.daily[0].day, '2026-10-25');
    assert.deepEqual(p.weeks.map(w => w.days), [7, 7, 1]);
    assert.equal(p.proposedSwapResults.length, 15);
    assert.deepEqual(p.proposedSwapResults[0], {
      day: '2026-10-25', type: p.daily[0].type,
      tried: 2, skipped: 1, used: 1, source: 'admin',
    });
    assert.equal(p.proposedUsageTotals.find(r => r.day === '2026-12-01').total, 10);
  }
  assert.equal(JSON.stringify(overview), before);
});
test('Boundaries: no records before start, stop at 28, all weekly totals match', () => {
  const { source, overview } = fixture();
  assert.equal(prepare(source, overview, '2026-10-24').participants[0].throughStudyDay, 0);
  assert.equal(prepare(source, overview, '2026-10-25').participants[0].throughStudyDay, 1);
  const p = prepare(source, overview, '2026-12-30').participants[0];
  assert.equal(p.throughStudyDay, 28);
  assert.deepEqual(p.weeks.map(w => [w.swaps, w.skipped, w.used]), Array.from({ length: 4 }, () => [14, 7, 7]));
});
test('Reject ambiguous identities, broken dates, totals and weekly inconsistencies', () => {
  for (const mutate of [
    x => x.overview.push(x.overview[0]),
    x => { x.overview[0].study_started = '2026-02-30'; },
    x => { x.overview[0].study_path = 'wellness'; },
    x => { x.overview[0].account = x.overview[1].account; },
    x => { x.source.participants[0].consumption[0][0] = 16; },
    x => { x.source.participants[0].claimedWeekly[0][0] = 0; },
  ]) {
    const x = fixture(); mutate(x);
    assert.throws(() => prepare(x.source, x.overview, '2026-11-08'));
  }
});
