"""Regenerate small, explicitly approximate teaching fixtures."""
import json
from pathlib import Path

def q(id,prompt,kind,coords,explanation,tolerance=30):
    geometry_type={'point':'Point','polyline':'LineString','multiPoint':'MultiPoint'}.get(kind,'Polygon')
    if geometry_type=='Polygon': coords=[coords+[coords[0]]]
    return dict(id=id,prompt=prompt,answerType=kind,geometry=dict(type=geometry_type,coordinates=coords),explanation=explanation,scoring=dict(toleranceKm=tolerance),hints=[],tags=[])
def level(id,title,questions,center=[15.5,49.8],span=9,unverified=False):
    value=dict(schemaVersion=1,id=id,title=title,description='Offline výuková sada / Offline teaching pack',language='cs',difficulty='beginner',tags=[],unverified=unverified,map=dict(center=center,longitudeSpan=span,showCountryBorders=True),questions=questions)
    Path(f'assets/levels/{id}.json').write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
level('czech-cities','Česká města',[
 q('praha','Kde leží Praha?','point',[14.4378,50.0755],'Praha leží na Vltavě ve středních Čechách. / Prague lies on the Vltava in central Bohemia.'),
 q('brno','Kde leží Brno?','point',[16.6068,49.1951],'Brno je největší město Moravy. / Brno is the largest city in Moravia.'),
 q('ostrava','Kde leží Ostrava?','point',[18.2625,49.8209],'Ostrava leží na severovýchodě Česka u hranic s Polskem. / Ostrava is in northeastern Czechia near Poland.'),
 q('three','Označ Prahu, Brno a Ostravu.','multiPoint',[[14.4378,50.0755],[16.6068,49.1951],[18.2625,49.8209]],'Pořadí bodů nerozhoduje. / Point order does not matter.')])
level('czech-rivers','České řeky',[
 q('vltava','Vyznač přibližný tok Vltavy.','polyline',[[13.56,48.98],[14.05,48.74],[14.32,48.81],[14.47,48.97],[14.36,49.24],[14.18,49.51],[14.42,49.85],[14.42,50.08],[14.48,50.35]],'Vltava teče přes Prahu a ústí do Labe u Mělníka. Výuková linie je zjednodušená. / The Vltava joins the Elbe at Mělník; this teaching line is approximate.',18),
 q('elbe','Vyznač českou část Labe.','polyline',[[15.54,50.77],[15.61,50.62],[15.81,50.43],[15.83,50.21],[15.77,50.04],[15.2,50.02],[14.88,50.19],[14.48,50.35],[14.14,50.53],[14.04,50.66],[14.24,50.85]],'Labe pramení v Krkonoších a pokračuje do Německa. Linie je zjednodušená. / The Elbe rises in the Krkonoše and flows into Germany.',18)],unverified=True)
level('czech-mountains','Česká pohoří',[
 q('krkonose','Obkresli oblast Krkonoš.','freehandArea',[[15.36,50.73],[15.53,50.83],[15.85,50.75],[15.9,50.61],[15.65,50.56],[15.39,50.62]],'Krkonoše leží podél česko-polské hranice. Obrys je orientační. / Krkonoše straddle the Czech–Polish border; this outline is approximate.'),
 q('sumava','Zakroužkuj přibližnou oblast Šumavy.','circle',[[13.1,49.22],[13.35,49.3],[14.15,48.72],[14.03,48.55],[13.55,48.82]],'Šumava leží na jihozápadě Čech. / Šumava lies in southwestern Bohemia.')],unverified=True)
level('europe','Evropa',[
 q('paris','Kde leží Paříž?','point',[2.3522,48.8566],'Paříž leží na Seině. / Paris lies on the Seine.',100),
 q('rome','Kde leží Řím?','point',[12.4964,41.9028],'Řím leží na Tibeře. / Rome lies on the Tiber.',100),
 q('czechia','Vyznač Česko.','polygon',[[12.09,50.25],[12.55,49.54],[13.84,48.77],[14.7,48.58],[16.95,48.62],[18.86,49.52],[18.5,49.91],[17.64,50.11],[16.33,50.66],[15.35,50.87],[14.3,51.05],[12.95,50.4]],'Česko sousedí s Německem, Polskem, Slovenskem a Rakouskem. Hranice jsou zjednodušené. / Czechia borders Germany, Poland, Slovakia and Austria.')],[12,50],55,True)
