# Convert ChicletSlicer visuals to native Button slicers (advancedSlicerVisual), refactoring step 3b.
# Usage: python -I -X utf8 ChicletToButtonSlicer.py <Report folder> <style module: fox|literal> [--dry]
# Change log:
# 2026-10-28.1  Created (ClientB Page5, ClientC SalesNew, ClientE Sales Main — 9 chiclets).
import copy, glob, json, os, sys

REP = sys.argv[1]
MODE = sys.argv[2]
DRY = '--dry' in sys.argv
ClientB_REF = r'C:\Users\ayrat\OneDrive\Документы\Agency\ClientB\Sales Report\Sales_ClientB.Report\definition\pages\Page13\visuals\8840fadc9fd62c2ecc73\visual.json'


def L(v):
    return {'expr': {'Literal': {'Value': v}}}


def C(color):
    """color: '#RRGGBB' literal, or ('theme', id, pct), or already an expr dict."""
    if isinstance(color, str):
        e = {'Literal': {'Value': "'" + color + "'"}}
    elif isinstance(color, tuple):
        e = {'ThemeDataColor': {'ColorId': color[1], 'Percent': color[2]}}
    else:
        e = color
    return {'solid': {'color': {'expr': e}}}


def chiclet_color(prop):
    """chiclet color property -> raw expr dict"""
    return prop['solid']['color']['expr']


def props(v, obj):
    arr = v.get('objects', {}).get(obj, [])
    return arr[0].get('properties', {}) if arr else {}


def lit(p):
    return p['expr']['Literal']['Value'] if p and 'Literal' in p.get('expr', {}) else None


WILD = [{'dataViewWildcard': {'matchingOption': 1}}]


def literal_style(v, cfg):
    """Formatting objects built from the chiclet's own colors (no _Measures colors in the model)."""
    rows = props(v, 'rows')
    font = chiclet_color(rows['fontColor']) if 'fontColor' in rows else {'Literal': {'Value': "'#666666'"}}
    hover = chiclet_color(rows['hoverColor']) if 'hoverColor' in rows else {'Literal': {'Value': "'#212121'"}}
    sel = chiclet_color(rows['selectedColor']) if 'selectedColor' in rows else {'Literal': {'Value': "'#BDD7EE'"}}
    unsel = chiclet_color(rows['unselectedColor']) if 'unselectedColor' in rows else {'Literal': {'Value': "'#FFFFFF'"}}
    outline = chiclet_color(rows['outlineColor']) if 'outlineColor' in rows else {'Literal': {'Value': "'#000000'"}}
    # chiclet text renders ~0.8x of a button slicer at the same number (screenshot check, ClientC 2026-10-28)
    size = f"{round(float((lit(rows.get('textSize')) or '10D').rstrip('D')) * 0.8)}D"
    weight = lit(rows.get('outlineWeight')) or '1D'
    o = {
        'value': [
            {'properties': {'fontFamily': L("'Segoe UI'"), 'fontSize': L(size), 'bold': L('false'),
                            'horizontalAlignment': L("'center'"), 'fontColor': C(font)},
             'selector': {'id': 'default'}},
            {'properties': {'fontColor': C(hover)}, 'selector': {'id': 'interaction:hover'}},
            {'properties': {'fontColor': C(font)}, 'selector': {'id': 'selection:selected'}},
        ],
        'fillCustom': [
            {'properties': {'fillColor': C(unsel)}, 'selector': {'data': WILD, 'id': 'default', 'hierarchyMatching': 1}},
            {'properties': {'transparency': L('0D')}, 'selector': {'id': 'default'}},
            {'properties': {'fillColor': C(unsel)}, 'selector': {'data': WILD, 'id': 'interaction:hover', 'hierarchyMatching': 1}},
            {'properties': {'transparency': L('0D')}, 'selector': {'id': 'interaction:hover'}},
            {'properties': {'fillColor': C(sel)}, 'selector': {'data': WILD, 'id': 'selection:selected', 'hierarchyMatching': 1}},
            {'properties': {'transparency': L('0D')}, 'selector': {'id': 'selection:selected'}},
        ],
        'shapeCustomRectangle': [
            {'properties': {'tileShape': L("'rectangleRoundedByPixel'"), 'rectangleRoundedCurve': L(cfg.get('radius', '5L'))},
             'selector': {'id': 'default'}},
        ],
        'outline': [
            {'properties': {'show': L('true'), 'lineColor': C(outline), 'weight': L(weight)}, 'selector': {'id': s}}
            for s in ('default', 'interaction:hover', 'selection:selected')
        ],
        'padding': [
            {'properties': {'paddingSelection': L("'Custom'"), 'topMargin': L('0L'), 'bottomMargin': L('0L'),
                            'leftMargin': L('0L'), 'rightMargin': L('0L')}, 'selector': {'id': 'default'}},
        ],
    }
    return o


def fox_style(v, cfg):
    ref = json.load(open(ClientB_REF, encoding='utf-8'))['visual']['objects']
    return {k: copy.deepcopy(ref[k]) for k in ('value', 'fillCustom', 'shapeCustomRectangle', 'outline', 'padding')}


def convert(path, cfg):
    d = json.load(open(path, encoding='utf-8'))
    v = d['visual']
    assert v['visualType'].startswith('ChicletSlicer'), path
    gen = props(v, 'general')
    projs = v['query']['queryState']['Category']['projections']
    assert len(v['query']['queryState']) == 1, 'extra roles: ' + str(list(v['query']['queryState']))
    nv = {'visualType': 'advancedSlicerVisual',
          'query': {'queryState': {'Values': {'projections': copy.deepcopy(projs)}}}}
    for k in v['query']:
        if k != 'queryState':
            nv['query'][k] = copy.deepcopy(v['query'][k])
    if cfg.get('sort'):  # keep the chiclet's on-screen item order (button slicer sorts ascending by default)
        nv['query']['sortDefinition'] = {'sort': [{'field': copy.deepcopy(projs[0]['field']), 'direction': cfg['sort']}]}
    objs = {}
    if 'filter' in gen:
        objs['general'] = [{'properties': {'filter': copy.deepcopy(gen['filter'])}}]
    objs.update(fox_style(v, cfg) if MODE == 'fox' else literal_style(v, cfg))
    objs['layout'] = [{'properties': {'rowCount': L(f"{cfg['rows']}L"), 'columnCount': L(f"{cfg['cols']}L"),
                                      'maxTiles': L(f"{cfg['rows'] * cfg['cols']}L")}}]
    if 'cellPadding' in cfg:
        objs['layout'][0]['properties']['cellPadding'] = L(cfg['cellPadding'])
    multi = lit(gen.get('multiselect')) == 'true'
    objs['selection'] = [{'properties': {'strictSingleSelect': L('false' if multi else 'true'),
                                         'singleSelect': L('true')}}]
    nv['objects'] = objs
    vco = copy.deepcopy(v.get('visualContainerObjects', {}))
    # chiclet header hidden -> button slicer title hidden (unless a container title is set)
    hdr = lit(props(v, 'header').get('show'))
    if 'title' not in vco and hdr == 'false':
        vco['title'] = [{'properties': {'show': L('false')}}]
    if MODE == 'fox' and 'background' not in vco:
        vco['background'] = [{'properties': {'show': L('false')}}]
    if 'vpad' in cfg:  # [top/bottom, left/right] px: chiclet tiles have a fixed size, button tiles fill the visual
        tb, lr = cfg['vpad']
        vco['padding'] = [{'properties': {'top': L(f'{tb}D'), 'bottom': L(f'{tb}D'), 'left': L(f'{lr}D'), 'right': L(f'{lr}D')}}]
    nv['visualContainerObjects'] = vco
    for k in v:
        if k not in ('visualType', 'query', 'objects', 'visualContainerObjects'):
            nv[k] = copy.deepcopy(v[k])
    dropped = {k: list(props(v, k).keys()) for k in v.get('objects', {}) if k not in ('general',)}
    dropped['general'] = [k for k in gen if k != 'filter']
    d['visual'] = nv
    if not DRY:
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(d, f, ensure_ascii=False, indent=2)
    print('converted', os.path.relpath(path, REP), 'field', projs[0]['queryRef'], 'grid',
          f"{cfg['rows']}x{cfg['cols']}", 'sync', v.get('syncGroup', {}).get('groupName'),
          'strictSingle', not multi)
    print('   chiclet-only settings mapped/dropped:', dropped)


CFG = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] != '--dry' else {}
n = 0
for f in glob.glob(os.path.join(REP, 'definition', 'pages', '*', 'visuals', '*', 'visual.json')):
    d = json.load(open(f, encoding='utf-8'))
    if d.get('visual', {}).get('visualType', '').startswith('ChicletSlicer'):
        cfg = CFG[d['name'] + '@' + f.split(os.sep)[-4]] if (d['name'] + '@' + f.split(os.sep)[-4]) in CFG else CFG[d['name']]
        convert(f, cfg)
        n += 1
print('total', n)
