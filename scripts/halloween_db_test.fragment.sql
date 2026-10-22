-- Diese Prüfungen laufen mit temporären Testdaten in derselben Transaktion.
savepoint halloween_pruefung;
do $$
declare cid uuid;sid uuid;tid uuid;tok text;ttok text;r jsonb;z jsonb;expected jsonb;taskrow bwr_private.tasks;n integer;i integer;request_id uuid;
begin
 if (select count(*) from bwr_private.tasks where app_id='halloween-waffelstand')<>72 then raise exception 'Erwartet: 72 Prüfgruppen';end if;
 if bwr_private.normalized('1.301,50 €','money')::numeric<>1301.50 then raise exception 'Deutsches Zahlenformat fehlerhaft';end if;
 if bwr_private.normalized('28','money')::numeric<>28 or bwr_private.normalized('28.00','money')::numeric<>28 then raise exception 'Zahlenvarianten fehlerhaft';end if;
 if bwr_private.normalized('0700 MA','account')<>'0700' then raise exception 'Kontenformat fehlerhaft';end if;
 if bwr_private.normalized('1.30.1,50','money') is not null then raise exception 'Ungültige Zahl akzeptiert';end if;
 insert into bwr_private.classes(label,class_name,grade,school_year) values('halloween-pruefung-'||gen_random_uuid(),'8x','8',2026) returning id into cid;
 sid:=bwr_private.add_account(cid,'halloween-student-'||cid,'a2b3');tid:=bwr_private.add_account(cid,'halloween-teacher-'||cid,'TemporarilyOnly98','teacher');
 insert into bwr_private.teacher_classes values(tid,cid);
 insert into bwr_private.class_apps values(cid,'halloween-waffelstand');insert into bwr_private.grants values(sid,'halloween-waffelstand',true);
 tok:=public.bwr_api('login',jsonb_build_object('login','halloween-student-'||cid,'password','A2B3'))->>'token';
 ttok:=public.bwr_api('login',jsonb_build_object('login','halloween-teacher-'||cid,'password','TemporarilyOnly98'))->>'token';
 if tok is null or ttok is null then raise exception 'Testanmeldung fehlgeschlagen';end if;
 r:=public.bwr_api('app.start',jsonb_build_object('app_id','halloween-waffelstand','request_id',gen_random_uuid()),tok);
 begin perform public.bwr_api('app.solution',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','request_id',gen_random_uuid()),tok);raise exception 'TEST: Lösung zu früh freigegeben';exception when raise_exception then if sqlerrm like 'TEST:%' then raise;end if;end;
 for i in 1..3 loop
  request_id:=gen_random_uuid();
  r:=public.bwr_api('app.check',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','answer',jsonb_build_object('amount','1'),'request_id',request_id),tok);
  z:=public.bwr_api('app.check',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','answer',jsonb_build_object('amount','1'),'request_id',request_id),tok);
  if z<>r then raise exception 'Doppelte Anfrage liefert abweichendes Ergebnis';end if;
  if (r#>>'{progress,run_errors,1.1.betrag}')::integer<>i then raise exception 'Fehlversuch doppelt oder falsch gezählt';end if;
  if i<3 then
   begin perform public.bwr_api('app.solution',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','request_id',gen_random_uuid()),tok);raise exception 'TEST: Lösung vor drei Fehlern verfügbar';exception when raise_exception then if sqlerrm like 'TEST:%' then raise;end if;end;
  end if;
 end loop;
 r:=public.bwr_api('app.solution',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','request_id',gen_random_uuid()),tok);
 r:=public.bwr_api('app.solution',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','request_id',gen_random_uuid()),tok);
 if r#>>'{progress,solutions,1.1.betrag}'<>'1' then raise exception 'Lösungshilfe wird mehrfach pro Durchlauf gezählt';end if;
 if coalesce((r#>>'{progress,solved,1.1.betrag}')::boolean,false) then raise exception 'Lösungsanzeige löst Aufgabe automatisch';end if;
 begin perform public.bwr_api('app.check',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','answer','{}'::jsonb,'request_id',gen_random_uuid()),tok);raise exception 'TEST: Leere Eingabe als Versuch akzeptiert';exception when raise_exception then if sqlerrm like 'TEST:%' then raise;end if;end;
 for taskrow in select * from bwr_private.tasks where app_id='halloween-waffelstand' order by id loop
  expected:=taskrow.expected::jsonb;
  r:=public.bwr_api('app.check',jsonb_build_object('app_id','halloween-waffelstand','task_id',taskrow.id,'answer',expected,'request_id',gen_random_uuid()),tok);
  if not (r->>'correct')::boolean then raise exception 'Musterlösung nicht erkannt: %',taskrow.id;end if;
 end loop;
 if r#>>'{progress,completed_runs}'<>'1' then raise exception 'Vollständiger Durchlauf nicht erkannt';end if;
 r:=public.bwr_api('app.repeat',jsonb_build_object('app_id','halloween-waffelstand','request_id',gen_random_uuid()),tok);
 if r#>>'{progress,errors,1.1.betrag}'<>'3' then raise exception 'Gesamtfehler bei Wiederholung gelöscht';end if;
 if r#>'{progress,run_errors}'<>'{}'::jsonb then raise exception 'Fehler des Durchlaufs nicht zurückgesetzt';end if;
 begin perform public.bwr_api('app.solution',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','request_id',gen_random_uuid()),tok);raise exception 'TEST: Lösung bleibt bei Wiederholung freigeschaltet';exception when raise_exception then if sqlerrm like 'TEST:%' then raise;end if;end;
 r:=public.bwr_api('app.check',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag','answer',jsonb_build_object('amount','28')),ttok);
 r:=public.bwr_api('app.solution',jsonb_build_object('app_id','halloween-waffelstand','task_id','1.1.betrag'),ttok);
 if exists(select 1 from bwr_private.progress where account_id=tid) then raise exception 'Lehrertest speichert Statistik';end if;
 raise notice 'Halloween-Prüfungen bestanden; Testdaten werden verworfen.';
end $$;
rollback to savepoint halloween_pruefung;
