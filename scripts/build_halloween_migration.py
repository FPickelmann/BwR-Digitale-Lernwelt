from pathlib import Path
from halloween_data import ROOT,generate

head=r"""-- Halloween-Erweiterung für die bestehende BwR Digitale Lernwelt.
-- Einmal vollständig im Supabase SQL Editor ausführen. Wiederholbar, keine Löschung von Accounts.
begin;
alter table bwr_private.tasks add column if not exists fields jsonb;
alter table bwr_private.tasks add column if not exists hint1 text not null default 'Prüfe deinen Ansatz.';
alter table bwr_private.tasks add column if not exists hint2 text not null default 'Überprüfe den nächsten Rechenschritt.';
alter table bwr_private.progress add column if not exists run_errors jsonb not null default '{}';
alter table bwr_private.progress add column if not exists solutions jsonb not null default '{}';
alter table bwr_private.progress add column if not exists run_solutions jsonb not null default '{}';
create or replace function bwr_private.normalized(v text,kind text) returns text language plpgsql immutable set search_path='' as $$
declare x text;
begin
 x:=lower(trim(coalesce(v,'')));
 if kind in ('money','integer') then
  x:=regexp_replace(x,'[€\s]','','g');
  -- Deutsche Tausenderpunkte sind nur in Dreiergruppen erlaubt.
  if x ~ '^[0-9]{1,3}(\.[0-9]{3})+(,[0-9]{1,2})?$' then x:=replace(x,'.','');
  elsif x !~ '^[0-9]+([,.][0-9]{1,2})?$' then return null;end if;
  x:=replace(x,',','.');
  if length(x)>20 then return null;end if;
  if kind='integer' and x::numeric<>trunc(x::numeric) then return null;end if;
  return (x::numeric)::text;
 elsif kind='account' then
  if x in ('ab','anfangsbestand') then return 'AB';end if;
  if x in ('entfällt','entfaellt','kein abschlusskonto','kein weiteres abschlusskonto') then return 'entfällt';end if;
  if x ~ '^[0-9]{3,4}([[:space:]].*)?$' then return lpad(substring(x from '^[0-9]{3,4}'),4,'0');end if;
  return case x when 'awr' then '6000' when 'aufwendungen für rohstoffe' then '6000' when 'awh' then '6020' when 'aufwendungen für hilfsstoffe' then '6020' when 'uefe' then '5000' when 'umsatzerlöse für eigene erzeugnisse' then '5000' when 'guv' then '8020' when 'gewinn- und verlustkonto' then '8020' when 'ka' then '2880' when 'kasse' then '2880' when 'ma' then '0700' when 'maschinen und anlagen' then '0700' when 'ek' then '3000' when 'eigenkapital' then '3000' when 'sbk' then '8010' when 'schlussbilanzkonto' then '8010' else x end;
 end if;
 return regexp_replace(x,'\s+',' ','g');
end $$;
create or replace function bwr_private.grade_fields(spec jsonb,expected jsonb,given jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare f jsonb; checks jsonb:='{}';a text;b text;kind text;ok boolean;
begin
 if jsonb_typeof(given)<>'object' then raise exception 'Bitte alle Eingabefelder ausfüllen';end if;
 for f in select value from jsonb_array_elements(spec) loop
  if trim(coalesce(given->>(f->>'key'),''))='' then raise exception 'Bitte alle Eingabefelder ausfüllen. Leere Eingaben zählen nicht als Fehlversuch.';end if;
  kind:=f->>'type';a:=bwr_private.normalized(given->>(f->>'key'),kind);b:=bwr_private.normalized(expected->>(f->>'key'),kind);
  if kind in ('money','integer') then ok:=a is not null and b is not null and a::numeric=b::numeric;
  else ok:=a is not null and a=b;end if;
  checks:=checks||jsonb_build_object(f->>'key',coalesce(ok,false));
 end loop;
 return checks;
end $$;
"""
source=(ROOT/'database/01_schema.sql').read_text()
api=source[source.index('create function public.bwr_api'):source.index('revoke all on all functions')]
api=api.replace('create function public.bwr_api','create or replace function public.bwr_api',1)
api=api.replace('correct boolean; all_done boolean;',"checks jsonb; given jsonb; correct boolean; all_done boolean; mistakes integer;")
old="if not exists(select 1 from bwr_private.apps a join bwr_private.class_apps ca on ca.app_id=a.id where a.id=appkey and a.active and ca.class_id=c.id and (u.role='teacher' or exists(select 1 from bwr_private.grants g where g.app_id=a.id and g.account_id=u.id and g.enabled))) then raise exception 'Anwendung nicht freigeschaltet';end if;"
new="if not exists(select 1 from bwr_private.apps a where a.id=appkey and a.active and ((u.role='teacher' and a.grade=c.grade) or (exists(select 1 from bwr_private.class_apps ca where ca.app_id=a.id and ca.class_id=c.id) and exists(select 1 from bwr_private.grants g where g.app_id=a.id and g.account_id=u.id and g.enabled)))) then raise exception 'Anwendung nicht freigeschaltet';end if;"
assert old in api;api=api.replace(old,new)
api=api.replace("'label',label) order by id)","'label',label,'fields',fields) order by id)")
old="return jsonb_build_object('correct',lower(trim(payload->>'answer'))=lower(trim(task.expected)),'explanation',task.explanation,'expected',task.expected,'test',true);"
new="""if action='app.solution' then return jsonb_build_object('expected',case when task.fields is null then to_jsonb(task.expected) else task.expected::jsonb end,'explanation',task.explanation,'test',true);end if;
    if task.fields is null then correct:=lower(trim(payload->>'answer'))=lower(trim(task.expected));checks:='{}';
    else checks:=bwr_private.grade_fields(task.fields,task.expected::jsonb,payload->'answer');select bool_and(value::boolean) into correct from jsonb_each_text(checks);end if;
    return jsonb_build_object('correct',correct,'fields',checks,'explanation',case when correct then task.explanation else task.hint1 end,'hint2',task.hint2,'test',true);"""
assert old in api;api=api.replace(old,new)
api=api.replace("p.answers:='{}';p.solved:='{}';p.run_complete:=false;","p.answers:='{}';p.solved:='{}';p.run_errors:='{}';p.run_solutions:='{}';p.run_complete:=false;")
old="if action='app.solution' then r:=jsonb_build_object('expected',task.expected,'explanation',task.explanation);"
new="""if action='app.solution' then
    if coalesce((p.run_errors->>task.id)::integer,0)<3 then raise exception 'Die Musterlösung ist erst nach drei Fehlversuchen in diesem Durchlauf verfügbar.';end if;
    if not coalesce((p.run_solutions->>task.id)::boolean,false) then p.solutions:=p.solutions||jsonb_build_object(task.id,coalesce((p.solutions->>task.id)::integer,0)+1);end if;
    p.run_solutions:=p.run_solutions||jsonb_build_object(task.id,true);
    r:=jsonb_build_object('expected',case when task.fields is null then to_jsonb(task.expected) else task.expected::jsonb end,'explanation',task.explanation);"""
assert old in api;api=api.replace(old,new)
old="correct:=lower(trim(payload->>'answer'))=lower(trim(task.expected));\n    p.answers:=p.answers||jsonb_build_object(task.id,payload->>'answer');"
new="""if task.fields is null then correct:=lower(trim(payload->>'answer'))=lower(trim(task.expected));checks:='{}';given:=to_jsonb(payload->>'answer');
    else given:=payload->'answer';checks:=bwr_private.grade_fields(task.fields,task.expected::jsonb,given);select bool_and(value::boolean) into correct from jsonb_each_text(checks);end if;
    p.answers:=p.answers||jsonb_build_object(task.id,given);"""
assert old in api;api=api.replace(old,new)
api=api.replace("else p.solved:=p.solved-task.id;p.errors:=p.errors||jsonb_build_object(task.id,coalesce((p.errors->>task.id)::integer,0)+1);end if;", "else p.solved:=p.solved-task.id;p.errors:=p.errors||jsonb_build_object(task.id,coalesce((p.errors->>task.id)::integer,0)+1);p.run_errors:=p.run_errors||jsonb_build_object(task.id,coalesce((p.run_errors->>task.id)::integer,0)+1);end if;")
api=api.replace("r:=jsonb_build_object('correct',correct,'explanation',case when correct then task.explanation else 'Prüfe deinen Ansatz und versuche es erneut.' end);", "mistakes:=coalesce((p.run_errors->>task.id)::integer,0);r:=jsonb_build_object('correct',correct,'fields',checks,'solution_available',mistakes>=3,'explanation',case when correct then task.explanation when mistakes=1 then task.hint1 else task.hint2 end);")
api=api.replace('set answers=p.answers,solved=p.solved,errors=p.errors,completed_runs', 'set answers=p.answers,solved=p.solved,errors=p.errors,run_errors=p.run_errors,solutions=p.solutions,run_solutions=p.run_solutions,completed_runs')
tail="""
revoke all on all functions in schema bwr_private from public,anon,authenticated;
revoke all on function public.bwr_api(text,jsonb,text) from public;
grant execute on function public.bwr_api(text,jsonb,text) to anon,authenticated;
commit;
-- Erfolgsanzeige:
select count(*) as pruefgruppen from bwr_private.tasks where app_id='halloween-waffelstand';
"""
target=ROOT/'database/04_halloween_update.sql'
target.write_text(head+generate()+api+(ROOT/'scripts/halloween_db_test.fragment.sql').read_text()+tail)
print(target)
