"""Compose Velours' 12 Blender previews into a labelled review image.

Run after build_accessories.py --preview:
  python3 scripts/mascot/render_accessory_contact_sheet.py
Requires Pillow. Existing model and GLB assets are not modified.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PREVIEWS = ROOT / 'scripts/mascot/previews'
CATALOG = json.loads((ROOT / 'scripts/mascot/accessories.json').read_text())['accessories']


def font(size, bold=False):
    source = ROOT / 'elyrii_app/assets/fonts' / ('Poppins-SemiBold.ttf' if bold else 'Poppins-Regular.ttf')
    return ImageFont.truetype(str(source), size)


def main():
    columns, card_w, card_h, gap = 4, 350, 470, 22
    top, margin = 118, 34
    width = margin*2 + columns*card_w + (columns-1)*gap
    height = top + 3*card_h + 2*gap + 36
    sheet = Image.new('RGB', (width, height), '#f4eee7')
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 25), 'Velours · 12 accessoires', font=font(33, True), fill='#512749')
    draw.text((margin, 72), 'Des objets 3D ajustés à sa silhouette, dans ses couleurs douces.', font=font(17), fill='#6e5869')
    for i, entry in enumerate(CATALOG):
        x = margin + (i%columns)*(card_w+gap)
        y = top + (i//columns)*(card_h+gap)
        draw.rounded_rectangle((x, y, x+card_w, y+card_h), radius=22, fill='#fffaf4')
        preview = Image.open(PREVIEWS/(entry['id']+'.png')).convert('RGBA')
        preview.thumbnail((330, 396), Image.Resampling.LANCZOS)
        sheet.paste(preview, (x+(card_w-preview.width)//2, y+10), preview)
        label=entry['labelFr']
        # Keep the longer bow label on the same baseline with a smaller type size.
        label_font=font(17 if len(label)>22 else 20, True)
        box=draw.textbbox((0,0),label,font=label_font)
        draw.text((x+(card_w-(box[2]-box[0]))/2,y+411),label,font=label_font,fill='#512749')
        detail='Vue de dos · bretelles visibles de face' if entry['id']=='mini_backpack' else ('Fixé au buste' if entry['parent']=='CTRL_chest' else 'Suit les mouvements de tête')
        detail_font=font(11)
        box=draw.textbbox((0,0),detail,font=detail_font)
        draw.text((x+(card_w-(box[2]-box[0]))/2,y+443),detail,font=detail_font,fill='#8b7381')
    output=PREVIEWS/'contact_sheet.png'
    sheet.save(output, optimize=True)
    print(output)


if __name__=='__main__':
    main()
