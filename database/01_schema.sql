-- Einmal im Supabase SQL Editor ausführen. Enthält keine Zugangsdaten.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists bwr_private;
revoke all on schema bwr_private from public, anon, authenticated;
create table bwr_private.settings (id boolean primary key default true check(id), encryption_key text not null);
insert into bwr_private.settings values(true,encode(extensions.gen_random_bytes(32),'hex'));
create table bwr_private.classes(id uuid primary key default gen_random_uuid(), label text unique not null, class_name text not null, grade text not null, school_year integer not null, next_suffix integer not null default 0);
create table bwr_private.accounts(id uuid primary key default gen_random_uuid(), class_id uuid not null references bwr_private.classes on delete cascade, login text unique not null, role text not null check(role in ('student','teacher')), password_hash text not null, password_cipher bytea not null, created_at timestamptz not null default now());
create unique index one_teacher_per_class on bwr_private.accounts(class_id) where role='teacher';
create table bwr_private.teacher_classes(account_id uuid not null references bwr_private.accounts on delete cascade,class_id uuid not null references bwr_private.classes on delete cascade,primary key(account_id,class_id));
create table bwr_private.sessions(token_hash text primary key, account_id uuid not null references bwr_private.accounts on delete cascade, expires_at timestamptz not null);
create table bwr_private.login_limits(login text primary key, attempts integer not null default 0, window_start timestamptz not null default now());
create table bwr_private.apps(id text primary key check(id ~ '^[a-z0-9][a-z0-9-]{0,59}$'),title text not null, description text not null default '', grade text not null, active boolean not null default true);
create table bwr_private.class_apps(class_id uuid not null references bwr_private.classes on delete cascade, app_id text not null references bwr_private.apps on delete cascade, primary key(class_id,app_id));
create table bwr_private.grants(account_id uuid not null references bwr_private.accounts on delete cascade,app_id text not null references bwr_private.apps on delete cascade,enabled boolean not null default false,primary key(account_id,app_id));
create table bwr_private.tasks(app_id text not null references bwr_private.apps on delete cascade,id text not null,label text not null,expected text not null,explanation text not null,primary key(app_id,id));
create table bwr_private.progress(account_id uuid not null references bwr_private.accounts on delete cascade,app_id text not null references bwr_private.apps on delete cascade,started_at timestamptz,updated_at timestamptz,completed_runs integer not null default 0,run_complete boolean not null default false,answers jsonb not null default '{}',solved jsonb not null default '{}',errors jsonb not null default '{}',primary key(account_id,app_id));
create table bwr_private.requests(account_id uuid not null references bwr_private.accounts on delete cascade,request_id uuid not null,response jsonb not null,primary key(account_id,request_id));
-- Tabellen zusätzlich mit RLS absichern. Zugriff nur über die unten definierten Funktionen.
do $$ declare t record; begin for t in select tablename from pg_tables where schemaname='bwr_private' loop execute format('alter table bwr_private.%I enable row level security',t.tablename); end loop; end $$;
revoke all on all tables in schema bwr_private from public,anon,authenticated;
create function bwr_private.suffix(i integer) returns text language plpgsql immutable set search_path='' as $$declare n integer:=i+1; r text:='';begin while n>0 loop r:=chr(65+(n-1)%26)||r;n:=(n-1)/26;end loop;return r;end$$;
create function bwr_private.add_account(cid uuid,username text,pw text,kind text default 'student') returns uuid language plpgsql set search_path='' as $$declare aid uuid; k text;begin
 select encryption_key into k from bwr_private.settings where id;
 insert into bwr_private.accounts(class_id,login,role,password_hash,password_cipher) values(cid,username,kind,extensions.crypt(case when kind='student' then lower(pw) else pw end,extensions.gen_salt('bf',10)),extensions.pgp_sym_encrypt(pw,k)) returning id into aid;return aid;
end$$;
create function bwr_private.class_data(cid uuid) returns jsonb language sql set search_path='' as $$
 select jsonb_build_object('class',to_jsonb(c),'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'login',a.login) order by a.created_at,a.login) from bwr_private.accounts a where a.class_id=c.id and a.role='student'),'[]'::jsonb),'apps',coalesce((select jsonb_agg(to_jsonb(ap) order by ap.title) from bwr_private.apps ap join bwr_private.class_apps ca on ca.app_id=ap.id where ca.class_id=c.id),'[]'::jsonb),'grants',coalesce((select jsonb_agg(to_jsonb(g)) from bwr_private.grants g join bwr_private.accounts a on a.id=g.account_id where a.class_id=c.id),'[]'::jsonb),'tasks',coalesce((select jsonb_agg(jsonb_build_object('app_id',t.app_id,'id',t.id,'label',t.label)) from bwr_private.tasks t join bwr_private.class_apps ca on ca.app_id=t.app_id where ca.class_id=c.id),'[]'::jsonb),'progress',coalesce((select jsonb_agg(to_jsonb(p)) from bwr_private.progress p join bwr_private.accounts a on a.id=p.account_id where a.class_id=c.id),'[]'::jsonb)) from bwr_private.classes c where c.id=cid;
$$;
create function public.bwr_api(action text,payload jsonb default '{}',session_token text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare u bwr_private.accounts; target bwr_private.accounts; c bwr_private.classes; ap bwr_private.apps; task bwr_private.tasks; p bwr_private.progress; lim bwr_private.login_limits; r jsonb; items jsonb; tok text; pw text; username text; aid uuid; cid uuid; appkey text; i integer; n integer; v integer; alphabet text:='abcdefghjkmnpqrstuvwxyz23456789'; correct boolean; all_done boolean; rid uuid; k text;
begin
 if pg_column_size(payload)>100000 then raise exception 'Anfrage zu groß';end if;
 if action='login' then
  username:=lower(trim(payload->>'login'));pw:=payload->>'password';
  if username is null or length(username)>80 or pw is null or length(pw)>200 then return jsonb_build_object('error','Anmeldung fehlgeschlagen.');end if;
  insert into bwr_private.login_limits(login) values(username) on conflict do nothing;
  select * into lim from bwr_private.login_limits where login=username for update;
  if lim.window_start<now()-interval '15 minutes' then update bwr_private.login_limits set attempts=0,window_start=now() where login=username;lim.attempts:=0;end if;
  if lim.attempts>=5 then return jsonb_build_object('error','Zu viele Anmeldeversuche. Bitte nach 15 Minuten erneut versuchen.');end if;
  update bwr_private.login_limits set attempts=attempts+1 where login=username;
  select * into u from bwr_private.accounts where lower(login)=username;
  if u.id is null then perform extensions.crypt(pw,extensions.gen_salt('bf',10));return jsonb_build_object('error','Account oder Passwort ist falsch.');end if;
  if u.password_hash<>extensions.crypt(case when u.role='student' then lower(pw) else pw end,u.password_hash) then return jsonb_build_object('error','Account oder Passwort ist falsch.');end if;
  update bwr_private.login_limits set attempts=0 where login=username;
  delete from bwr_private.sessions where expires_at<now();
  tok:=encode(extensions.gen_random_bytes(32),'hex');
  insert into bwr_private.sessions values(encode(extensions.digest(tok,'sha256'),'hex'),u.id,now()+interval '8 hours');
  return jsonb_build_object('token',tok);
 end if;
 select a.* into u from bwr_private.accounts a join bwr_private.sessions s on s.account_id=a.id where s.token_hash=encode(extensions.digest(session_token,'sha256'),'hex') and s.expires_at>now();
 if u.id is null then return jsonb_build_object('error','Bitte melde dich erneut an.','expired',true);end if;
 select * into c from bwr_private.classes where id=u.class_id;
 if u.role='teacher' and payload ? 'class_id' then
  select cl.* into c from bwr_private.classes cl join bwr_private.teacher_classes tc on tc.class_id=cl.id where tc.account_id=u.id and cl.id=(payload->>'class_id')::uuid;
  if c.id is null then raise exception 'Kein Zugriff auf diese Klasse';end if;
 end if;
 if action='logout' then delete from bwr_private.sessions where token_hash=encode(extensions.digest(session_token,'sha256'),'hex');return '{}'::jsonb;end if;
 if action='me' then
  select coalesce(jsonb_agg(to_jsonb(a) order by a.title),'[]'::jsonb) into items from bwr_private.apps a join bwr_private.class_apps ca on ca.app_id=a.id where ca.class_id=c.id and a.active and (u.role='teacher' or exists(select 1 from bwr_private.grants g where g.app_id=a.id and g.account_id=u.id and g.enabled));
  return jsonb_build_object('account',jsonb_build_object('id',u.id,'login',u.login,'role',u.role),'class',to_jsonb(c),'apps',items,'tasks',coalesce((select jsonb_agg(jsonb_build_object('app_id',t.app_id,'id',t.id,'label',t.label)) from bwr_private.tasks t where t.app_id in(select el->>'id' from jsonb_array_elements(items) el)),'[]'::jsonb),'progress',coalesce((select jsonb_agg(to_jsonb(x)) from bwr_private.progress x where x.account_id=u.id),'[]'::jsonb));
 end if;
 if action='password' then
  aid:=coalesce((payload->>'account_id')::uuid,u.id);
  select * into target from bwr_private.accounts where id=aid;
  if target.id is null or not(target.id=u.id or (u.role='teacher' and exists(select 1 from bwr_private.teacher_classes tc where tc.account_id=u.id and tc.class_id=target.class_id) and target.role='student')) then raise exception 'Kein Zugriff';end if;
  select encryption_key into k from bwr_private.settings where id;
  return jsonb_build_object('password',extensions.pgp_sym_decrypt(target.password_cipher,k));
 end if;
 if action like 'teacher.%' then
  if u.role<>'teacher' then raise exception 'Kein Zugriff';end if;
  if action='teacher.classes' then return jsonb_build_object('classes',coalesce((select jsonb_agg(to_jsonb(cl) order by cl.label) from bwr_private.classes cl join bwr_private.teacher_classes tc on tc.class_id=cl.id where tc.account_id=u.id),'[]'::jsonb));end if;
  if action='teacher.create_class' then
   username:=trim(payload->>'class_name');n:=(payload->>'year')::integer;
   if username is null or n is null or username !~ '^([5-9]|10)[a-z]$' or n<2020 or n>2100 then raise exception 'Bitte Klasse wie 8b und ein gültiges Jahr eingeben';end if;
   insert into bwr_private.classes(label,class_name,grade,school_year) values(username||n,username,regexp_replace(username,'[a-z]','','g'),n) returning id into cid;
   insert into bwr_private.teacher_classes values(u.id,cid);return jsonb_build_object('id',cid);
  end if;
  if action='teacher.class' then return bwr_private.class_data(c.id);end if;
  if action='teacher.add' then
   n:=(payload->>'count')::integer;if n<1 or n>100 then raise exception 'Bitte 1 bis 100 Accounts wählen';end if;
   select * into c from bwr_private.classes where id=c.id for update;
   for i in 1..n loop
    username:=c.label||bwr_private.suffix(c.next_suffix);c.next_suffix:=c.next_suffix+1;
    loop
     pw:='';for j in 1..4 loop
      loop v:=get_byte(extensions.gen_random_bytes(1),0);exit when v<256-(256%length(alphabet));end loop;
      pw:=pw||substr(alphabet,1+v%length(alphabet),1);
     end loop;
     exit when pw ~ '[a-z]' and pw ~ '[0-9]';
    end loop;
    aid:=bwr_private.add_account(c.id,username,pw);
    insert into bwr_private.grants(account_id,app_id,enabled)
    select aid,ca.app_id,(select count(*) from bwr_private.grants g join bwr_private.accounts a on a.id=g.account_id where a.class_id=c.id and a.role='student' and a.id<>aid and g.app_id=ca.app_id and g.enabled) > (select count(*) from bwr_private.accounts a where a.class_id=c.id and a.role='student' and a.id<>aid)/2.0 from bwr_private.class_apps ca where ca.class_id=c.id;
   end loop;
   update bwr_private.classes set next_suffix=c.next_suffix where id=c.id;return bwr_private.class_data(c.id);
  end if;
  if action='teacher.assign' then
   appkey:=payload->>'app_id';select * into ap from bwr_private.apps where id=appkey and grade=c.grade and active;
   if ap.id is null then raise exception 'Anwendung passt nicht zur Jahrgangsstufe';end if;
   insert into bwr_private.class_apps values(c.id,appkey) on conflict do nothing;
   insert into bwr_private.grants select id,appkey,false from bwr_private.accounts where class_id=c.id and role='student' on conflict do nothing;return bwr_private.class_data(c.id);
  end if;
  if action='teacher.catalog' then return jsonb_build_object('apps',coalesce((select jsonb_agg(to_jsonb(a) order by title) from bwr_private.apps a where grade=c.grade and active),'[]'::jsonb));end if;
  if action='teacher.detach' then
   appkey:=payload->>'app_id';delete from bwr_private.class_apps where class_id=c.id and app_id=appkey;
   delete from bwr_private.grants where app_id=appkey and account_id in(select id from bwr_private.accounts where class_id=c.id);return bwr_private.class_data(c.id);
  end if;
  aid:=(payload->>'account_id')::uuid;appkey:=payload->>'app_id';
  if aid is not null then select * into target from bwr_private.accounts where id=aid and class_id=c.id and role='student';if target.id is null then raise exception 'Kein Zugriff';end if;end if;
  if action='teacher.delete' then
   if aid is null then raise exception 'Account fehlt';end if;
   delete from bwr_private.accounts where id=aid;return bwr_private.class_data(c.id);
  end if;
  if action='teacher.grant' then
   if not exists(select 1 from bwr_private.class_apps where class_id=c.id and app_id=appkey) then raise exception 'Anwendung nicht zugeordnet';end if;
   insert into bwr_private.grants select id,appkey,(payload->>'enabled')::boolean from bwr_private.accounts where class_id=c.id and role='student' and (aid is null or id=aid) on conflict(account_id,app_id) do update set enabled=excluded.enabled;return bwr_private.class_data(c.id);
  end if;
  if action='teacher.reset' then
   if aid is null and appkey is null then raise exception 'Bitte einen Account oder eine Anwendung wählen';end if;
   delete from bwr_private.progress where account_id in(select id from bwr_private.accounts where class_id=c.id and role='student') and (aid is null or account_id=aid) and (appkey is null or app_id=appkey);
   delete from bwr_private.requests where account_id in(select id from bwr_private.accounts where class_id=c.id and role='student') and (aid is null or account_id=aid);return bwr_private.class_data(c.id);
  end if;
  raise exception 'Unbekannte Lehreraktion';
 end if;
 appkey:=payload->>'app_id';
 if not exists(select 1 from bwr_private.apps a join bwr_private.class_apps ca on ca.app_id=a.id where a.id=appkey and a.active and ca.class_id=c.id and (u.role='teacher' or exists(select 1 from bwr_private.grants g where g.app_id=a.id and g.account_id=u.id and g.enabled))) then raise exception 'Anwendung nicht freigeschaltet';end if;
 if action='app.tasks' then return jsonb_build_object('tasks',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',label) order by id) from bwr_private.tasks where app_id=appkey),'[]'::jsonb));end if;
 if action in ('app.start','app.check','app.repeat','app.solution') then
  if u.role='teacher' then
   if action='app.check' or action='app.solution' then
    select * into task from bwr_private.tasks where app_id=appkey and id=payload->>'task_id';
    if task.id is null then raise exception 'Aufgabe nicht gefunden';end if;
    return jsonb_build_object('correct',lower(trim(payload->>'answer'))=lower(trim(task.expected)),'explanation',task.explanation,'expected',task.expected,'test',true);
   end if;return jsonb_build_object('test',true);
  end if;
  rid:=(payload->>'request_id')::uuid;if rid is null then raise exception 'Anfragekennung fehlt';end if;
  -- Ein Account wird gesperrt, damit gleichzeitige Prüfanfragen keine Zähler überschreiben.
  perform 1 from bwr_private.accounts where id=u.id for update;
  select response into r from bwr_private.requests where account_id=u.id and request_id=rid;if found then return r;end if;
  insert into bwr_private.progress(account_id,app_id,started_at,updated_at) values(u.id,appkey,now(),now()) on conflict do nothing;
  select * into p from bwr_private.progress where account_id=u.id and app_id=appkey for update;
  r:='{}'::jsonb;
  if action='app.repeat' then
   if not p.run_complete then raise exception 'Der aktuelle Durchlauf ist noch nicht abgeschlossen';end if;
   p.answers:='{}';p.solved:='{}';p.run_complete:=false;
  elsif action in ('app.check','app.solution') then
   select * into task from bwr_private.tasks where app_id=appkey and id=payload->>'task_id';if task.id is null then raise exception 'Aufgabe nicht gefunden';end if;
   if action='app.solution' then r:=jsonb_build_object('expected',task.expected,'explanation',task.explanation);
   else
    if p.run_complete then raise exception 'Bitte zuerst einen neuen Durchlauf starten';end if;
    if length(trim(coalesce(payload->>'answer','')))=0 then raise exception 'Bitte eine Antwort eingeben';end if;
    correct:=lower(trim(payload->>'answer'))=lower(trim(task.expected));
    p.answers:=p.answers||jsonb_build_object(task.id,payload->>'answer');
    if correct then p.solved:=p.solved||jsonb_build_object(task.id,true);
    else p.solved:=p.solved-task.id;p.errors:=p.errors||jsonb_build_object(task.id,coalesce((p.errors->>task.id)::integer,0)+1);end if;
    select count(*)>0 and bool_and(coalesce((p.solved->>t.id)::boolean,false)) into all_done from bwr_private.tasks t where t.app_id=appkey;
    if all_done then p.completed_runs:=p.completed_runs+1;p.run_complete:=true;end if;
    r:=jsonb_build_object('correct',correct,'explanation',case when correct then task.explanation else 'Prüfe deinen Ansatz und versuche es erneut.' end);
   end if;
  end if;
  update bwr_private.progress set answers=p.answers,solved=p.solved,errors=p.errors,completed_runs=p.completed_runs,run_complete=p.run_complete,updated_at=now() where account_id=u.id and app_id=appkey returning * into p;
  r:=r||jsonb_build_object('progress',to_jsonb(p));insert into bwr_private.requests values(u.id,rid,r);return r;
 end if;
 raise exception 'Unbekannte Aktion';
end$$;
revoke all on all functions in schema bwr_private from public,anon,authenticated;
revoke all on function public.bwr_api(text,jsonb,text) from public;
grant execute on function public.bwr_api(text,jsonb,text) to anon,authenticated;
commit;
