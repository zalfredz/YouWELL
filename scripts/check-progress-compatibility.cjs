const assert = require('node:assert/strict');

module.exports = async function checkProgressCompatibility({ db, asUser, owner, reader, admin }) {
  // Manual SQL Editor users may rerun this file: the original strict save
  // must not be replaced by its own wrapper (which would recurse forever).
  await db.exec(require('node:fs').readFileSync(require('node:path').join(__dirname,
    '../supabase/migrations/20261108120000_legacy_progress_compatibility.sql'), 'utf8'));
  const get = async () => (await db.query('select * from public.youwell_progress where user_id = $1', [owner])).rows[0];
  let row = await get();
  // A legitimate early v3 client omitted newer optional fields, serialized
  // empty maps as [] and accidentally carried a private local note.
  const old = {
    schemaVersion: 1, version: 3, profile: row.payload.profile,
    days: { '2026-10-23': { quests: [], note: 'must stay local' } },
    capacity: [], oldPreviewFlag: true,
    habitSwaps: [{ id: 'legacy-count-only', day: '2026-10-23', time: '09:00', outcome: 'used' }],
  };
  await asUser(owner, 'aal1', async () => {
    const r = (await db.query('select public.save_youwell_progress($1, $2) as r', [old, row.revision])).rows[0].r;
    assert.equal(r.saved, true);
    assert.deepEqual(r.snapshot.payload.capacity, {});
    assert.deepEqual(r.snapshot.payload.mobileRewards, {});
    assert.deepEqual(r.snapshot.payload.mealCheckIns, row.payload.mealCheckIns, 'a collection missing from an old client is preserved');
    assert.equal(r.snapshot.payload.oldPreviewFlag, undefined);
    assert.equal(r.snapshot.payload.days['2026-10-23'].note, undefined);
    assert.deepEqual(r.snapshot.payload.habitSwaps, [{ id: 'legacy-count-only', day: '2026-10-23' }]);
    assert.deepEqual(r.snapshot.payload.usageTotals, row.payload.usageTotals, 'omitted daily totals are retained');
  });
  row = await get();
  const edited = {
    ...row.payload,
    usageTotals: [{ day: '2026-10-23', type: 'rokok', total: 12, confirmed: true, source: 'admin' }],
    swapResults: [{ day: '2026-10-23', type: 'rokok', tried: 3, skipped: 2, used: 1, source: 'admin' }],
    openedDays: ['2026-10-23'], adminOpenedDays: ['2026-10-23'],
    habitSwaps: [{ id: 'admin-recovered-1', day: '2026-10-23' }],
  };
  await asUser(admin, 'aal2', async () => {
    const r = (await db.query('select public.admin_write_youwell_progress($1,$2,$3,$4,$5) as r',
      [owner, row.revision, edited, 'Restore confirmed participant records', [{ kind: 'usage' }]])).rows[0].r;
    assert.equal(r.saved, true);
  });
  row = await get();
  await asUser(owner, 'aal1', async () => {
    const stalePhone = { ...old, habitSwaps: [], usageTotals: [], swapResults: [] };
    const r = (await db.query('select public.save_youwell_progress($1,$2) as r', [stalePhone, row.revision])).rows[0].r;
    assert.equal(r.saved, true);
    assert.equal(r.snapshot.payload.usageTotals[0].total, 12);
    assert.deepEqual(r.snapshot.payload.swapResults, edited.swapResults);
    assert.deepEqual(r.snapshot.payload.adminOpenedDays, ['2026-10-23']);
    assert.deepEqual(r.snapshot.payload.openedDays, ['2026-10-23']);
    assert.deepEqual(r.snapshot.payload.habitSwaps, [{ id: 'admin-recovered-1', day: '2026-10-23' }]);
  });
  row = await get();
  await asUser(owner, 'aal1', async () => {
    const withLegacyTotal = { ...old, usageTotals: [{ day: '2026-10-24', type: 'cigarette', total: '7', confirmed: true, time: '08:00' }] };
    const r = (await db.query('select public.save_youwell_progress($1,$2) as r', [withLegacyTotal, row.revision])).rows[0].r;
    assert.equal(r.saved, true);
    const total = r.snapshot.payload.usageTotals.find(x => x.day === '2026-10-24');
    assert.deepEqual(total, { day: '2026-10-24', type: 'rokok', total: 7, confirmed: true });
    assert.equal(r.snapshot.payload.usageTotals.find(x => x.source === 'admin').total, 12);
    assert.deepEqual(r.snapshot.payload.swapResults, edited.swapResults, 'omitted Habit Swap outcomes are preserved');
  });
  row = await get();
  await asUser(owner, 'aal1', async () => {
    for (const usage of [
      { day: '2026-02-30', type: 'rokok', total: 1 },
      { day: 'not-a-day', type: 'rokok', total: 1 },
      { day: '2026-10-24', type: 'rokok', total: 501 },
      { day: '2026-10-24', type: 'rokok', total: -1 },
      { day: '2026-10-24', type: 'rokok', total: 1.5 },
      { day: '2026-10-24', type: 'rokok', total: 1, confirmed: 'yes' },
    ]) {
      await assert.rejects(() => db.query('select public.save_youwell_progress($1,$2)',
        [{ ...old, usageTotals: [usage] }, row.revision]), error => error.code === '22023');
    }
    for (const bad of [{ ...old, days: [1] }, { ...old, habitSwaps: 'broken' }, { ...old, version: 4 }]) {
      await assert.rejects(() => db.query('select public.save_youwell_progress($1,$2)', [bad, row.revision]), error => error.code === '22023');
    }
    const conflict = (await db.query('select public.save_youwell_progress($1,$2) as r', [old, Number(row.revision) - 1])).rows[0].r;
    assert.equal(conflict.saved, false, 'legacy compatibility never bypasses revision checks');
    for (const fn of ['youwell_save_progress_strict_v3(jsonb,bigint)', 'youwell_admin_write_strict_v3(uuid,bigint,jsonb,text,jsonb)']) {
      assert.equal((await db.query("select has_function_privilege('authenticated', $1, 'execute') as allowed", [fn])).rows[0].allowed, false);
    }
    await assert.rejects(() => db.query('select private.youwell_normalize_progress($1)', [old]), error => error.code === '42501');
  });
  assert.equal(Number((await get()).revision), Number(row.revision), 'rejected data did not change any revision');
  await asUser(reader, 'aal1', async () => {
    await assert.rejects(() => db.query('select public.admin_write_youwell_progress($1,$2,$3,$4,$5)',
      [owner, row.revision, edited, 'Unauthorized edit', []]), error => error.code === '42501');
  });
  await asUser(owner, 'aal1', async () => {
    const reset = { ...old, profile: null, days: {}, capacity: {}, habitSwaps: [],
      usageTotals: [], openedDays: [], activityDays: [] };
    const r = (await db.query('select public.save_youwell_progress($1,$2) as r', [reset, row.revision])).rows[0].r;
    assert.equal(r.saved, true);
    assert.equal(r.snapshot.payload.profile, null);
    assert.deepEqual(r.snapshot.payload.usageTotals, [], 'explicit reset can still clear corrected totals');
    assert.deepEqual(r.snapshot.payload.habitSwaps, []);
  });
  console.log('Legacy sync passed: defaults, privacy projection, numeric totals, corrections preserved, invalid values rejected, MFA/revisions unchanged.');
};
