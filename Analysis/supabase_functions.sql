-- #############################################################################
-- DATABASE FUNCTIONS – Supabase (PostgreSQL)
-- #############################################################################
-- This file contains the two server-side SQL functions used in the experiment.
-- They handle participant creation with adaptive condition
-- assignment, and automatic product category assignment based on Task 1
-- ratings via a database trigger.
-- #############################################################################


--------------------------------------------------------------------------------
-- 1. PARTICIPANT CREATION + CONDITION ASSIGNMENT
--------------------------------------------------------------------------------
-- Called via supabase.rpc('create_participant', { p_participant_id: ... })
-- when a new participant starts the experiment.
--
-- Uses adaptive randomization: the condition with the fewest participants so
-- far is selected (ties broken randomly). 
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_participant(p_participant_id uuid)
 RETURNS TABLE(participant_id uuid, condition text, interest text, load text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_exists    boolean;
  v_condition text;
  v_interest  text;
  v_load      text;
begin
  -- Check whether a record for this participant already exists
  select exists(
    select 1 from public.participants p
    where p.participant_id = p_participant_id
  ) into v_exists;

  -- If yes, return the existing record immediately
  if v_exists then
    return query
      select p.participant_id, p."condition", p."interest", p."load"
      from public.participants p
      where p.participant_id = p_participant_id;
    return;
  end if;

  -- Acquire advisory lock to prevent race conditions
  perform pg_advisory_lock(987654321);

  -- Adaptive randomization: count participants per condition,
  -- pick the least-filled condition (ties broken randomly)
  with counts as (
    select 'HILL' as cond, coalesce(count(*) filter (where p."condition"='HILL'),0) as cnt
    from public.participants p
    union all
    select 'HIHL', coalesce(count(*) filter (where p."condition"='HIHL'),0)
    from public.participants p
    union all
    select 'LILL', coalesce(count(*) filter (where p."condition"='LILL'),0)
    from public.participants p
    union all
    select 'LIHL', coalesce(count(*) filter (where p."condition"='LIHL'),0)
    from public.participants p
  ),
  ranked as (
    select cond, cnt, rank() over (order by cnt asc) as rnk
    from counts
  )
  select cond into v_condition
  from ranked
  where rnk = 1
  order by random()
  limit 1;

  -- Derive factor levels from the condition code
  v_interest := case when v_condition in ('HILL','HIHL') then 'High' else 'Low' end;
  v_load     := case when v_condition in ('HIHL','LIHL') then 'High' else 'Low' end;

  -- Insert the new participant
  insert into public.participants (participant_id, "condition", "interest", "load")
  values (p_participant_id, v_condition, v_interest, v_load)
  on conflict on constraint participants_pkey do nothing; -- prevents duplicates

  -- Release advisory lock
  perform pg_advisory_unlock(987654321);

  -- Return the newly created record
  return query
    select p.participant_id, p."condition", p."interest", p."load"
    from public.participants p
    where p.participant_id = p_participant_id;

exception
  when others then
    perform pg_advisory_unlock(987654321);
    raise;
end;
$function$;


--------------------------------------------------------------------------------
-- 2. PRODUCT CATEGORY ASSIGNMENT (Trigger: participants_set_assigned_category)
--------------------------------------------------------------------------------
-- Registered as a BEFORE INSERT OR UPDATE trigger on the participants table.
-- Automatically fires whenever Task 1 ratings are saved.
--
-- Logic:
--   - High Interest condition -> selects the category with the HIGHEST rating
--   - Low Interest condition  -> selects the category with the LOWEST rating
--   - Skips recalculation if the relevant columns did not change (on UPDATE)
--   - Skips assignment if no ratings are set yet
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_set_assigned_category()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_best     text;
  v_interest text := lower(coalesce(NEW.interest, 'high'));
begin
  -- 1) On UPDATE: only recalculate if Task 1 ratings or interest changed
  if TG_OP = 'UPDATE' then
    if NEW.t1_detergent   is not distinct from OLD.t1_detergent
       and NEW.t1_smartwatch  is not distinct from OLD.t1_smartwatch
       and NEW.t1_speaker     is not distinct from OLD.t1_speaker
       and NEW.t1_bottle      is not distinct from OLD.t1_bottle
       and NEW.t1_toothbrush  is not distinct from OLD.t1_toothbrush
       and NEW.t1_backpack    is not distinct from OLD.t1_backpack
       and NEW.interest       is not distinct from OLD.interest
    then
      return NEW;
    end if;
  end if;

  -- 2) If no ratings are set yet, skip assignment
  if NEW.t1_detergent    is null
     and NEW.t1_smartwatch  is null
     and NEW.t1_speaker     is null
     and NEW.t1_bottle      is null
     and NEW.t1_toothbrush  is null
     and NEW.t1_backpack    is null
  then
    return NEW;
  end if;

  -- 3) Build candidate list and select the best category
  with pairs as (
    select *
    from (
      values
        ('Detergent',           NEW.t1_detergent),
        ('Smartwatch',          NEW.t1_smartwatch),
        ('Speaker',             NEW.t1_speaker),
        ('Water Bottle',        NEW.t1_bottle),
        ('Electric Toothbrush', NEW.t1_toothbrush),
        ('Backpack',            NEW.t1_backpack)
    ) as t(key, rating)
    where rating is not null
  ),
  target as (
    select case
             when v_interest = 'low'
               then min(rating)
             else max(rating)
           end as target_rating
    from pairs
  ),
  candidates as (
    select p.key
    from pairs p
    cross join target t
    where p.rating = t.target_rating
    order by random()
  )
  select key into v_best
  from candidates
  limit 1;

  if v_best is not null then
    NEW.assigned_category := v_best;
  end if;

  return NEW;
end;
$function$;

