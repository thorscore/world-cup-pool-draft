create extension if not exists pgcrypto with schema extensions;

create table if not exists public.wc_pool_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  admin_token text not null,
  spectator_token text not null,
  state jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.wc_pool_players (
  pool_id uuid not null references public.wc_pool_rooms(id) on delete cascade,
  player_id text not null,
  name text not null,
  token text not null default encode(extensions.gen_random_bytes(16), 'hex'),
  primary key (pool_id, player_id),
  unique (pool_id, token)
);

alter table public.wc_pool_rooms enable row level security;
alter table public.wc_pool_players enable row level security;

create or replace function public.wc_pool_sync_players(p_pool_id uuid, p_state jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.wc_pool_players (pool_id, player_id, name)
  select p_pool_id, player_data->>'id', coalesce(player_data->>'name', 'Player')
  from jsonb_array_elements(coalesce(p_state->'players', '[]'::jsonb)) as player_data
  where player_data ? 'id'
  on conflict (pool_id, player_id) do update
    set name = excluded.name;

  delete from public.wc_pool_players existing
  where existing.pool_id = p_pool_id
    and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_state->'players', '[]'::jsonb)) as player_data
      where player_data->>'id' = existing.player_id
    );
end;
$$;

create or replace function public.wc_pool_payload(
  p_room public.wc_pool_rooms,
  p_role text,
  p_player_id text default null,
  p_player_name text default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'code', p_room.code,
    'role', p_role,
    'player_id', p_player_id,
    'player_name', p_player_name,
    'spectator_token', case when p_role = 'admin' then p_room.spectator_token else null end,
    'state', p_room.state,
    'updated_at', p_room.updated_at,
    'player_links', case
      when p_role = 'admin' then coalesce((
        select jsonb_agg(jsonb_build_object('id', player_id, 'name', name, 'token', token) order by name)
        from public.wc_pool_players
        where pool_id = p_room.id
      ), '[]'::jsonb)
      else '[]'::jsonb
    end
  );
$$;

create or replace function public.wc_pool_create_room(
  p_state jsonb,
  p_admin_token text,
  p_spectator_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  inserted_room public.wc_pool_rooms;
begin
  if p_admin_token is null or length(p_admin_token) < 16 then
    raise exception 'Admin token is missing.';
  end if;

  loop
    new_code := upper(substr(encode(extensions.gen_random_bytes(4), 'hex'), 1, 6));
    begin
      insert into public.wc_pool_rooms (code, admin_token, spectator_token, state)
      values (new_code, p_admin_token, p_spectator_token, p_state)
      returning * into inserted_room;
      exit;
    exception when unique_violation then
    end;
  end loop;

  perform public.wc_pool_sync_players(inserted_room.id, p_state);
  select * into inserted_room from public.wc_pool_rooms where id = inserted_room.id;
  return public.wc_pool_payload(inserted_room, 'admin');
end;
$$;

create or replace function public.wc_pool_get_room(p_code text, p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  found_room public.wc_pool_rooms;
  found_player public.wc_pool_players;
begin
  select * into found_room
  from public.wc_pool_rooms
  where code = upper(p_code);

  if not found then
    raise exception 'Room not found.';
  end if;

  if p_token = found_room.admin_token then
    return public.wc_pool_payload(found_room, 'admin');
  end if;

  if p_token = found_room.spectator_token then
    return public.wc_pool_payload(found_room, 'spectator');
  end if;

  select * into found_player
  from public.wc_pool_players
  where pool_id = found_room.id and token = p_token;

  if not found then
    raise exception 'Access key is not valid for this room.';
  end if;

  return public.wc_pool_payload(found_room, 'player', found_player.player_id, found_player.name);
end;
$$;

create or replace function public.wc_pool_admin_save_state(p_code text, p_token text, p_state jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  found_room public.wc_pool_rooms;
begin
  select * into found_room
  from public.wc_pool_rooms
  where code = upper(p_code) and admin_token = p_token
  for update;

  if not found then
    raise exception 'Only the admin can update this room.';
  end if;

  update public.wc_pool_rooms
  set state = p_state, updated_at = now()
  where id = found_room.id
  returning * into found_room;

  perform public.wc_pool_sync_players(found_room.id, p_state);
  select * into found_room from public.wc_pool_rooms where id = found_room.id;
  return public.wc_pool_payload(found_room, 'admin');
end;
$$;

create or replace function public.wc_pool_player_make_pick(p_code text, p_token text, p_team text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  found_room public.wc_pool_rooms;
  found_player public.wc_pool_players;
  current_state jsonb;
  players jsonb;
  picks jsonb;
  teams jsonb;
  player_count int;
  pick_count int;
  round_index int;
  slot_index int;
  current_index int;
  current_player_id text;
  picked_group text;
  new_pick jsonb;
begin
  select * into found_room
  from public.wc_pool_rooms
  where code = upper(p_code)
  for update;

  if not found then
    raise exception 'Room not found.';
  end if;

  select * into found_player
  from public.wc_pool_players
  where pool_id = found_room.id and token = p_token;

  if not found then
    raise exception 'Only a player access key can make a player pick.';
  end if;

  current_state := found_room.state;
  if coalesce((current_state->>'draftStarted')::boolean, false) is not true then
    raise exception 'The draft has not started yet.';
  end if;

  players := coalesce(current_state->'players', '[]'::jsonb);
  picks := coalesce(current_state->'picks', '[]'::jsonb);
  teams := coalesce(current_state->'teams', '[]'::jsonb);
  player_count := jsonb_array_length(players);
  pick_count := jsonb_array_length(picks);

  if player_count < 2 or pick_count >= player_count * 4 then
    raise exception 'The draft is complete.';
  end if;

  round_index := floor(pick_count::numeric / player_count)::int;
  slot_index := pick_count % player_count;
  current_index := case when round_index % 2 = 0 then slot_index else player_count - 1 - slot_index end;
  current_player_id := players->current_index->>'id';

  if current_player_id is distinct from found_player.player_id then
    raise exception 'It is not your turn to pick.';
  end if;

  if exists (select 1 from jsonb_array_elements(picks) pick where pick->>'team' = p_team) then
    raise exception 'That team has already been drafted.';
  end if;

  select team->>'group' into picked_group
  from jsonb_array_elements(teams) team
  where team->>'name' = p_team
  limit 1;

  if picked_group is null then
    raise exception 'Team not found.';
  end if;

  new_pick := jsonb_build_object('playerId', found_player.player_id, 'team', p_team, 'group', picked_group);
  current_state := jsonb_set(current_state, '{picks}', picks || jsonb_build_array(new_pick), true);

  update public.wc_pool_rooms
  set state = current_state, updated_at = now()
  where id = found_room.id
  returning * into found_room;

  return public.wc_pool_payload(found_room, 'player', found_player.player_id, found_player.name);
end;
$$;

revoke all on public.wc_pool_rooms from anon, authenticated;
revoke all on public.wc_pool_players from anon, authenticated;

grant execute on function public.wc_pool_create_room(jsonb, text, text) to anon, authenticated;
grant execute on function public.wc_pool_get_room(text, text) to anon, authenticated;
grant execute on function public.wc_pool_admin_save_state(text, text, jsonb) to anon, authenticated;
grant execute on function public.wc_pool_player_make_pick(text, text, text) to anon, authenticated;
