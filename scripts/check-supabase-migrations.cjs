// Run from the repo root after installing the isolated test dependency:
// npm install --prefix .tools/sql-check --no-audit --no-fund @electric-sql/pglite
// node scripts/check-supabase-migrations.cjs
// Uses an in-memory PostgreSQL database, never a real Supabase project.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require('../.tools/sql-check/node_modules/@electric-sql/pglite');

const owner = '11111111-1111-4111-8111-111111111111';
const reader = '22222222-2222-4222-8222-222222222222';
const admin = '33333333-3333-4333-8333-333333333333';
const approved = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const pending = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

async function main() {
  const db = await PGlite.create();
  try {
    // Only the Auth/Storage interfaces referenced by our migrations are mocked.
    // Roles, grants, RLS and SECURITY DEFINER use PostgreSQL's real behavior.
    await db.exec(`
      create role anon;
      create role authenticated;
      create schema auth;
      create schema storage;
      create table auth.users (
        id uuid primary key, email text, email_confirmed_at timestamptz
      );
      create table auth.identities (
        user_id uuid references auth.users(id) on delete cascade, provider text
      );
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;
      create function auth.jwt() returns jsonb language sql stable as $$
        select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
      $$;
      create table storage.buckets (
        id text primary key, name text, public boolean,
        file_size_limit bigint, allowed_mime_types text[]
      );
      create table storage.objects (
        id uuid primary key default gen_random_uuid(),
        bucket_id text references storage.buckets(id), name text
      );
      create function storage.foldername(name text) returns text[]
      language sql immutable as $$
        select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1];
      $$;
      alter table storage.objects enable row level security;
      grant usage on schema auth, storage to anon, authenticated;
      grant select, insert, delete on storage.objects to authenticated;
    `);
    const migrations = path.join(__dirname, '../supabase/migrations');
    for (const file of fs.readdirSync(migrations).filter(f => f.endsWith('.sql')).sort()) {
      await db.exec(fs.readFileSync(path.join(migrations, file), 'utf8'));
      console.log(`Migration passed: ${file}`);
    }
    await db.exec(`
      insert into auth.users(id, email, email_confirmed_at) values
        ('${owner}', 'owner@example.test', now()),
        ('${reader}', 'reader@example.test', now()),
        ('${admin}', 'admin@example.test', now());
      insert into auth.identities values ('${admin}', 'google');
      insert into private.youwell_admins(email) values ('admin@example.test');
      insert into storage.buckets(id, name, public) values ('other', 'other', false);
      insert into storage.objects(bucket_id, name) values
        ('community', '${owner}/approved.png'),
        ('community', '${owner}/pending.png'),
        ('community', '${owner}/orphan.png'),
        ('other', '${owner}/secret.png');
      insert into public.youwell_posts(id, author, alias, body, status, image_path) values
        ('${approved}', '${owner}', 'owner', 'Approved photo', 'approved', '${owner}/approved.png'),
        ('${pending}', '${owner}', 'owner', 'Pending photo', 'pending', '${owner}/pending.png');
    `);
    async function asUser(id, aal, callback, role = 'authenticated') {
      await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id]);
      await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify({ sub: id, aal })]);
      await db.exec(`set role ${role}`);
      try { return await callback(); }
      finally { await db.exec('reset role'); }
    }
    const photos = async () => (await db.query('select name from storage.objects order by name')).rows.map(r => r.name);
    const denied = action => assert.rejects(action, error => error.code === '42501');

    await asUser(owner, 'aal1', async () => {
      assert.deepEqual(await photos(), [
        `${owner}/approved.png`, `${owner}/orphan.png`, `${owner}/pending.png`,
      ]);
      await denied(() => db.query('select * from public.youwell_posts'));
    });
    await asUser(reader, 'aal1', async () => {
      assert.deepEqual(await photos(), [`${owner}/approved.png`]);
      await denied(() => db.query('select * from public.youwell_posts'));
      await denied(() => db.query('select public.youwell_admin_progress_overview()'));
    });
    await asUser(admin, 'aal1', async () => {
      assert.deepEqual(await photos(), [`${owner}/approved.png`]);
      await denied(() => db.query('select public.youwell_admin_progress_overview()'));
    });
    await asUser(admin, 'aal2', async () => {
      assert.equal((await photos()).length, 3);
      await db.query('select public.set_youwell_participant_code($1, $2)', [owner, 'P1']);
      await assert.rejects(
        () => db.query('select public.set_youwell_participant_code($1, $2)', [reader, 'P1']),
        error => error.code === '23505',
      );
    });
    await asUser('', 'aal1', async () => {
      await denied(() => db.query('select public.youwell_community_photo_readable($1)', [`${owner}/approved.png`]));
    }, 'anon');
    console.log('Photo access passed: owner, reader, MFA admin, anonymous, private tables and other buckets.');

    const payload = {
      schemaVersion: 1, version: 3,
      profile: { alias: 'owner', path: 'wellness', started: '2026-10-16', companionName: 'Welli' },
      days: {}, capacity: {}, mobileRewards: {}, achievements: {},
      openedDays: [], activityDays: [], workoutSessions: [], mealCheckIns: [], habitDelays: [], habitSwaps: [],
    };
    await asUser(owner, 'aal1', async () => {
      assert.equal((await db.query('select public.save_youwell_progress($1, 0) as result', [payload])).rows[0].result.saved, true);
      payload.profile.alias = 'renamed';
      assert.equal((await db.query('select public.save_youwell_progress($1, 1) as result', [payload])).rows[0].result.saved, true);
      // Fields added on 23 Oct (sleep quests, Meal Snap verification) pass.
      const newer = {
        ...payload,
        days: { '2026-10-23': { quests: [{ id: 'q1', ladder: 'Energy', activityKind: 'sleep', bedBefore: 390, wakeBefore: 450, status: 'committed' }] } },
        mealCheckIns: [{ id: 'm1', day: '2026-10-23', time: '2026-10-23T08:00:00', checkId: 'c1', verification: 'pending', photoCaptured: true }],
      };
      assert.equal((await db.query('select public.save_youwell_progress($1, 2) as result', [newer])).rows[0].result.saved, true);
      payload.days = newer.days;
      payload.mealCheckIns = newer.mealCheckIns;
      await assert.rejects(
        () => db.query('select public.react_youwell_post($1, $2)', [approved, '👏']),
        error => error.code === 'P0002',
      );
    });
    assert.deepEqual((await db.query('select distinct alias from public.youwell_posts')).rows, [{ alias: 'renamed' }]);
    await asUser(admin, 'aal2', async () => {
      const rows = (await db.query('select public.youwell_admin_progress_overview() as result')).rows[0].result;
      assert.equal(rows.length, 1);
      assert.equal(rows[0].code, 'P1');
      assert.equal(rows[0].alias, 'renamed');
    });
    await asUser(reader, 'aal1', async () => {
      await assert.rejects(() => db.query('select public.delete_youwell_post($1)', [pending]), error => error.code === 'P0002');
    });
    await asUser(owner, 'aal1', async () => {
      assert.equal((await db.query('select public.delete_youwell_post($1) as photo', [pending])).rows[0].photo, `${owner}/pending.png`);
    });
    console.log('Account operations passed: sync names, alias propagation, participant codes, self-reaction denial and author-only deletion.');

    // Phase 7: only an MFA admin deletes someone else's published post.
    await asUser(reader, 'aal1', async () => {
      await denied(() => db.query('select public.admin_delete_youwell_post($1)', [approved]));
    });
    await asUser(admin, 'aal1', async () => {
      await denied(() => db.query('select public.admin_delete_youwell_post($1)', [approved]));
    });
    await asUser(admin, 'aal2', async () => {
      const queue = (await db.query('select public.youwell_moderation_queue() as q')).rows[0].q;
      assert.deepEqual(queue.published.map(p => p.id), [approved]);
      assert.equal((await db.query('select public.admin_delete_youwell_post($1) as photo', [approved])).rows[0].photo, `${owner}/approved.png`);
      await assert.rejects(() => db.query('select public.admin_delete_youwell_post($1)', [approved]), error => error.code === 'P0002');
      assert.deepEqual((await db.query('select public.youwell_moderation_queue() as q')).rows[0].q.published, []);
    });
    console.log('Admin deletion passed: reader and admin without MFA denied, MFA admin deletes a published post.');

    // Phase 8: every published post is reachable by search and pages.
    await db.exec(`
      insert into public.youwell_posts(author, alias, body, status, created_at)
      select '${owner}', 'renamed', 'Jalan pagi ' || n, 'approved', now() - (n || ' minutes')::interval
      from generate_series(1, 5) n;
      insert into public.youwell_posts(author, alias, body, status)
      values ('${owner}', 'renamed', 'Masih menunggu', 'pending');
    `);
    await asUser(admin, 'aal1', async () => {
      await denied(() => db.query('select public.youwell_admin_published_posts()'));
    });
    await asUser(admin, 'aal2', async () => {
      const page = async (q, before, limit) =>
        (await db.query('select public.youwell_admin_published_posts($1, $2, $3) as r', [q, before, limit])).rows[0].r;
      const first = await page(null, null, 2);
      assert.deepEqual(first.map(p => p.body), ['Jalan pagi 1', 'Jalan pagi 2']);
      const next = await page(null, first[1].created_at, 2);
      assert.deepEqual(next.map(p => p.body), ['Jalan pagi 3', 'Jalan pagi 4']);
      assert.deepEqual((await page('pagi 5', null, 30)).map(p => p.body), ['Jalan pagi 5']);
      assert.equal((await page('menunggu', null, 30)).length, 0);
    });
    console.log('Published search passed: MFA only, newest first, cursor pages, text search, approved only.');

    // Phase 9: meal photos are sent by their owner and decided once by an MFA admin.
    const mealPath = `${owner}/11111111-2222-4333-8444-555555555555.png`;
    await db.exec(`insert into storage.objects(bucket_id, name) values ('meals', '${mealPath}');`);
    await asUser(reader, 'aal1', async () => {
      await assert.rejects(
        () => db.query('select public.submit_youwell_meal($1, $2)', ['m1', mealPath]),
        error => error.code === '22023',
      );
    });
    let mealId;
    await asUser(owner, 'aal1', async () => {
      mealId = (await db.query('select public.submit_youwell_meal($1, $2) as id', ['m1', mealPath])).rows[0].id;
      const mine = (await db.query('select public.youwell_my_meal_checks() as r')).rows[0].r;
      assert.deepEqual(mine.map(m => [m.client_id, m.status]), [['m1', 'pending']]);
      await denied(() => db.query('select public.youwell_meal_queue()'));
      await denied(() => db.query('select public.review_youwell_meal($1, true)', [mealId]));
      await denied(() => db.query('select * from public.youwell_meal_checks'));
    });
    await asUser(admin, 'aal1', async () => {
      await denied(() => db.query('select public.youwell_meal_queue()'));
    });
    await asUser(admin, 'aal2', async () => {
      const queue = (await db.query('select public.youwell_meal_queue() as q')).rows[0].q;
      assert.deepEqual(queue.map(q => q.alias), ['renamed']);
      assert.equal((await db.query('select public.review_youwell_meal($1, false) as p', [mealId])).rows[0].p, mealPath);
      await assert.rejects(() => db.query('select public.review_youwell_meal($1, true)', [mealId]), error => error.code === 'P0002');
      const recent = (await db.query('select public.youwell_meal_recent() as r')).rows[0].r;
      assert.deepEqual(recent.map(r => [r.status, r.reviewer]), [['rejected', 'admin']]);
    });
    await asUser(owner, 'aal1', async () => {
      const mine = (await db.query('select public.youwell_my_meal_checks() as r')).rows[0].r;
      assert.equal(mine[0].status, 'rejected');
      // A new photo for the same meal goes back to pending.
      const again = `${owner}/66666666-7777-4888-8999-000000000000.png`;
      await db.exec('reset role');
      await db.exec(`insert into storage.objects(bucket_id, name) values ('meals', '${again}');`);
      await db.exec('set role authenticated');
      await db.query('select public.submit_youwell_meal($1, $2)', ['m1', again]);
      const after = (await db.query('select public.youwell_my_meal_checks() as r')).rows[0].r;
      assert.equal(after[0].status, 'pending');
    });
    console.log('Meal verification passed: owner-only upload, MFA admin decision once, retake goes back to pending.');

    // Phase 10: daily usage totals, admin interventions and history restore.
    const revisionOf = async () =>
      (await db.query('select revision from public.youwell_progress where user_id = $1', [owner])).rows[0].revision;
    await asUser(owner, 'aal1', async () => {
      const current = Number((await db.query('select revision from public.youwell_progress where user_id = $1', [owner])).rows[0].revision);
      const withUsage = { ...payload, usageTotals: [{ day: '2026-10-23', type: 'rokok', total: 4, confirmed: true }] };
      assert.equal((await db.query('select public.save_youwell_progress($1, $2) as r', [withUsage, current])).rows[0].r.saved, true);
      for (const bad of [
        [{ day: '2026-10-23', type: 'cigarette', total: 4 }],
        [{ day: '2026-10-23', type: 'rokok', total: 900 }],
        [{ day: '2026-10-23', type: 'rokok', total: 4, time: '08:00' }],
      ]) {
        await assert.rejects(
          () => db.query('select public.save_youwell_progress($1, $2)', [{ ...payload, usageTotals: bad }, current + 1]),
          error => error.code === '22023',
        );
      }
      await denied(() => db.query('select public.admin_write_youwell_progress($1, 1, $2, $3, $4)', [owner, payload, 'Pemulihan data', []]));
      await denied(() => db.query('select * from public.youwell_admin_interventions'));
      await denied(() => db.query('select * from public.youwell_progress_history'));
    });
    await db.exec('reset role');
    const beforeAdmin = Number(await revisionOf());
    await asUser(admin, 'aal1', async () => {
      await denied(() => db.query('select public.youwell_admin_interventions()'));
    });
    await asUser(admin, 'aal2', async () => {
      const overview = (await db.query('select public.youwell_admin_progress_overview() as r')).rows[0].r;
      const mine = overview.find(row => row.account === owner);
      assert.equal(Number(mine.revision), beforeAdmin);
      const edited = { ...mine.payload, usageTotals: [{ day: '2026-10-23', type: 'rokok', total: 6, confirmed: true, source: 'admin' }] };
      await assert.rejects(
        () => db.query('select public.admin_write_youwell_progress($1, $2, $3, $4, $5)', [owner, beforeAdmin, edited, '', []]),
        error => error.code === '22023',
      );
      await assert.rejects(
        () => db.query('select public.admin_write_youwell_progress($1, $2, $3, $4, $5)',
          [owner, beforeAdmin, { ...edited, profile: { ...edited.profile, alias: 'other' } }, 'Pemulihan data', []]),
        error => error.code === '22023',
      );
      const stale = (await db.query('select public.admin_write_youwell_progress($1, $2, $3, $4, $5) as r',
        [owner, beforeAdmin - 1, edited, 'Pemulihan data', []])).rows[0].r;
      assert.equal(stale.saved, false);
      const saved = (await db.query('select public.admin_write_youwell_progress($1, $2, $3, $4, $5) as r',
        [owner, beforeAdmin, edited, 'Data hilang setelah install ulang', [{ kind: 'usage', day: '2026-10-23' }]])).rows[0].r;
      assert.equal(saved.saved, true);
      const log = (await db.query('select public.youwell_admin_interventions() as r')).rows[0].r;
      assert.deepEqual(log.map(i => [i.alias, i.reason]), [['renamed', 'Data hilang setelah install ulang']]);
      const history = (await db.query('select public.youwell_admin_progress_history($1) as r', [owner])).rows[0].r;
      assert.equal(Number(history[0].revision), beforeAdmin);
      const restored = (await db.query('select public.admin_restore_youwell_revision($1, $2, $3) as r',
        [owner, beforeAdmin, 'Kembali ke salinan sebelum edit'])).rows[0].r;
      assert.equal(restored.saved, true);
    });
    await db.exec('reset role');
    const back = (await db.query('select payload, revision from public.youwell_progress where user_id = $1', [owner])).rows[0];
    assert.equal(back.payload.usageTotals[0].total, 4);
    assert.equal(Number(back.revision), beforeAdmin + 2);
    console.log('Admin overview passed: usage totals validated, MFA-only edits with reason and audit, stale revision refused, history restore.');
  } finally { await db.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
