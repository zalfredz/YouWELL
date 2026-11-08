-- Read-only. Export the single JSON value to a LOCAL ignored file:
-- .tools/reduction-import/overview.json
-- No email, credentials or Google identity is returned.
-- Run in your own project's SQL Editor, or with an authorized SQL connection.
select coalesce(jsonb_agg(jsonb_build_object(
  'account', p.user_id,
  'code', c.code,
  'revision', p.revision,
  'study_path', s.study_path,
  'study_started', s.study_started,
  'payload', p.payload
) order by c.code), '[]'::jsonb) as overview
from public.youwell_progress p
join public.youwell_participant_codes c on c.user_id = p.user_id
left join public.youwell_study_cohorts s on s.user_id = p.user_id
where c.code in ('P5', 'P6', 'P7', 'P8', 'P9', 'P10');
