"""Read atlas alpha bounds into geometry metadata; original images are never modified."""
import json
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parent.parent/'assets'
def bounds(path,cols,rows,heads=False):
    image=Image.open(path).convert('RGBA')
    width,height=image.size
    boxes=[]
    for row in range(rows):
        for col in range(cols):
            x0=col*width//cols;y0=row*height//rows
            x1=(col+1)*width//cols;y1=(row+1)*height//rows
            alpha=image.getchannel('A').crop((x0,y0,x1,y1)).point(lambda a:255 if a>100 else 0)
            b=alpha.getbbox()
            if b is None:raise ValueError('Empty atlas slot')
            if heads:
                upper=(b[0],b[1],b[2],b[1]+round((b[3]-b[1])*.25))
                hb=alpha.crop(upper).getbbox()
                b=(upper[0]+hb[0],upper[1]+hb[1],upper[0]+hb[2],upper[1]+hb[3])
            boxes.append([x0+b[0],y0+b[1],b[2]-b[0],b[3]-b[1]])
    return boxes

data={'parts':bounds(root/'rig-parts-v2.png',4,4),'heads':bounds(root/'characters-v2.png',4,3,True),'npc':bounds(root/'npc-parts-v2.png',4,2)}
(root/'rig-atlas.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print('Read alpha geometry for 16 body parts and 12 character heads; images unchanged')
