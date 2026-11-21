"""Redrawn at 32x32 with the exact game character palette. No v1 bitmap resizing."""
from pathlib import Path
import json, hashlib, zipfile, re
from PIL import Image, ImageDraw, ImageFont
import build_evidence_models as original

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/evidence-models-v2'
# Literal palette verified against scripts/pixel_skin.gd COLORS.
PALETTE=dict(ink='#171f27',edge='#2b383e',teal='#405958',light_teal='#69817b',paper='#e9dbb2',ochre='#ab843e',wood='#70532c',red='#985442',dark_red='#623638',blue='#324360',light_blue='#506581',plum='#775568',dark_plum='#4e3749',gray='#959085',dark_gray='#555057',olive='#6b704b',brown='#a67650',skin='#d9a56c',light='#efc58d',deep='#37333c')

class Pixel:
    def __init__(self):self.ops=[]
    def r(self,x,y,w,h,c):
        assert all(isinstance(v,int) for v in [x,y,w,h]) and w>0 and h>0
        assert x>=0 and y>=0 and x+w<=32 and y+h<=32
        self.ops.append(dict(shape='rect',x=x,y=y,width=w,height=h,color=c))
    def p(self,pts,c):
        assert all(0<=x<32 and 0<=y<32 for x,y in pts)
        self.ops.append(dict(shape='polygon',points=pts,color=c))
    def strokes(self,x,y,w,n=3,c='gray'):
        for i in range(n):self.r(x,y+i*4,max(2,w-(i%2)*3),2,c)
    def paper(self,x=8,y=4,w=16,h=23):
        # Uneven stepped silhouette, directional 2px shadows, no uniform outline.
        self.p([(x+1,y+2),(x+w-4,y+2),(x+w-1,y+5),(x+w-1,y+h-1),(x+3,y+h-1),(x+3,y+h),(x,y+h),(x,y+5)],'ink')
        self.p([(x,y+1),(x+2,y+1),(x+2,y),(x+w-5,y),(x+w-5,y+2),(x+w-3,y+2),(x+w-3,y+4),(x+w-1,y+4),(x+w-1,y+h-3),(x+2,y+h-3),(x+2,y+h-2),(x,y+h-2)],'paper')
        self.r(x+w-5,y+2,2,3,'ochre');self.r(x+2,y+2,2,h-7,'gray')
    def frame(self,x,y,w,h,c='wood'):
        self.r(x,y,w,h,'ink');self.r(x,y,w-2,h-2,c);self.r(x+2,y+2,w-6,h-6,'paper')
    def image(self):
        im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
        for o in self.ops:
            col=PALETTE[o['color']]
            if o['shape']=='rect':d.rectangle((o['x'],o['y'],o['x']+o['width']-1,o['y']+o['height']-1),fill=col)
            else:d.polygon(o['points'],fill=col)
        return im
    def svg(self):
        parts=[]
        for o in self.ops:
            col=PALETTE[o['color']]
            if o['shape']=='rect':parts.append(f'<rect x="{o["x"]}" y="{o["y"]}" width="{o["width"]}" height="{o["height"]}" fill="{col}"/>')
            else:parts.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in o['points'])+f'" fill="{col}"/>')
        return '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 32 32" shape-rendering="crispEdges">'+''.join(parts)+'</svg>'

def model(entry,second=False):
    id,title,k,accent,*_=entry;a=accent if accent in PALETTE else ('gray' if accent=='shade' else 'ochre');c=Pixel()
    if k=='calendar':
        c.p([(9,25),(23,25),(26,28),(5,28)],'wood');c.r(8,6,16,20,'paper');c.r(8,6,16,5,'red');c.r(8,6,2,20,'gray');c.r(22,9,2,17,'ochre');c.r(10,3,2,6,'ink');c.r(20,3,2,6,'ink')
        for x,y in [(11,13),(16,13),(20,13),(11,18),(16,18),(20,18)]:c.r(x,y,2,2,'wood')
        c.r(10,17,5,5,'red');c.r(12,19,1,1,'paper');c.r(18,22,4,3,'red')
    elif k=='clock':
        c.p([(8,6),(9,4),(22,4),(24,7),(24,25),(26,25),(26,28),(6,28),(6,25),(8,25)],'ink');c.r(8,6,14,19,'wood');c.r(10,8,10,13,'ochre');c.r(11,9,9,11,'paper');c.r(13,11,2,2,'ink');c.r(15,13,2,4,'ink');c.r(17,17,2,2,'red');c.r(8,25,16,2,'ochre');c.r(21,6,2,3,'deep')
    elif k=='doorplate':
        c.p([(3,12),(5,10),(27,10),(29,12),(29,21),(5,21),(3,19)],'ink');c.r(4,12,23,7,'teal');c.r(8,12,6,7,'wood');c.r(13,12,8,7,'gray');c.r(18,12,7,7,'light_teal');c.r(20,14,4,2,'ink');c.r(5,14,2,2,'paper');c.r(25,14,2,2,'paper')
    elif k=='ruler':
        c.p([(3,20),(25,9),(29,12),(29,16),(7,27),(3,24)],'ink');c.p([(4,20),(25,11),(27,12),(27,15),(6,25),(4,23)],'ochre')
        for x,y in [(9,19),(13,17),(17,15),(21,13)]:c.r(x,y,2,3,'wood')
        c.r(4,21,5,3,'paper');c.r(23,11,5,4,'paper');c.r(5,22,2,1,'teal');c.r(25,12,2,2,'blue')
    elif k=='ticket':
        c.p([(10,4),(23,4),(23,9),(25,9),(25,25),(22,25),(22,28),(9,28),(9,24),(7,24),(7,8),(10,8)],'ink');c.r(9,6,13,20,'ochre');c.r(10,6,2,20,'paper');c.r(15,16,2,4,'wood');c.r(15,20,6,2,'wood');c.r(17,10,4,2,'wood');c.r(15,24,5,1,'wood')
    elif k in {'ledger','names','empty'}:
        c.p([(3,9),(12,6),(16,8),(20,6),(29,8),(29,26),(19,28),(15,26),(4,28)],'ink');c.p([(4,10),(12,8),(14,10),(14,25),(5,26)],'paper');c.p([(17,10),(20,8),(27,10),(27,24),(19,26),(17,24)],'paper');c.r(14,10,3,16,'wood');c.r(5,12,2,12,'gray');c.strokes(8,12,5,3);c.strokes(19,12,6,3)
        if id=='c1.access':c.r(7,17,6,2,'teal');c.frame(22,20,8,9,'teal');c.r(25,23,2,2,'gray')
        if id=='c2.utility':c.r(26,12,3,3,'light_blue');c.r(26,19,3,3,'blue');c.r(5,23,8,2,'blue')
        if k=='names':c.frame(21,20,10,10,'plum');c.r(24,23,4,3,'gray');c.r(8,12,4,2,'plum')
        if k=='empty':c.r(18,11,8,13,'paper');c.r(20,16,5,2,'gray');c.r(19,21,3,2,'ochre');c.r(25,9,2,5,'wood')
    elif k=='map':
        c.p([(4,10),(9,6),(15,8),(20,5),(27,8),(28,23),(22,26),(15,24),(9,27),(4,24)],'ink');c.p([(4,10),(9,8),(15,10),(20,7),(25,10),(26,22),(22,24),(15,22),(9,25),(4,22)],'paper');c.r(10,10,2,13,'gray');c.r(17,10,2,13,'ochre');c.r(6,13,4,4,'olive');c.r(12,17,5,4,'teal');c.r(20,13,4,5,'red')
    elif k=='rubbing':
        c.p([(11,4),(21,5),(25,9),(23,15),(25,21),(22,27),(10,28),(7,23),(9,17),(7,10)],'ink');c.p([(11,6),(20,7),(23,10),(21,16),(23,21),(20,25),(12,26),(10,22),(12,16),(10,11)],'gray');c.strokes(13,10,7,3,'paper');c.r(15,23,5,2,'ochre')
    elif k=='film':
        c.r(3,11,26,12,'ink');c.r(3,11,24,10,'blue');c.r(7,13,17,6,'gray');c.r(8,14,5,4,'dark_plum');c.r(17,14,5,4,'plum')
        for x in [5,11,17,23]:c.r(x,11,2,1,'paper');c.r(x,21,2,1,'paper')
    elif k=='counter':
        c.p([(6,9),(26,9),(28,12),(28,23),(5,23),(3,20),(3,12)],'ink');c.r(5,11,21,10,'wood');c.r(7,12,7,5,'teal');c.r(17,12,7,5,'teal');c.r(9,13,3,3,'paper');c.r(19,13,3,3,'light_teal');c.r(7,19,7,2,'ochre');c.r(17,19,7,2,'ochre')
    elif k in {'meters','recovery'}:
        c.p([(5,6),(26,6),(28,9),(28,25),(6,25),(4,22),(4,9)],'ink');c.r(5,8,21,15,'gray' if k=='meters' else 'teal');c.r(7,10,7,10,'paper' if k=='meters' else 'ink');c.r(17,10,7,10,'paper' if k=='meters' else 'ink');c.r(15,9,2,13,'edge')
        if k=='meters':c.r(9,13,2,3,'wood');c.r(11,11,2,3,'wood');c.r(19,15,2,3,'blue');c.r(21,13,2,3,'blue')
        else:c.r(8,12,5,2,'gray');c.r(18,12,5,2,'gray');c.r(8,17,5,2,'red');c.r(18,17,5,2,'light_teal')
    elif k in {'timeline','zones','stack','port','upload','chain','network','algorithm','batch','deletion','register','ballots','statements'}:
        if k=='timeline':
            c.r(4,6,24,21,'ink');c.r(5,7,21,17,'teal')
            for i in range(3):c.r(7,10+i*5,17,2,'gray');c.r(13+i,9+i*5,4,4,'light_blue')
            c.r(23,8,2,15,'ochre')
        elif k=='zones':
            c.r(4,5,20,22,'ink');c.r(5,7,16,17,'teal');c.r(10,7,2,17,'light_teal');c.r(5,14,16,2,'light_teal');c.r(7,10,3,3,'ochre');c.r(15,19,3,3,'ochre');c.paper(19,16,11,14);c.r(23,21,4,2,'wood')
        elif k=='stack':
            c.frame(3,7,11,17,'teal');c.frame(19,10,11,17,'blue');c.r(11,9,11,2,'red');c.r(15,9,2,8,'red');c.r(10,22,11,2,'ochre');c.r(15,18,2,6,'ochre')
        elif k=='port':
            c.r(2,11,28,11,'ink');c.r(3,12,25,8,'wood')
            for i,col in enumerate(['teal','blue','ochre','plum']):c.r(4+i*6,14,5,4,col);c.r(5+i*6,15,2,2,'paper')
        elif k=='upload':
            c.frame(3,6,12,20,'teal');c.frame(21,11,10,15,'blue');c.r(11,12,14,2,'ochre');c.r(16,12,2,8,'ochre');c.r(17,18,7,2,'ochre');c.r(7,25,2,3,'wood')
        elif k=='chain':
            c.r(2,11,28,11,'ink');c.r(3,12,25,8,'paper');c.r(5,16,21,2,'wood')
            for i in range(4):c.r(5+i*6,14,4,5,'plum')
            c.r(10,13,2,7,'paper');c.r(23,13,2,7,'paper');c.r(14,20,2,6,'teal');c.r(14,24,10,2,'teal')
        elif k=='network':
            c.r(10,11,13,2,'gray');c.r(14,11,2,14,'gray');c.r(14,23,10,2,'gray');c.frame(3,5,11,11,'teal');c.frame(20,5,10,11,'blue');c.frame(11,19,11,11,'wood')
        elif k in {'algorithm','batch'}:
            c.frame(3,4,13,12,'teal' if k=='algorithm' else 'blue');c.r(13,11,9,2,a);c.r(19,12,2,10,a);c.frame(21,20,10,10,'wood');c.r(5,19,8,3,'ochre');c.r(7,24,8,3,'ochre')
        elif k=='deletion':
            c.paper(4,5,13,22);c.r(7,11,6,2,'wood');c.r(5,16,11,4,'dark_red');c.r(7,17,5,2,'red');c.paper(17,9,13,22);c.r(20,15,5,2,'gray');c.r(20,21,7,3,'teal')
        elif k=='register':
            c.r(4,6,24,22,'ink');c.r(5,7,21,18,'paper');c.r(11,8,2,17,'ochre');c.r(19,8,2,17,'ochre')
            for y in [12,18]:c.r(6,y,18,2,'gray')
            c.r(21,9,3,3,'teal');c.r(21,15,3,3,'gray');c.r(21,21,3,3,'gray')
        elif k=='ballots':
            for i in range(6):
                x=5+(i%2)*12;y=4+(i//2)*9;c.r(x,y,10,7,'ink');c.r(x,y,8,5,'paper');c.r(x+2,y+2,2,2,'ochre')
        elif k=='statements':
            for i in range(3):x=3+i*9;y=7+(i%2)*3;c.r(x,y,8,19,'ink');c.r(x,y,6,17,'paper');c.r(x+2,y+3,3,2,'gray');c.r(x+2,y+12,3,2,['teal','plum','blue'][i])
    else:
        if k=='scroll':
            c.r(7,6,18,23,'ink');c.r(8,7,15,18,'paper');c.r(6,4,20,4,'ochre');c.r(6,25,20,4,'wood');c.strokes(11,10,9,2)
            for x in [10,15,20]:c.r(x,20,3,3,'ochre')
        elif k=='petition':
            c.r(4,5,24,22,'ink');c.r(4,5,22,20,'paper');c.strokes(8,9,14,2);c.r(8,21,5,2,'teal');c.r(18,21,5,2,'blue');c.r(15,18,2,6,'ochre')
        elif k=='interview':
            c.frame(6,4,21,24,'wood');c.r(13,2,8,4,'gray');c.r(15,10,2,13,'ochre');c.strokes(9,10,5,3);c.strokes(18,10,4,2,'light_blue')
        elif k=='clipboard':
            c.frame(7,4,19,25,'wood');c.r(11,2,11,4,'gray');c.r(11,8,10,3,'ochre');c.strokes(11,14,10,2);c.r(11,22,10,3,'ochre')
        elif k=='medical':
            c.r(6,5,21,24,a);c.paper(9,7,16,20);c.r(13,10,6,2,a);c.r(15,9,2,5,a);c.strokes(13,16,8,2);c.r(26,11,3,5,'gray')
            if id=='c3.blank':c.r(12,16,10,7,'paper');c.r(12,16,10,2,'plum');c.r(12,21,10,2,'plum');c.r(12,17,2,5,'plum')
        elif k=='receipt':
            c.r(10,3,14,26,'ink');c.r(10,3,12,24,'paper');c.strokes(13,8,7,3);c.r(14,22,5,3,'teal')
            for y in [5,11,17,23]:c.r(9,y,3,2,'edge');c.r(21,y,3,2,'edge')
        elif k=='deeds':
            c.paper(4,8,15,21);c.r(8,14,7,2,'gray');c.r(8,22,4,3,'red');c.paper(15,4,14,22);c.r(20,10,5,2,'gray');c.r(20,19,4,3,'plum')
        elif k=='revision':
            c.paper(13,8,15,21);c.paper(9,6,15,21);c.paper(5,4,15,21);c.strokes(9,10,7,3);c.r(8,15,8,3,a);c.r(21,23,8,5,'paper');c.r(23,25,4,2,a)
        elif k=='dissent':
            c.paper();c.strokes(12,9,8,3);c.r(5,13,22,5,'ink');c.r(5,13,19,3,'gray');c.r(11,21,9,3,'red')
            if id=='c6.suppressed':c.r(21,22,8,7,'paper');c.r(23,25,4,2,'teal')
        elif k=='notice':
            c.paper(7,3,19,27);c.r(11,8,10,4,'red');c.strokes(11,16,10,2);c.r(9,4,2,2,'gray');c.r(22,6,2,2,'gray')
        elif k=='contract':
            c.paper(6,7,15,22);c.paper(12,4,16,23);c.strokes(17,10,6,2);c.r(17,20,7,2,'plum');c.r(17,24,7,1,'ochre')
        elif k=='application':
            c.paper();c.strokes(12,8,8,3);c.r(4,17,25,5,'dark_red');c.r(5,17,22,3,'red');c.r(11,24,10,1,'gray')
        elif k=='signed':
            c.paper(9,3,15,26);c.strokes(13,9,7,3);c.r(12,22,7,2,'wood');c.r(18,25,3,2,'ochre')
        elif k=='school':
            c.r(7,4,20,25,'ink');c.r(7,4,18,23,'wood');c.r(10,5,14,20,'paper');c.r(10,6,2,19,'red');c.strokes(14,9,7,3);c.r(19,22,3,2,'ochre')
        elif k=='recipe':
            c.p([(6,9),(20,4),(27,23),(23,28),(11,29),(7,25)],'ink');c.p([(7,10),(19,6),(25,23),(22,26),(12,27),(9,24)],'paper');c.strokes(12,11,8,3,'wood');c.r(13,20,9,2,'red');c.r(10,24,4,3,'wood')
        elif k=='form':
            c.paper(7,3,19,26);c.strokes(11,8,11,2)
            for y in [19,24]:c.r(11,y,3,3,'gray');c.r(12,y+1,1,1,'paper');c.r(17,y,5,2,'gray')
        elif k in {'letter','foldnote'}:
            c.p([(3,20),(17,18),(23,22),(23,28),(5,29)],'wood');c.r(4,20,17,7,'ochre');c.r(6,22,5,2,'wood');c.r(11,24,4,2,'wood');c.paper(14,4,15,23);c.strokes(19,10,6,3,'plum' if k=='letter' else 'gray')
        else:raise ValueError(k)
    if second:
        # Draw secondary geometry anew at 32px. Physical objects stay physical.
        if k in {'clock','doorplate','ruler','ticket'}:
            if k=='clock':c.r(10,8,11,14,'wood');c.r(12,11,7,9,'deep');c.r(15,16,2,3,'ochre');c.r(10,22,10,2,'gray')
            elif k=='doorplate':c.r(6,13,20,5,'wood');c.r(9,14,2,2,'ink');c.r(22,14,2,2,'ink');c.r(14,13,5,2,'gray')
            elif k=='ruler':c.r(12,18,6,2,'wood');c.r(20,14,4,2,'olive')
            else:c.r(12,7,9,16,'ochre');c.strokes(14,10,5,3,'wood');c.r(13,24,7,1,'wood')
        elif k in {'map','ledger','names','empty'}:
            c.r(18,11,8,13,'paper');c.strokes(19,12,6,3,'wood');c.r(6,17,7,2,a)
            if k=='empty':c.r(18,11,8,13,'paper');c.r(20,20,5,2,'gray')
        elif k=='rubbing':c.r(12,10,10,12,'gray');c.strokes(13,11,7,3,'paper');c.r(11,24,8,2,'wood')
        else:
            c=Pixel();c.paper(4,5,25,25);c.r(16,8,2,19,'ochre');c.strokes(8,10,6,3);c.strokes(20,10,5,2,a)
            if k in {'form','medical','contract'}:c.r(9,23,5,2,'gray');c.r(20,23,5,2,'gray')
            elif k in {'letter','foldnote','dissent','scroll'}:c.r(8,22,15,3,a)
            elif k=='receipt':c.r(21,20,5,5,'teal')
            else:c.r(20,23,5,2,a)
    return c

def create():
    OUT.mkdir(parents=True,exist_ok=True)
    palette_source=(ROOT/'scripts/pixel_skin.gd').read_text('utf-8').split('const COLORS=')[1].split('\n')[0]
    assert {v[1:] for v in PALETTE.values()}==set(re.findall(r'"([0-9a-f]{6})"',palette_source))
    previous=json.loads((ROOT/'assets/evidence-models-v1/manifest.json').read_text('utf-8'))
    old_by_id={x['id']:x for x in previous['items']};items=[]
    for entry in original.SPEC:
        id=entry[0];m=dict(old_by_id[id]);folder=OUT/id.replace('.','-');folder.mkdir(exist_ok=True);geometries={}
        for label,is_second in [('front',False),('secondary',True)]:
            art=model(entry,is_second);im=art.image();im.save(folder/f'{label}-32x32.png');im.resize((192,192),Image.Resampling.NEAREST).save(folder/f'{label}.png');(folder/f'{label}.svg').write_text(art.svg(),'utf-8');geometries[label]=art.ops
        front=model(entry).image();front.save(folder/'icon.png');front.resize((64,64),Image.Resampling.NEAREST).save(folder/'icon-64.png')
        m.update(design_status='redrawn_after_style_feedback',dimensions=dict(native=[32,32],inventory=[32,32],inventory_display=[64,64],inspection=[192,192]),pivot=[96,168],assets={kind:f'{folder.name}/{kind}.png' for kind in ['icon','front','secondary']},palette_source='scripts/pixel_skin.gd COLORS',native_pixel_scale=6)
        # Map broad fields to coarse native clusters, with exact integer coordinates.
        front_labels=[h['label'] for h in m['hotspots'] if h['view']=='front'];n=len(front_labels)
        hotspot_boxes=[]
        if entry[2] in {'ruler','doorplate','port','film'}:hotspot_boxes=[(3,10,12,15),(16,8,14,18)]
        elif entry[2]=='calendar':hotspot_boxes=[(9,16,7,7),(17,19,7,7)]
        elif entry[2]=='clock':hotspot_boxes=[(11,9,10,11),(20,5,5,6)]
        elif n==3:hotspot_boxes=[(3+i*9,8,8,19) for i in range(3)]
        else:hotspot_boxes=[(6,7,11,17),(17,10,12,18)]
        m['hotspots']=[dict(id=f'front_{i}',view='front',rect=[v*6 for v in hotspot_boxes[i]],label=label,description=m['inspect_note']) for i,label in enumerate(front_labels)]
        m['hotspots'].append(dict(id='secondary',view='secondary',rect=[24,30,150,150],label=m['secondary_label'],description='检查展开页、背面或附件。关键文字仍由界面层呈现。'))
        if id=='c3.clock':m['inspect_note']='指针角度仅为造型示意；真实停表时点未设定，不能用于时间核验。'
        (folder/'model.json').write_text(json.dumps({**m,'models':geometries},ensure_ascii=False,indent=2),'utf-8');items.append(m)
    result=dict(version=2,palette=PALETTE,count=49,items=items,pixel_rules=dict(native_size=32,inspection_integer_scale=6,inventory_integer_scale=2,no_antialias=True,no_gradients=True,redrawn_from_geometry=True))
    (OUT/'manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),'utf-8')
    previews(items);docs(items);gallery(items);validate(items);package()

def font(size):return ImageFont.truetype(str(ROOT/'assets/fonts/pixel-text.otf'),size)

def previews(items):
    p=OUT/'previews';p.mkdir(exist_ok=True)
    atlas=Image.new('RGBA',(320,160))
    for i,m in enumerate(items):atlas.alpha_composite(Image.open(OUT/m['assets']['icon']),((i%10)*32,(i//10)*32))
    atlas.save(OUT/'inventory-atlas.png')
    overview=Image.new('RGB',(1440,1710),PALETTE['ink']);d=ImageDraw.Draw(overview);d.text((30,22),'启动阶段 / 粗像素证物 · 重绘版',font=font(30),fill=PALETTE['paper']);d.text((30,66),'32×32 原生 / 游戏同一调色板 / 整数倍显示 / 六章 49 件',font=font(18),fill=PALETTE['gray'])
    for ch in range(1,7):
        group=[m for m in items if m['chapter']==ch];y=110+(ch-1)*262;d.text((30,y),f'第 {ch} 章',font=font(20),fill=PALETTE['ochre'])
        for i,m in enumerate(group):
            x=30+i*154;im=Image.open(OUT/m['assets']['icon']).resize((128,128),Image.Resampling.NEAREST);overview.paste(im,(x,y+26),im);title=m['title'];d.text((x,y+157),title[:8],font=font(16),fill=PALETTE['paper']);d.text((x,y+181),title[8:16],font=font(16),fill=PALETTE['paper']);d.text((x,y+212),'人物页' if m['category']=='collection' else '核心条目',font=font(16),fill=PALETTE['gray'])
        rows=(len(group)+2)//3;sheet=Image.new('RGB',(1200,90+rows*290),PALETTE['ink']);sd=ImageDraw.Draw(sheet);sd.text((24,18),f'第 {ch} 章 / 32×32 粗像素模型',font=font(30),fill=PALETTE['paper'])
        for i,m in enumerate(group):
            x=20+(i%3)*394;yy=84+(i//3)*290;sd.rectangle((x,yy,x+374,yy+270),fill=PALETTE['edge']);im=Image.open(OUT/m['assets']['icon']).resize((192,192),Image.Resampling.NEAREST);sheet.paste(im,(x+90,yy+2),im);sd.text((x+12,yy+204),m['title'],font=font(20),fill=PALETTE['paper']);sd.text((x+12,yy+237),m['id'],font=font(16),fill=PALETTE['gray'])
        sheet.save(p/f'chapter-{ch}.png')
    overview.save(p/'all-evidence.png')
    # Review composition is generated separately. It does not change game backgrounds.
    review=Image.new('RGB',(1280,720),PALETTE['ink']);rd=ImageDraw.Draw(review);rd.text((30,20),'与现有游戏配色、像素颗粒对照',font=font(26),fill=PALETTE['paper']);rd.text((30,58),'物件 32×32 · 对照图，不是实装截图',font=font(18),fill=PALETTE['gray'])
    screenshot=Image.open(ROOT/'build/v6/apartment.png').convert('RGB');review.paste(screenshot.resize((960,540),Image.Resampling.NEAREST),(0,120))
    for i,id in enumerate(['c1.calendar','c1.shoe','c3.clock','c4.ruler']):
        m=next(x for x in items if x['id']==id);im=Image.open(OUT/m['assets']['icon']).resize((96,96),Image.Resampling.NEAREST);y=110+i*145;review.paste(im,(1010,y),im);rd.text((980,y+95),m['title'][:11],font=font(18),fill=PALETTE['paper'])
    review.save(p/'game-style-comparison.png')

def docs(items):
    lines=['# 证物模型 v2 · 粗像素重绘','', '日期：2026-09-30。用户指出 v1 不符合整体美术，本版逐件重画 49 个模型；v1 保留为被否定的旧稿。没有修改正式游戏。','',
    '## 本次修正','', '- 原生网格从 80×56 改为 32×32，直接从新几何画出，没有缩小旧 PNG 冒充重绘。','- 使用 scripts/pixel_skin.gd 中完全相同的 20 色母调色板，单件限制在 10 色以内。','- 粗轮廓、阶梯边缘、不对称折角、2px 主块。减少文书细线和均匀黑框，让色块体积优先。','- 原生图标 32×32，收集栏显示图 64×64；检查图 192×192，都是整数倍最近邻。','- 每件独立正面与第二视图、PNG、SVG、几何 JSON、检查热点。','- 关键文字仍放在可读的 UI 正文层，像素图不编造时间、签名或真实文字。','',
    '## 对照依据','', '检查了 build/v6/apartment.png 的实际游戏截图、scripts/pixel_skin.gd 的调色板与 docs/人物动作修复-v0.3.md 的粗颗粒约束。对照图只是美术审阅合成，不是正式游戏已接入截图。审美是否匹配仍由用户判断，文件检查不能替代该判断。','',
    '## 49 件分别建模','', '| ID／证物 | 载体 | 第二视图 | 检查点 |','|---|---|---|---|']
    for m in items:lines.append(f'| `{m["id"]}` / {m["title"]} | {m["carrier"]} | {m["secondary_label"]} | '+ '；'.join(h['label'] for h in m['hotspots'] if h['view']=='front')+' |')
    lines+=['','## 来源与剧情边界','', '数字记录模型仍是案卷展示代理，不表示从现场带走机器。c3.blank、c5.empty、c5.letter 保留原有同源关联，不额外计为独立证据。闻遥钟的指针为造型示意，不能当作已经设定的停表时间。上传表初始选择均为空。','',
    '## 文件','', '- assets/evidence-models-v2/gallery.html：全部逐件查看，含剧透入口、检查视图与热点。','- assets/evidence-models-v2/previews/：总览、六章分图、游戏风格对照。','- assets/evidence-models-v2/<条目 ID>/：32px 原生、64px 图标、192px 检查图、SVG、model.json。','- assets/evidence-models-v2/manifest.json：统一索引。','- assets/evidence-models-v2/validation.json：文件和像素检查记录。','- build/EvidenceModels-v2-CoarsePixel.zip：完整包。','',
    '检查已完成：覆盖数量、游戏调色板一致、透明底、每件色数、尺寸、整数倍像素块、图标独立、正面与第二视图区分、热点范围。浏览器检查记录另写入 validation.json。本版仍为素材设计交付，尚未接入 Godot 或改变存档。','']
    (ROOT/'docs/证物模型设计-v2-粗像素重绘.md').write_text('\n'.join(lines),'utf-8')

def gallery(items):
    # Reuse the working catalog shell, updated to the new native geometry and rules.
    original_out=original.OUT
    try:
        original.OUT=OUT;original.make_gallery(items)
    finally:original.OUT=original_out
    path=OUT/'gallery.html';html=path.read_text('utf-8');html=html.replace('49 个独立展示条目 / 16 色 / 透明像素素材 / 正面与检查视图','粗像素重绘 / 32×32 原生 / 游戏同一调色板 / 49 个条目')
    html=html.replace('width:96px;height:96px','width:64px;height:64px').replace('width:72px;height:72px','width:64px;height:64px').replace('aspect-ratio:160/112','aspect-ratio:1/1').replace('/160*100','/192*100').replace('/112*100','/192*100').replace('max-width:640px','max-width:576px')
    html=html.replace("'<dt>检查</dt>'","'<dt>检查</dt>'")
    # Native UI font already ships with the project; no network fonts.
    html=html.replace('<style>','<style>@font-face{font-family:GamePixel;src:url(../fonts/pixel-text.otf)}')
    html=html.replace('"Microsoft YaHei",sans-serif','GamePixel,"Microsoft YaHei",sans-serif')
    path.write_text(html,'utf-8')

def validate(items):
    assert len(items)==49;hashes=[];counts=[]
    allowed={tuple(bytes.fromhex(h[1:]))+(255,) for h in PALETTE.values()}
    for m in items:
        folder=OUT/m['id'].replace('.','-');front=Image.open(folder/'front-32x32.png').convert('RGBA');second=Image.open(folder/'secondary-32x32.png').convert('RGBA');assert front.tobytes()!=second.tobytes()
        for label,native in [('front',front),('secondary',second)]:
            assert native.size==(32,32) and native.getextrema()[3][0]==0
            colors=set(native.get_flattened_data());assert all(p[3]==0 or p in allowed for p in colors);count=sum(p[3]!=0 for p in colors);assert count<=10,(m['id'],count);counts.append(count)
            scaled=Image.open(folder/f'{label}.png');assert scaled.size==(192,192);assert scaled.tobytes()==native.resize((192,192),Image.Resampling.NEAREST).tobytes()
        icon=Image.open(folder/'icon.png');assert icon.size==(32,32);hashes.append(hashlib.sha256(icon.tobytes()).hexdigest())
        for h in m['hotspots']:
            x,y,w,hh=h['rect'];assert x>=0 and y>=0 and x+w<=192 and y+hh<=192
    assert len(set(hashes))==49,'Duplicate icon'
    report=dict(version=2,entries=49,core=37,collection=12,native=[32,32],inspection=[192,192],shared_game_palette=True,max_item_colors=max(counts),unique_icons=49,geometry_redrawn=True,transparent=True,integer_upscale=True,browser_check='pending',game_integrated=False)
    (OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')

def package():
    dest=ROOT/'build/EvidenceModels-v2-CoarsePixel.zip'
    with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as z:
        for p in OUT.rglob('*'):
            if p.is_file():z.write(p,p.relative_to(OUT.parent))
        z.write(ROOT/'docs/证物模型设计-v2-粗像素重绘.md','证物模型设计-v2-粗像素重绘.md');z.write(Path(__file__),'build_evidence_models_v2.py');z.write(ROOT/'scripts/build_evidence_models.py','build_evidence_models.py')
    print(json.dumps(dict(entries=49,zip=str(dest),sha256=hashlib.sha256(dest.read_bytes()).hexdigest()),ensure_ascii=False))

if __name__=='__main__':create()
