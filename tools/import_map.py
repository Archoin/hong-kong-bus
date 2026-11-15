"""Build a compact ODbL-derived street/building dataset from an OSM XML extract.
Rebuild dependency: shapely (pip install --target /tmp/hkbus-map-deps shapely pillow).
Original XML is retained under tools/map_source and is not shipped in the game.
"""
import sys, json, math, random, collections, xml.etree.ElementTree as ET
from pathlib import Path
sys.path.insert(0,'/tmp/hkbus-map-deps')
from shapely.geometry import Point, LineString, Polygon, box
from shapely.ops import unary_union, split, linemerge
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
ORIGIN=(114.1515,22.2858); SCALE=.8
XMET=111320*math.cos(math.radians(ORIGIN[1]))*SCALE; ZMET=111320*SCALE
BOUNDS=(-560,-330,560,330); REGION=box(*BOUNDS)
def project(lon,lat):return ((lon-ORIGIN[0])*XMET,(ORIGIN[1]-lat)*ZMET)
def unproject(x,z):return ORIGIN[0]+x/XMET,ORIGIN[1]-z/ZMET
root=ET.parse(ROOT/'tools/map_source/sheung_wan.osm').getroot()
nodes={int(n.attrib['id']):project(float(n.attrib['lon']),float(n.attrib['lat'])) for n in root.findall('node')}
ways=[]
for way in root.findall('way'):
 tags={t.attrib['k']:t.attrib['v'] for t in way.findall('tag')}
 points=[nodes[int(n.attrib['ref'])] for n in way.findall('nd') if int(n.attrib['ref']) in nodes]
 if len(points)>1:ways.append((int(way.attrib['id']),tags,points))
# DEM is a coarse surface model. Smooth building noise and cap grid gradients for arcade handling.
elev=json.loads((ROOT/'tools/map_source/elevation.json').read_text()); EW=len(elev['lons']);EH=len(elev['lats'])
grid=[[max(0,elev['elevation'][r*EW+c]-5)*.70 for c in range(EW)] for r in range(EH)]
for _ in range(2):
 grid=[[sum(grid[min(EH-1,max(0,r+dr))][min(EW-1,max(0,c+dc))]*(4 if dr==dc==0 else 1) for dr in [-1,0,1] for dc in [-1,0,1])/12 for c in range(EW)] for r in range(EH)]
# Keep the reclamation/harbor edge almost level; retain the rising Hollywood/SoHo ground.
for r in range(EH):
 for c in range(EW):
  if r<=1:grid[r][c]*=.15 if r==0 else .40
for _ in range(15):
 for r in range(EH):
  for c in range(EW):
   neighbors=[grid[rr][cc]+15 for rr,cc in [(r-1,c),(r+1,c),(r,c-1),(r,c+1)] if 0<=rr<EH and 0<=cc<EW]
   grid[r][c]=min(grid[r][c],min(neighbors))
gx=[project(v,ORIGIN[1])[0] for v in elev['lons']];gz=[project(ORIGIN[0],v)[1] for v in elev['lats']]
def terrain(x,z):
 fx=max(0,min(EW-1.000001,(x-gx[0])/(gx[-1]-gx[0])*(EW-1)));fz=max(0,min(EH-1.000001,(z-gz[0])/(gz[-1]-gz[0])*(EH-1)))
 c=int(fx);r=int(fz);u=fx-c;v=fz-r
 return (grid[r][c]*(1-u)+grid[r][c+1]*u)*(1-v)+(grid[r+1][c]*(1-u)+grid[r+1][c+1]*u)*v

def line_parts(g):
 if g.is_empty:return []
 if g.geom_type=='LineString':return [g]
 if hasattr(g,'geoms'):return [v for v in g.geoms if v.geom_type=='LineString']
 return []
ROAD_TYPES={'primary','primary_link','secondary','secondary_link','tertiary','tertiary_link','residential','unclassified','trunk'}
raw=[];flyovers=[];pedestrian=[]
for oid,t,ps in ways:
 line=LineString(ps); clipped=line.intersection(REGION)
 if clipped.is_empty:continue
 name=t.get('name:en',t.get('name',''))
 if t.get('highway') in ['steps','pedestrian']:
  for part in line_parts(clipped):pedestrian.append({'points':[list(p) for p in part.coords],'name':name,'steps':t.get('highway')=='steps'})
 if t.get('highway') not in ROAD_TYPES and not (t.get('highway')=='service' and name.startswith('Des Voeux')):continue
 if t.get('tunnel') in ['yes','building_passage'] or int(t.get('layer','0'))<0:continue
 if t.get('bridge') or int(t.get('layer','0'))>0:
  if 'Connaught' in name or 'Rumsey' in name:
   for part in line_parts(clipped):flyovers.append({'points':[list(p) for p in part.coords],'name':name})
  continue
 if 'Bypass' in name:continue
 width=26 if name.startswith('Connaught') else 23 if name.startswith('Des Voeux') else 16 if "Queen's" in name else 13 if name in ['Hollywood Road','Bonham Strand','Wing Lok Street','Jervois Street'] else 11.5
 for part in line_parts(clipped):
  # Keep source junction vertices; densify long edges for hillside conformity.
  ps=list(part.coords)
  for a,b in zip(ps,ps[1:]):
   length=math.dist(a,b)
   if length<.3:continue
   count=max(1,math.ceil(length/14))
   for k in range(count):
    aa=(a[0]+(b[0]-a[0])*k/count,a[1]+(b[1]-a[1])*k/count);bb=(a[0]+(b[0]-a[0])*(k+1)/count,a[1]+(b[1]-a[1])*(k+1)/count)
    raw.append({'a':aa,'b':bb,'width':width,'name':name,'osm_id':oid,'tram':name.startswith('Des Voeux')})
# Rebuild a shared coordinate graph and keep the largest connected street component.
lookup={}; verts=[];edges=[]
def node(p):
 key=(round(p[0],2),round(p[1],2))
 if key not in lookup:lookup[key]=len(verts);verts.append(key)
 return lookup[key]
for e in raw:e['i']=node(e['a']);e['j']=node(e['b']);edges.append(e)
adj=collections.defaultdict(set)
for e in edges:adj[e['i']].add(e['j']);adj[e['j']].add(e['i'])
components=[];seen=set()
for i in range(len(verts)):
 if i in seen:continue
 comp=set([i]);seen.add(i);todo=[i]
 while todo:
  n=todo.pop()
  for j in adj[n]:
   if j not in seen:seen.add(j);comp.add(j);todo.append(j)
 components.append(comp)
main=max(components,key=len); remap={old:new for new,old in enumerate(sorted(main))}
verts3=[[verts[i][0],round(terrain(*verts[i]),3),verts[i][1]] for i in sorted(main)]
edges=[e for e in edges if e['i'] in main and e['j'] in main]
for e in edges:e['i']=remap[e['i']];e['j']=remap[e['j']];e['a']=verts3[e['i']];e['b']=verts3[e['j']]
# Tram movement follows actual railway=tram geometry, independent of car-junction topology.
import heapq
rail_lookup={};rail_nodes=[];rail_adj=collections.defaultdict(list)
def rail_node(p):
 key=(round(p[0],3),round(p[1],3))
 if key not in rail_lookup:rail_lookup[key]=len(rail_nodes);rail_nodes.append(key)
 return rail_lookup[key]
for oid,t,ps in ways:
 if t.get('railway')!='tram' or t.get('service')=='siding':continue
 for part in line_parts(LineString(ps).intersection(REGION)):
  coords=list(part.coords)
  for a,b in zip(coords,coords[1:]):
   i=rail_node(a);j=rail_node(b);length=math.dist(a,b)
   rail_adj[i].append((j,length));rail_adj[j].append((i,length))
rail_components=[];seen=set()
for i in range(len(rail_nodes)):
 if i in seen:continue
 comp={i};todo=[i];seen.add(i)
 while todo:
  for j,_ in rail_adj[todo.pop()]:
   if j not in seen:seen.add(j);comp.add(j);todo.append(j)
 rail_components.append(comp)
rail_main=max(rail_components,key=lambda c:max(rail_nodes[i][0] for i in c)-min(rail_nodes[i][0] for i in c))
start=min(rail_main,key=lambda i:rail_nodes[i][0]);end=max(rail_main,key=lambda i:rail_nodes[i][0])
queue=[(0,start)];dist={start:0};previous={}
while queue:
 cost,n=heapq.heappop(queue)
 if n==end:break
 if cost>dist[n]:continue
 for j,c in rail_adj[n]:
  if cost+c<dist.get(j,float('inf')):dist[j]=cost+c;previous[j]=n;heapq.heappush(queue,(cost+c,j))
rail_path=[];n=end
while n!=start:rail_path.append(rail_nodes[n]);n=previous[n]
rail_path.append(rail_nodes[start]);rail_path.reverse()
tram_path=[]
for a,b in zip(rail_path,rail_path[1:]):
 count=max(1,math.ceil(math.dist(a,b)/8))
 for j in range(count):
  x=a[0]+(b[0]-a[0])*j/count;z=a[1]+(b[1]-a[1])*j/count
  tram_path.append([round(x,3),round(terrain(x,z),3),round(z,3)])
x,z=rail_path[-1];tram_path.append([x,terrain(x,z),z])
rail_line=LineString(rail_path)
for e in edges:
 e['tram']=rail_line.distance(Point((e['a'][0]+e['b'][0])/2,(e['a'][2]+e['b'][2])/2))<9

# Continuous visible curb boundaries avoid stacked lane stripes at intersections.
paint_union=unary_union([LineString([(e['a'][0],e['a'][2]),(e['b'][0],e['b'][2])]).buffer(e['width']/2-.35,cap_style=1,join_style=1) for e in edges])
paint_parts=[paint_union] if paint_union.geom_type=='Polygon' else list(paint_union.geoms)
curb_lines=[]
for poly in paint_parts:
 for ring in [poly.exterior]+list(poly.interiors):
  curb_lines.append([[round(x,2),round(z,2)] for x,z in ring.simplify(.25).coords])

# Road setbacks are deliberate; real narrow streets widened by 0–4m for a 6m minibus.
roads_union=unary_union([LineString([(e['a'][0],e['a'][2]),(e['b'][0],e['b'][2])]).buffer(e['width']/2+2.4,cap_style=1,join_style=1) for e in edges])
landmark_names=['Western Market','Man Mo Temple','Central Market','The Center','PMQ']
landmarks={};buildings=[];rng=random.Random(8311)
for oid,t,ps in ways:
 name=t.get('name:en',t.get('name',''))
 if len(ps)<4 or ps[0]!=ps[-1]:continue
 poly=Polygon(ps)
 if not poly.is_valid:poly=poly.buffer(0)
 if poly.is_empty or not poly.intersects(REGION):continue
 if name in landmark_names and (t.get('building') or name not in landmarks):
  landmarks[name]={'center':list(poly.centroid.coords)[0],'polygon':list(poly.exterior.coords) if poly.geom_type=='Polygon' else [],'tags':{k:v for k,v in t.items() if k in ['height','building:levels','building','name:zh']}}
 if 'building' not in t or t.get('building') in ['roof','construction','no']:continue
 if poly.area<25 or poly.area>22000:continue
 poly=poly.intersection(REGION).difference(roads_union)
 if poly.is_empty:continue
 parts=[poly] if poly.geom_type=='Polygon' else [p for p in poly.geoms if p.geom_type=='Polygon']
 for part in parts:
  if part.area<32:continue
  part=part.simplify(.55,preserve_topology=True)
  if part.area<32:continue
  x,z=part.centroid.coords[0]
  try:h=float(t.get('height','').split(' ')[0])*.72
  except ValueError:
   try:h=float(t.get('building:levels',''))*2.9
   except ValueError:h=rng.choice([14,18,23,29,36,44,55,68])*(1.15 if x>140 else 1)
  if name=='Western Market':h=17
  elif name=='Man Mo Temple':h=8
  elif name=='The Center':h=220
  h=max(9,min(230,h))
  buildings.append({'osm_id':oid,'name':name,'points':[[round(v,2) for v in p] for p in list(part.exterior.coords)[:-1]],'height':round(h,2),'base':round(min(terrain(*p) for p in part.exterior.coords),3),'style':('glass' if h>80 or t.get('building')=='office' else 'tenement'),'seed':rng.randrange(100000)})
# OSM sometimes contains an outline and an almost identical building part.
# Retain the larger footprint once, avoiding flickering coplanar facades.
from shapely.strtree import STRtree
accepted=[];polys=[]
for b in sorted(buildings,key=lambda b:Polygon(b['points']).area,reverse=True):
 poly=Polygon(b['points'])
 if not poly.is_valid:poly=poly.buffer(0)
 duplicate=False
 for existing in polys:
  if existing.intersects(poly) and existing.intersection(poly).area>poly.area*.88:
   duplicate=True;break
 if not duplicate:accepted.append(b);polys.append(poly)
buildings=accepted

# Native coastline reference, joined into mainland boundary. Ferry piers remain separate features.
coastlines=[]
for oid,t,ps in ways:
 if t.get('natural')=='coastline':
  for p in line_parts(LineString(ps).intersection(REGION)):
   coastlines.append([list(c) for c in p.coords])
# A shoreline sampled from the OSM mainland run (north of coastal highways), excluding terminal fingers.
maincoast=[]
for oid,t,ps in ways:
 if oid in [1117392693,1117392694,1117392695,1117392696,1117392697,1117392698,1117603244,276452994]:
  maincoast.extend(ps)
maincoast.sort(key=lambda p:p[0]); clean=[]
for p in maincoast:
 if not clean or abs(p[0]-clean[-1][0])>1:clean.append(p)
# At any east-west position, use the outermost sampled mainland boundary.
def shore_z(x):
 for a,b in zip(clean,clean[1:]):
  if a[0]<=x<=b[0]:return a[1]+(b[1]-a[1])*(x-a[0])/max(.01,b[0]-a[0])
 return clean[0][1] if x<clean[0][0] else clean[-1][1]
shore=[[round(x,2),round(shore_z(x),2)] for x in range(-560,561,16)]
# Stop sites are real places; service bays are projected to the nearest connected drivable street.
sites=[
 ('Western Market','WESTERN',114.15044,22.28708,'market','Des Voeux'),
 ('Macau Ferry Terminal','FERRY',114.15165,22.28805,'harbour','Chung Kong'),
 ('Waterfront Park','WATERFRONT',114.14555,22.28875,'harbour','Western Fire'),
 ('Dried Seafood Street','SEAFOOD',114.14710,22.28765,'market','Des Voeux'),
 ('Bonham Strand','BONHAM',114.14950,22.28615,'market','Bonham'),
 ('Hollywood Road Park','HOLLYWOOD',114.14775,22.28545,'heritage','Hollywood'),
 ('Cat Street / Lok Ku','CAT ST',114.14920,22.28475,'heritage','Lok Ku'),
 ('Man Mo Temple','MAN MO',114.15018,22.28410,'heritage','Hollywood'),
 ('PMQ / Aberdeen St','PMQ',114.15220,22.28360,'creative','Aberdeen'),
 ('Central Market','CENTRAL',114.15545,22.28425,'business','Des Voeux'),
 ('SoHo / Gage Street','SOHO',114.15365,22.28300,'nightlife','Gage'),
 ('Sheung Wan Station','MTR',114.15270,22.28635,'business','Des Voeux')]
colors=['efb64b','5cd9dd','80c6ad','ea926d','e2b789','badd72','ed8fbd','d6da78','aa9fe3','ff9175','d98bcc','87b9e8']
stops=[]
for idx,(name,short,lon,lat,zone,pref) in enumerate(sites):
 pt=Point(project(lon,lat)); candidates=[e for e in edges if pref in e['name']] or edges
 edge=min(candidates,key=lambda e:LineString([(e['a'][0],e['a'][2]),(e['b'][0],e['b'][2])]).distance(pt))
 a=edge['a'];b=edge['b'];line=LineString([(a[0],a[2]),(b[0],b[2])]);q=line.interpolate(line.project(pt));x,z=q.coords[0]
 dx=b[0]-a[0];dz=b[2]-a[2];length=math.hypot(dx,dz);dx/=length;dz/=length
 # Make stop direction eastward on horizontal streets / northward on steep cross streets.
 if (abs(dx)>abs(dz) and dx<0) or (abs(dx)<=abs(dz) and dz>0):dx=-dx;dz=-dz
 left=(dz,-dx)
 offset=edge['width']/2-3.1
 pos=(x+left[0]*offset,z+left[1]*offset); curb=(x+left[0]*(edge['width']/2+1.5),z+left[1]*(edge['width']/2+1.5))
 stops.append({'name':name,'short':short,'position':[round(pos[0],2),round(terrain(*pos),3),round(pos[1],2)],'curb':[round(curb[0],2),round(terrain(*curb),3),round(curb[1],2)],'tangent':[round(dx,5),0,round(dz,5)],'color':colors[idx],'zone':zone,'street':edge['name'],'width':edge['width']})
spawn=stops[0]['position'][:];t=stops[0]['tangent'];spawn=[spawn[0]-t[0]*14,spawn[1],spawn[2]-t[2]*14];spawn[0]-=t[2]*5.5;spawn[2]+=t[0]*5.5;spawn[1]=terrain(spawn[0],spawn[2])
output={'curb_lines':curb_lines,'tram_route':tram_path,'source':'OpenStreetMap contributors, ODbL 1.0; downloaded 2026-11-14','projection':{'origin':ORIGIN,'scale':SCALE,'x_m_per_deg':XMET,'z_m_per_deg':ZMET},'bounds':list(BOUNDS),'nodes':verts3,'edges':edges,'buildings':buildings,'landmarks':landmarks,'coast':shore,'coastlines':coastlines,'flyovers':flyovers,'pedestrian':pedestrian,'stops':stops,'spawn':spawn,'spawn_heading':math.atan2(-t[0],-t[2]),'terrain':{'x':gx,'z':gz,'heights':grid,'attribution':'Copernicus DEM GLO-90 via Open-Meteo; smoothed and grade-limited for gameplay'}}
(ROOT/'assets/map_data/district.json').write_text(json.dumps(output,separators=(',',':')))
print('Map:',len(verts3),'nodes,',len(edges),'edges,',len(buildings),'building footprints,',len(flyovers),'flyover pieces')
print('Disconnected components:',sorted([len(c) for c in components],reverse=True)[:10])
print('Road length:',round(sum(math.dist(e['a'],e['b']) for e in edges)), 'm')
print('Stops:')
for i,s in enumerate(stops):print(i,s['name'],s['street'],s['position'])
# A source-derived geographic atlas: real footprint locations and drivable network.
W,H=1680,1100;im=Image.new('RGB',(W,H),'#142d3c');d=ImageDraw.Draw(im)
fontpath='/System/Library/Fonts/Supplemental/Arial.ttf'
try:font=ImageFont.truetype(fontpath,20);small=ImageFont.truetype(fontpath,16);title=ImageFont.truetype(fontpath,36)
except:font=small=title=ImageFont.load_default()
def pix(p):return (int(50+(p[0]+560)/1120*(W-100)),int(125+(p[1]+330)/660*(H-200)))
d.text((50,30),'HONG KONG BUS / GEOGRAPHIC REFERENCE ATLAS',fill='#ffe4a5',font=title)
d.text((50,78),'Sheung Wan → western Central   |   OSM street & building geometry   |   1,120 × 660 game metres',fill='#b5d7da',font=font)
for b in buildings:d.polygon([pix(p) for p in b['points']],fill='#687777' if b['style']=='tenement' else '#6a919e')
for e in edges:d.line([pix((e['a'][0],e['a'][2])),pix((e['b'][0],e['b'][2]))],fill='#e2ad62' if e['tram'] else '#9bb0ac',width=max(2,int(e['width']*.45)))
d.line([pix(p) for p in shore],fill='#55c9d4',width=4)
for i,s in enumerate(stops):
 x,y=pix((s['position'][0],s['position'][2]));d.ellipse((x-13,y-13,x+13,y+13),fill='#'+s['color']);d.text((x-6,y-10),str(i+1),fill='#102d36',font=small)
 d.text((x+17,y-11),s['short'],fill='#fff0ca',font=small,stroke_width=2,stroke_fill='#142d3c')
d.text((50,H-45),'© OpenStreetMap contributors • ODbL 1.0. Terrain: Copernicus DEM via Open-Meteo. Game streets widened and simplified; not navigation data.',fill='#b5d7da',font=small)
(ROOT/'docs/map').mkdir(parents=True,exist_ok=True);im.save(ROOT/'docs/map/geographic_atlas.png')
