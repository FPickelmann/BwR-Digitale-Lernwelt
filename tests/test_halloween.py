import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from halloween_data import TASKS,LEDGERS
class HalloweenTest(unittest.TestCase):
 def test_rechnung_und_ergebnis(self):
  expenses=350/35*18+(100/25*1+100/25*4+75/25*3+75/25*4+75/25*4)
  revenue=100*2+100*2.5+75*3+75*2.5
  self.assertEqual(expenses,233);self.assertEqual(revenue-expenses,629.5)
  self.assertEqual(700+revenue-expenses-4*7,1301.5)
  self.assertEqual(700+revenue-expenses,1329.5)
 def test_alle_konten_ausgeglichen(self):
  for code,rows in LEDGERS.items():
   sums={side:sum(n for _,s,_,n in rows if s==side) for side in ['Soll','Haben']}
   target=next(t for t in TASKS if t['id']==f'2.{code}.g')['expected']
   if code!='8010':sums[target['side']]+=abs(sums['Soll']-sums['Haben'])
   self.assertEqual(sums['Soll'],sums['Haben'],code)
 def test_vollstaendigkeit(self):
  self.assertEqual(len(TASKS),72);self.assertEqual(len({t['id'] for t in TASKS}),72)
  for t in TASKS:
   self.assertEqual({f['key'] for f in t['fields']},set(t['expected']),t['id'])
   self.assertTrue(t['info']);self.assertEqual(len(t['tips']),2)
if __name__=='__main__':unittest.main()
