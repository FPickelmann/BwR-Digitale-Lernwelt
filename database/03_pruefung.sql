-- Nach 01_schema.sql und der privaten 02_accounts.sql ausführen.
-- Führt Tests mit kurzlebigen Testdaten aus. ROLLBACK entfernt alle Teständerungen.
begin;
do $$
declare cid uuid; student uuid; teacher uuid; other_id uuid; r jsonb; tok text; teacher_tok text; p jsonb; i integer;
begin
 if has_schema_privilege('anon','bwr_private','USAGE') then raise exception 'Privates Schema ist erreichbar';end if;
 if (select count(*) from bwr_private.accounts a join bwr_private.classes c on c.id=a.class_id where c.label='8b2026' and a.role='student')<>30 then raise exception 'Erwartet: 30 Schüleraccounts';end if;
 insert into bwr_private.classes(label,class_name,grade,school_year) values('test-rollback','8x','8',2026) returning id into cid;
 student:=bwr_private.add_account(cid,'test-student','a2b3');
 other_id:=bwr_private.add_account(cid,'test-other','x9y8');
 teacher:=bwr_private.add_account(cid,'test-teacher','LongTestPassword98','teacher');
 insert into bwr_private.teacher_classes values(teacher,cid);
 insert into bwr_private.apps values('test-rollback','Test','Test','8',true);
 insert into bwr_private.class_apps values(cid,'test-rollback');
 insert into bwr_private.grants values(student,'test-rollback',true),(other_id,'test-rollback',false);
 insert into bwr_private.tasks values('test-rollback','1a','Testaufgabe','42','Testbegründung');
 r:=public.bwr_api('login',jsonb_build_object('login','test-student','password','A2B3'));tok:=r->>'token';
 if tok is null then raise exception 'Schüleranmeldung fehlgeschlagen';end if;
 r:=public.bwr_api('me','{}',tok);if r#>>'{account,id}'<>student::text then raise exception 'Falscher Account';end if;
 begin perform public.bwr_api('password',jsonb_build_object('account_id',other_id),tok);raise exception 'Fremdes Passwort erreichbar';exception when raise_exception then if sqlerrm='Fremdes Passwort erreichbar' then raise;end if;end;
 begin perform public.bwr_api('teacher.class','{}',tok);raise exception 'Schüler hat Lehrerzugriff';exception when raise_exception then if sqlerrm='Schüler hat Lehrerzugriff' then raise;end if;end;
 r:=public.bwr_api('app.check',jsonb_build_object('app_id','test-rollback','task_id','1a','answer','41','request_id',gen_random_uuid()),tok);
 if r#>>'{progress,errors,1a}'<>'1' then raise exception 'Fehler wird nicht gezählt';end if;
 r:=public.bwr_api('app.check',jsonb_build_object('app_id','test-rollback','task_id','1a','answer','42','request_id',gen_random_uuid()),tok);
 if r#>>'{progress,completed_runs}'<>'1' then raise exception 'Abschluss wird nicht gezählt';end if;
 r:=public.bwr_api('app.repeat',jsonb_build_object('app_id','test-rollback','request_id',gen_random_uuid()),tok);
 r:=public.bwr_api('app.check',jsonb_build_object('app_id','test-rollback','task_id','1a','answer','42','request_id',gen_random_uuid()),tok);
 if r#>>'{progress,completed_runs}'<>'2' then raise exception 'Wiederholung wird nicht gezählt';end if;
 teacher_tok:=public.bwr_api('login',jsonb_build_object('login','test-teacher','password','LongTestPassword98'))->>'token';
 r:=public.bwr_api('app.check',jsonb_build_object('app_id','test-rollback','task_id','1a','answer','42'),teacher_tok);
 if exists(select 1 from bwr_private.progress where account_id=teacher) then raise exception 'Lehrertest speichert Fortschritt';end if;
 r:=public.bwr_api('teacher.reset',jsonb_build_object('app_id','test-rollback'),teacher_tok);
 if exists(select 1 from bwr_private.progress where account_id=student) then raise exception 'Zurücksetzen unvollständig';end if;
 if not exists(select 1 from bwr_private.grants where account_id=student and enabled) then raise exception 'Zurücksetzen verändert Freigaben';end if;
 for i in 1..5 loop r:=public.bwr_api('login',jsonb_build_object('login','test-other','password','wrong'));end loop;
 r:=public.bwr_api('login',jsonb_build_object('login','test-other','password','x9y8'));
 if r->>'token' is not null then raise exception 'Anmeldebegrenzung fehlt';end if;
 raise notice 'Alle Datenbankprüfungen bestanden. Testdaten werden verworfen.';
end $$;
rollback;
