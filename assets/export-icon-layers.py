"""Export approved artwork as SVG layers; does not modify app resources."""
import argparse
from pathlib import Path
from copy import deepcopy as cp
import xml.etree.ElementTree as E
N='http://www.w3.org/2000/svg'; E.register_namespace('',N)
def tag(t):return '{'+N+'}'+t
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true', help='Verify layers without writing')
args=parser.parse_args()
source=E.parse(ROOT/'logo.svg').getroot()
art=[cp(e) for e in source if e.tag not in (tag('title'),tag('desc'))]
assert len(art)==9
background,signature,*foreground=art
background.attrib={'x':'0','y':'0','width':'256','height':'256','fill':'#782F9A'}
D=ROOT/'icon-layers'
def export(name,parts,transform=None):
 r=E.Element(tag('svg'),{'width':'1024','height':'1024','viewBox':'0 0 256 256','role':'img'})
 E.SubElement(r,tag('title')).text='Sinal Sync — '+name
 parent=r
 if transform:parent=E.SubElement(r,tag('g'),{'transform':transform})
 for el in parts:parent.append(cp(el))
 E.indent(r);p=D/(name+'.svg')
 content=E.tostring(r,encoding='utf-8',xml_declaration=True)
 if args.check:
  if not p.exists() or p.read_bytes()!=content:raise SystemExit(f'Out-of-date layer: {p}')
 else:
  p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
 return r
# Faithful 2-layer master: platform provides outside mask.
export('master/background',[background,signature])
export('master/foreground',foreground)
export('master/composite',[background,signature]+foreground)
# Conservative adaptive safe circle: content within central 66dp diameter on 108dp canvas.
tr='translate(128 128) scale(0.60) translate(-128 -128)'
g=E.Element(tag('g'),{'transform':tr});g.append(cp(signature))
export('android/background',[background,g])
export('android/foreground',foreground,tr)
fg=E.Element(tag('g'),{'transform':tr});fg.extend(cp(foreground))
export('android/composite',[background,g,fg])
# Composer controls background color and opacity; preserve semantic layers.
sig=cp(signature);sig.attrib.pop('opacity',None)
export('macos/01-wads-signature',[sig])
export('macos/02-devices',foreground[:4])
export('macos/03-transmission',foreground[4:])
# Both device interiors remain opaque purple to preserve approved occlusion.
for p in D.rglob('*.svg'):
 r=E.parse(p).getroot()
 assert r.get('viewBox')=='0 0 256 256'
 assert not any(e.tag in (tag('image'),tag('text'),tag('filter')) for e in r.iter())
print('Verified 9 SVGs; no files changed.' if args.check else 'Generated and validated 9 SVGs; native resources untouched.')
