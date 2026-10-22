"""Fachlich geprüfte Aufgabenspezifikation; erzeugt SQL und öffentliche Metadaten."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
APP='halloween-waffelstand'
ACCOUNTS=[('6000','AWR','Aufwendungen für Rohstoffe'),('6020','AWH','Aufwendungen für Hilfsstoffe'),('5000','UEFE','Umsatzerlöse für eigene Erzeugnisse'),('8020','GUV','Gewinn- und Verlustkonto'),('2880','KA','Kasse'),('0700','MA','Maschinen und Anlagen'),('3000','EK','Eigenkapital'),('8010','SBK','Schlussbilanzkonto')]
TASKS=[]
def field(key,label,kind='money',options=None):
 d={'key':key,'label':label,'type':kind}
 if options:d['options']=options
 return d
def add(id,label,section,fields,expected,info,tips,explanation,account=None,kind=None):
 d=dict(id=id,label=label,section=section,fields=fields,info=info,tips=tips,explanation=explanation,expected=expected)
 if account:d['account']=account
 if kind:d['kind']=kind
 TASKS.append(d)
def euro(n):return f'{n:,.2f}'.replace(',','X').replace('.',',').replace('X','.')+' €'
def money_task(id,label,expected,info,tips,explanation):add(id,label,'Geschaeftsfaelle',[field('amount','Gesamtbetrag in €')],{'amount':euro(expected)},info,tips,explanation)
ALL_INFO='Alle Zahlungen erfolgen bar. Vorsteuer und Umsatzsteuer werden nicht berücksichtigt.'
money_task('1.1.betrag','1.1 Vier Waffeleisen – Betrag',28,'Ihr kauft vier Waffeleisen für je 7,00 €. '+ALL_INFO,['Multipliziere die Anzahl der Waffeleisen mit dem Einzelpreis.','Es sind vier gleiche Geräte: Anzahl × 7,00 €.'],'4 × 7,00 € = 28,00 €. Die vier Waffeleisen kosten zusammen 28,00 €.')
money_task('1.2.betrag','1.2 Grundzutaten – Betrag',180,'Für 35 Waffeln kosten die Grundzutaten zusammen 18,00 €. Benötigt werden 350 Waffeln. '+ALL_INFO,['Berechne zuerst, wie oft 35 Waffeln in 350 Waffeln enthalten sind.','Teile 350 durch 35. Multipliziere diesen Faktor anschließend mit 18,00 €.'],'350 : 35 = 10; 10 × 18,00 € = 180,00 €. Es wird die zehnfache Grundmenge benötigt.')
ingredients=[('puder','Puderzucker',100,1),('nutella','Nutella',100,4),('kakao','Kakao',75,3),('himbeer','Himbeermarmelade',75,4),('orange','Orangenmarmelade',75,4)]
fields=[];expected={}
for key,name,qty,price in ingredients:
 fields += [field(key+'_packs',name+' – Packungen','integer'),field(key+'_cost',name+' – Kosten in €')]
 expected[key+'_packs']=str(qty//25);expected[key+'_cost']=euro(qty//25*price)
fields += [field('total','Gesamtbetrag Sonderzutaten in €')];expected['total']=euro(53)
add('1.3.betrag','1.3 Sonderzutaten – Zwischenergebnisse und Gesamtbetrag','Geschaeftsfaelle',fields,expected,'100 Geister-Waffeln mit Puderzucker; 100 Spinnennetz-Waffeln mit Nutella; 75 Totenkopf-Waffeln mit Kakao UND Himbeermarmelade; 75 Kürbis-Waffeln mit Orangenmarmelade. Jede Packung reicht für 25 Waffeln. Packungspreise: Puderzucker 1,00 €, Nutella 4,00 €, Kakao 3,00 €, Himbeermarmelade 4,00 €, Orangenmarmelade 4,00 €.',['Berechne die benötigten Packungen für jede Zutat getrennt. Achte auf die zwei Zutaten der Totenkopf-Waffel.','Waffelanzahl : 25 ergibt die Packungsanzahl. Multipliziere diese mit dem Packungspreis und addiere alle fünf Kostenbeträge.'],'Puderzucker: 100 : 25 × 1,00 € = 4,00 €; Nutella: 100 : 25 × 4,00 € = 16,00 €; Kakao: 75 : 25 × 3,00 € = 9,00 €; Himbeermarmelade: 75 : 25 × 4,00 € = 12,00 €; Orangenmarmelade: 75 : 25 × 4,00 € = 12,00 €. Gesamt: 4,00 € + 16,00 € + 9,00 € + 12,00 € + 12,00 € = 53,00 €.')
sales=[('geist','Geister-Waffeln',100,2),('spinne','Spinnennetz-Waffeln',100,2.5),('kopf','Totenkopf-Waffeln',75,3),('kuerbis','Kürbis-Waffeln',75,2.5)]
add('1.4.betrag','1.4 Verkauf – Zwischenergebnisse und Gesamtbetrag','Geschaeftsfaelle',[field(k,n+' – Erlöse in €') for k,n,_,_ in sales]+[field('total','Gesamterlös in €')],{**{k:euro(q*p) for k,_,q,p in sales},'total':euro(862.5)},'Verkauft werden 100 Geister-Waffeln zu je 2,00 €, 100 Spinnennetz-Waffeln zu je 2,50 €, 75 Totenkopf-Waffeln zu je 3,00 € und 75 Kürbis-Waffeln zu je 2,50 €. '+ALL_INFO,['Ermittle zuerst den Erlös jeder Waffelsorte einzeln.','Multipliziere je Sorte die verkaufte Anzahl mit dem Verkaufspreis. Addiere anschließend die vier Erlöse.'],'100 × 2,00 € = 200,00 €; 100 × 2,50 € = 250,00 €; 75 × 3,00 € = 225,00 €; 75 × 2,50 € = 187,50 €. Gesamt: 862,50 €.')
for idx,debit,credit,amount,why in [(1,'0700','2880',28,'Maschinen und Anlagen nehmen im Soll zu; die Kasse nimmt im Haben ab.'),(2,'6000','2880',180,'Rohstoffaufwand steht im Soll; die Barauszahlung vermindert die Kasse im Haben.'),(3,'6020','2880',53,'Die Sonderzutaten werden hier als Hilfsstoffaufwand im Soll erfasst. Die Kasse nimmt im Haben ab.'),(4,'2880','5000',862.5,'Die Bareinnahme erhöht die Kasse im Soll. Umsatzerlöse werden im Haben gebucht.')]:
 info=next(t['info'] for t in TASKS if t['id']==f'1.{idx}.betrag')
 add(f'1.{idx}.buchung',f'1.{idx} Buchungssatz','Geschaeftsfaelle',[field('debit','Sollkonto','account'),field('credit','Habenkonto','account'),field('amount','Buchungsbetrag in €')],{'debit':debit,'credit':credit,'amount':euro(amount)},info,['Welche zwei Konten ändern sich? Alle Zahlungen sind bar.','Prüfe, auf welcher Seite der Zugang bzw. Abgang des Bestandskontos oder der Aufwand bzw. Ertrag gebucht wird.'],f'{debit} an {credit} {euro(amount)}. {why}')
LEDGERS={
'6000': [('Geschäftsfall 2','Soll','2880',180)],
'6020': [('Geschäftsfall 3','Soll','2880',53)],
'5000': [('Geschäftsfall 4','Haben','2880',862.5)],
'8020': [('Abschluss AWR','Soll','6000',180),('Abschluss AWH','Soll','6020',53),('Abschluss UEFE','Haben','5000',862.5)],
'2880': [('Anfangsbestand','Soll','AB',700),('Geschäftsfall 1','Haben','0700',28),('Geschäftsfall 2','Haben','6000',180),('Geschäftsfall 3','Haben','6020',53),('Geschäftsfall 4','Soll','5000',862.5)],
'0700': [('Geschäftsfall 1','Soll','2880',28)],
'3000': [('Anfangsbestand','Haben','AB',700),('Übernahme des Gewinns','Haben','8020',629.5)],
'8010': [('Abschluss Kasse','Soll','2880',1301.5),('Abschluss MA','Soll','0700',28),('Abschluss EK','Haben','3000',1329.5)]}
KINDS={'6000':'Aufwandskonto','6020':'Aufwandskonto','5000':'Ertragskonto','8020':'Konto für die Ergebnisrechnung','2880':'aktives Bestandskonto','0700':'aktives Bestandskonto','3000':'passives Bestandskonto','8010':'Schlussbilanzkonto'}
for code,short,name in ACCOUNTS:
 prefix='2.'+code;section=code+' '+short;rows=LEDGERS[code]
 info='Relevante Geschäftsfälle: vier Waffeleisen für je 7,00 €; Grundzutaten für 350 Waffeln (18,00 € je 35 Waffeln); Sonderzutaten und Verkäufe wie in Aufgabe 1. Anfangsbestand der Klassenkasse: 700,00 €. Dieser Betrag wird auch als Anfangsbestand des Eigenkapitals erfasst. Alle Zahlungen bar; keine Umsatzsteuer und keine Abschreibung. Bei GUV und EK sind die vorhergehenden Abschlussbuchungen zu berücksichtigen.'
 fields=[];expected={}
 for i,(label,side,contra,amount) in enumerate(rows):
  fields += [field(f'r{i}_side',label+' – Seite','select',['Soll','Haben']),field(f'r{i}_contra',label+' – Gegenkonto / AB','account'),field(f'r{i}_amount',label+' – Betrag in €')]
  expected.update({f'r{i}_side':side,f'r{i}_contra':contra,f'r{i}_amount':euro(amount)})
 add(prefix+'.eintraege',section+' – Buchungen im T-Konto',section,fields,expected,info,['Ordne jedem genannten Vorgang die Kontoseite und das Gegenkonto zu. Den Anfangsbestand kennzeichnest du mit AB.','Aktive Bestandskonten: Anfangsbestand und Zugänge im Soll. Passive Bestandskonten: Anfangsbestand und Zugänge im Haben. Aufwendungen stehen im Soll, Erträge im Haben.'], '; '.join(f'{label}: {side}, {contra}, {euro(amount)}' for label,side,contra,amount in rows),code,'entries')
 soll=sum(v for _,side,_,v in rows if side=='Soll');haben=sum(v for _,side,_,v in rows if side=='Haben');high=max(soll,haben);low=min(soll,haben);saldo=high-low
 add(prefix+'.a',section+' · a) Summen ermitteln',section,[field('soll','Summe Soll vor Abschluss in €'),field('haben','Summe Haben vor Abschluss in €')],{'soll':euro(soll),'haben':euro(haben)},info,['Addiere die Einträge auf jeder Kontoseite getrennt.','Die Abschlussbuchung dieses Kontos gehört noch nicht in diese Summen. Berücksichtige aber die Abschlüsse, die bereits auf dieses Konto übertragen wurden.'],f'Vor dem Abschluss: Soll {euro(soll)}, Haben {euro(haben)}.',code)
 comparison='Soll > Haben' if soll>haben else 'Haben > Soll' if haben>soll else 'Soll = Haben'
 add(prefix+'.b',section+' · b) Summen vergleichen',section,[field('comparison','Vergleich','select',['Soll > Haben','Haben > Soll','Soll = Haben'])],{'comparison':comparison},info,['Vergleiche die beiden Summen aus a).','Prüfe auch, ob die Summen gleich groß sind. Beim SBK ist das entscheidend.'],f'{euro(soll)} im Soll und {euro(haben)} im Haben: {comparison}.',code)
 add(prefix+'.c',section+' · c) Saldo berechnen',section,[field('high','Größere Summe in €'),field('low','Kleinere Summe in €'),field('saldo','Saldo in €')],{'high':euro(high),'low':euro(low),'saldo':euro(saldo)},info,['Der Saldo ist die Differenz zwischen den beiden Kontensummen.','Größere Summe minus kleinere Summe. Sind beide Summen gleich, beträgt die Differenz 0,00 €.'],f'{euro(high)} − {euro(low)} = {euro(saldo)}.'+(' Der Gewinn beträgt 629,50 €.' if code=='8020' else ''),code)
 add(prefix+'.d',section+' · d) Kontoart angeben',section,[field('kind','Kontoart','select',list(dict.fromkeys(KINDS.values())))],{'kind':KINDS[code]},info,['Zeigt das Konto Vermögen, Kapital, Aufwand, Ertrag oder eine Zusammenfassung zum Abschluss?','Die Kontenklasse hilft: 0 und 2 Vermögen, 3 Kapital, 5 Erträge, 6 Aufwendungen. GUV ermittelt den Erfolg; SBK stellt die Schlussbestände gegenüber.'],f'{section} ist ein {KINDS[code]}.',code)
 close='8020' if code in ['6000','6020','5000'] else '3000' if code=='8020' else '8010' if code!='8010' else 'entfällt'
 add(prefix+'.e',section+' · e) Abschlusskonto angeben',section,[field('account','Abschlusskonto','account')],{'account':close},info,['Erfolgskonten werden über GUV, Bestandskonten über SBK abgeschlossen.','Die GUV wird auf Eigenkapital abgeschlossen. Für das SBK gibt es keinen weiteren Abschluss auf ein anderes Konto.'],f'Abschlusskonto: {close}.'+(' Das SBK ist die Schlussbilanz in Kontenform.' if code=='8010' else ''),code)
 if code=='8010':
  ff=[field('closing','Abschlussbuchung','select',['Buchungssatz erforderlich','entfällt'])];ee={'closing':'entfällt'};ex='Entfällt: Das ausgeglichene SBK wird nicht über ein weiteres Konto abgeschlossen.'
 else:
  debit,credit=(close,code) if soll>haben else (code,close)
  ff=[field('debit','Sollkonto','account'),field('credit','Habenkonto','account'),field('amount','Saldobetrag in €')];ee={'debit':debit,'credit':credit,'amount':euro(saldo)};ex=f'{debit} an {credit} {euro(saldo)}. Der Saldo wird im abzuschließenden Konto auf der kleineren Seite eingetragen.'
 add(prefix+'.f',section+' · f) Abschlussbuchungssatz bilden',section,ff,ee,info,['Der Saldo steht im abzuschließenden Konto auf der kleineren Seite.','Bestimme zuerst die Seite im bisherigen Konto. Die Gegenbuchung erfolgt im Abschlusskonto auf der anderen Seite. Beim SBK entfällt die Buchung.'],ex,code)
 gg=[];ge={}
 if code!='8010':
  gg=[field('side','Abschluss auf der Seite','select',['Soll','Haben']),field('contra','Gegenkonto','account'),field('amount','Abschlussbetrag in €')];ge={'side':'Haben' if soll>haben else 'Soll','contra':close,'amount':euro(saldo)}
 gg += [field('soll','Endsumme Soll in €'),field('haben','Endsumme Haben in €')];ge.update(soll=euro(high),haben=euro(high))
 add(prefix+'.g',section+' · g) Abschluss buchen und Summen ergänzen',section,gg,ge,info,['Ergänze den Saldo auf der kleineren Seite. Danach müssen beide Seiten gleich groß sein.','Die Endsumme entspricht auf beiden Seiten der vorher größeren Summe. Beim ausgeglichenen SBK ist keine zusätzliche Saldobuchung nötig.'],('Keine zusätzliche Buchung im SBK. ' if code=='8010' else f'Abschluss: {ge["side"]}, Gegenkonto {close}, {euro(saldo)}. ')+f'Beide Endsummen betragen {euro(high)}.',code,'closing')

def quote(value):return "'"+value.replace("'","''")+"'"
def generate():
 tasks=sorted(TASKS,key=lambda t:(0 if t['section']=='Geschaeftsfaelle' else 1,t['id']))
 public=[{k:v for k,v in t.items() if k not in ['expected','explanation','tips']} for t in tasks]
 (ROOT/'applications'/APP/'tasks.json').write_text(json.dumps(public,ensure_ascii=False,indent=2)+'\n')
 sql=["-- Aufgaben ergänzen; keine Accounts oder Lernstände werden gelöscht.",f"insert into bwr_private.apps(id,title,description,grade) values('{APP}','Halloween-Waffelstand','Berechnungen, Buchungssätze und T-Konten – passend zum Arbeitsblatt.','8') on conflict(id) do update set title=excluded.title,description=excluded.description;",'delete from bwr_private.tasks where app_id='+quote(APP)+' and id not in ('+','.join(quote(t['id']) for t in tasks)+');']
 for t in tasks:
  vals=[APP,t['id'],t['label'],json.dumps(t['expected'],ensure_ascii=False),t['explanation'],json.dumps(t['fields'],ensure_ascii=False),t['tips'][0],t['tips'][1]]
  sql.append('insert into bwr_private.tasks(app_id,id,label,expected,explanation,fields,hint1,hint2) values('+','.join(quote(v) for v in vals)+"::text) on conflict(app_id,id) do update set label=excluded.label,expected=excluded.expected,explanation=excluded.explanation,fields=excluded.fields,hint1=excluded.hint1,hint2=excluded.hint2;")
 # fields column is jsonb and PostgreSQL accepts unknown string literals in INSERT.
 return '\n'.join(sql)+'\n'
if __name__=='__main__':
 (ROOT/'database'/'halloween_tasks.fragment.sql').write_text(generate())
 print(f'{len(TASKS)} Prüfgruppen erstellt.')
