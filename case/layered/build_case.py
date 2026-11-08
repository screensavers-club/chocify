"""Chocofi three-layer case: bottom -> plate -> top.

Run inside Blender (units: mm, scale_length 0.001):
    exec(compile(open(path).read(), path, 'exec'), {'__name__': '__main__'})

Everything comes from one 2D outline, so change a value below and rerun.
inputs.json holds what carries over: switch positions, cap openings, Pro Micro.
Alignment: pegs on the bottom and top layers meet in shared through holes in the
plate. No tongues or grooves, so every layer has flat faces. Print the bottom
floor down, and the plate and top with their top faces on the bed.
"""
import json, math, os
import bpy, bmesh
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

HERE = '/Users/siah/Dev/chocofi/case/layered/'
DATA = json.load(open(HERE + 'inputs.json'))

# --- heights (world z)
Z_FLOOR, Z_SEAM1, Z_SEAM2, Z_TOP = 1.0, 7.6, 9.8, 15.4
# --- footprint: GROW is added to the v1 outline, WALL is measured from the new edge
GROW, WALL = 2.0, 4.3
R_CONVEX, R_REFLEX = 5.0, 1.0        # vertical corner radii of the outer edge
# --- pegs: one from the bottom and one from the top in each plate hole, 0.2 mm apart
N_PEGS, PEG_D, R_PEG, R_PEG_HOLE, PEG_H, R_PEG_BASE = 4, 3.4, 1.0, 1.15, 1.0, 1.6
# --- switches
HOLE, POCKET_X, POCKET_Y, LEDGE = 13.9, 15.4, 12.9, 1.2
# --- screws: M2x10 from underneath
SCREW_D = 3.0                        # distance in from the outer edge
R_THROUGH, R_HEAD, HEAD_Z, R_PILOT, PILOT_TOP, R_POST = 1.15, 2.2, 3.0, 0.85, 14.0, 2.9
N_SCREWS = 10
# --- openings and supports
USB_X, USB_Z = (39.92, 51.92), (1.95, 8.45)
CABLE_Y, CABLE_Z, CABLE_R = -8.0, 5.6, 2.0
STRAIN = (51.0, -11.0, 1.75, 6.0)    # x, y, r, top z
RESTS = [(-37.6, 5.2), (-37.6, 22.2), (16.4, 19.2), (34.4, -21.3), (-8.6, -15.1)]

# v1 outline with sharp corners, measured from the original STL
def _isect(a, b, c, d):
    den = (b[0]-a[0])*(d[1]-c[1]) - (b[1]-a[1])*(d[0]-c[0])
    t = ((c[0]-a[0])*(d[1]-c[1]) - (c[1]-a[1])*(d[0]-c[0])) / den
    return (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t)
BASE = [(-35.2,-26.35), (-35.2,-14.44), (-21.03,-14.44), (-8.79,-34.83), (10.21,-34.83), (26.88,-39.38),
        _isect((58.23,-23.68),(45.24,-46.25),(40.62,-47.31),(26.88,-39.38)),
        (58.23,-23.68), (58.23,38.57), (18.74,38.57), (18.74,41.05), (0.82,41.05), (0.82,47.56),
        (-22.15,47.56), (-22.15,41.62), (-40.15,41.62), (-40.15,29.63), (-58.23,29.63), (-58.23,-26.35)]

# --- 2D helpers
def sarea(P): return 0.5*sum(P[i][0]*P[(i+1)%len(P)][1]-P[(i+1)%len(P)][0]*P[i][1] for i in range(len(P)))
def ccw(P): return list(P) if sarea(P) > 0 else list(P)[::-1]
def offset_sharp(P, s):
    """Mitred offset of a CCW polygon, s > 0 grows it."""
    n, out = len(P), []
    for i in range(n):
        a, b, c = P[i-1], P[i], P[(i+1)%n]
        def shifted(p, q):
            dx, dy = q[0]-p[0], q[1]-p[1]; L = math.hypot(dx, dy)
            nx, ny = dy/L*s, -dx/L*s
            return (p[0]+nx, p[1]+ny), (q[0]+nx, q[1]+ny)
        out.append(_isect(*shifted(a, b), *shifted(b, c)))
    return out
def fillet(P, r_of):
    """Round every corner. r_of(is_convex) gives the radius; clamped to half of each edge."""
    n, out = len(P), []
    for i in range(n):
        p0, p1, p2 = P[i-1], P[i], P[(i+1)%n]
        L1, L2 = math.dist(p0, p1), math.dist(p1, p2)
        d1 = ((p0[0]-p1[0])/L1, (p0[1]-p1[1])/L1); d2 = ((p2[0]-p1[0])/L2, (p2[1]-p1[1])/L2)
        cross = (p1[0]-p0[0])*(p2[1]-p1[1])-(p1[1]-p0[1])*(p2[0]-p1[0])
        th = math.acos(max(-1, min(1, d1[0]*d2[0]+d1[1]*d2[1])))
        r = max(0.3, r_of(cross > 0))
        t = min(r/math.tan(th/2), 0.48*L1, 0.48*L2); r = t*math.tan(th/2)
        a = (p1[0]+d1[0]*t, p1[1]+d1[1]*t); b = (p1[0]+d2[0]*t, p1[1]+d2[1]*t)
        bx, by = d1[0]+d2[0], d1[1]+d2[1]; bl = math.hypot(bx, by); h = r/math.sin(th/2)
        c = (p1[0]+bx/bl*h, p1[1]+by/bl*h)
        a0 = math.atan2(a[1]-c[1], a[0]-c[0]); a1 = math.atan2(b[1]-c[1], b[0]-c[0])
        da = (a1-a0+math.pi) % (2*math.pi) - math.pi
        k = max(2, int(abs(math.degrees(da))/10))
        out += [(c[0]+r*math.cos(a0+da*j/k), c[1]+r*math.sin(a0+da*j/k)) for j in range(k+1)]
    return out
def inset(d):
    """Outline d mm in from the new outer edge, corners concentric with it."""
    return fillet(offset_sharp(ccw(BASE), GROW-d), lambda convex: R_CONVEX-d if convex else R_REFLEX+d)
def circle(x, y, r, n=None):
    n = n or max(24, int(r*16))
    return [(x+r*math.cos(2*math.pi*i/n), y+r*math.sin(2*math.pi*i/n)) for i in range(n)]
def rect(cx, cy, w, h, rot=0.0, r=0.0):
    a = math.radians(rot); u, v = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
    pts = [(cx+u[0]*x+v[0]*y, cy+u[1]*x+v[1]*y) for x, y in ((-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2))]
    return fillet(pts, lambda c: r) if r else pts
def box(x0, x1, y0, y1): return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
def seg_dist(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy or 1e-12)))
    return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)
def loop_dist(p, L): return min(seg_dist(p, L[i], L[(i+1)%len(L)]) for i in range(len(L)))
def rect_dist(p, cx, cy, w, h, rot=0.0):
    a = math.radians(rot); dx, dy = p[0]-cx, p[1]-cy
    x, y = dx*math.cos(a)+dy*math.sin(a), -dx*math.sin(a)+dy*math.cos(a)
    return math.hypot(max(abs(x)-w/2, 0), max(abs(y)-h/2, 0))

# --- 3D helpers
def prism_mesh(name, loops, z0, z1, axis_x=False):
    """loops[0] is the outline, the rest are holes. axis_x maps (u,v,w) -> (w,u,v)."""
    loops = [ccw(loops[0])] + [ccw(h)[::-1] for h in loops[1:]]
    flat = [p for L in loops for p in L]; n = len(flat)
    tris = tessellate_polygon([[Vector((p[0], p[1], 0)) for p in L] for L in loops])
    def co(p, z): return (z, p[0], p[1]) if axis_x else (p[0], p[1], z)
    verts = [co(p, z0) for p in flat] + [co(p, z1) for p in flat]
    faces = []
    for a, b, c in tris:
        if (flat[b][0]-flat[a][0])*(flat[c][1]-flat[a][1])-(flat[b][1]-flat[a][1])*(flat[c][0]-flat[a][0]) < 0: b, c = c, b
        faces += [(a+n, b+n, c+n), (c, b, a)]
    k = 0
    for L in loops:
        m = len(L)
        for i in range(m):
            j = (i+1) % m
            faces.append((k+i, k+j, k+j+n, k+i+n))
        k += m
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    return me

def solid(name, adds, cuts):
    """adds/cuts are lists of (loops, z0, z1[, axis_x]). Returns a new clean mesh."""
    scene = bpy.context.scene
    tmp = bpy.data.collections.new('_tmp_' + name); scene.collection.children.link(tmp)
    colls, objs = [], []
    def group(tag, items):
        c = bpy.data.collections.new('_tmp_%s_%s' % (name, tag)); tmp.children.link(c); colls.append(c)
        for i, it in enumerate(items):
            o = bpy.data.objects.new('_t', prism_mesh('_t', *it)); c.objects.link(o); objs.append(o)
        return c
    base = bpy.data.objects.new('_base', prism_mesh('_base', *adds[0])); tmp.objects.link(base); objs.append(base)
    if len(adds) > 1:
        m = base.modifiers.new('u', 'BOOLEAN'); m.operation = 'UNION'; m.solver = 'EXACT'
        m.operand_type = 'COLLECTION'; m.collection = group('add', adds[1:])
    if cuts:
        m = base.modifiers.new('d', 'BOOLEAN'); m.operation = 'DIFFERENCE'; m.solver = 'EXACT'
        m.operand_type = 'COLLECTION'; m.collection = group('cut', cuts)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(base.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    for o in objs:
        d = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(d)
    for c in colls: bpy.data.collections.remove(c)
    bpy.data.collections.remove(tmp)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts[:], edges=bm.edges[:], delimit=set())
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.to_mesh(me); bm.free()
    me.name = name
    return me

# --- layout
OUTER, CAVITY = inset(0), inset(WALL)
SW = DATA['switches']; PM = DATA['pro_micro']; OPENINGS = DATA['openings']

def pick_screws():
    path = inset(SCREW_D); cands = []
    for i in range(len(path)):
        a, b = path[i], path[(i+1) % len(path)]
        for j in range(max(1, int(math.dist(a, b)/0.5))):
            t = j/max(1, int(math.dist(a, b)/0.5)); cands.append((a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t))
    def ok(p):
        if min(rect_dist(p, *s['c'], 14.0, 14.0, s['rot']) for s in SW.values()) < R_POST+0.3: return False
        if rect_dist(p, PM[0], PM[1], 18.2, 33.2) < R_POST+0.5: return False
        if min(loop_dist(p, L) for L in OPENINGS) < R_PILOT+0.55: return False
        if USB_X[0]-R_POST-1 < p[0] < USB_X[1]+R_POST+1 and p[1] > 30: return False
        if p[0] > 45 and abs(p[1]-CABLE_Y) < CABLE_R+R_POST+1: return False
        if math.dist(p, STRAIN[:2]) < R_POST+STRAIN[2]+1.5: return False
        return True
    good = [p for p in cands if ok(p)]
    if not good: raise RuntimeError('no screw spot clears the switches')
    # farthest-point spread, starting from the corner farthest from the centre
    chosen = [max(good, key=lambda p: math.hypot(*p))]
    while len(chosen) < N_SCREWS:
        chosen.append(max(good, key=lambda p: min(math.dist(p, q) for q in chosen)))
    return [(round(x, 2), round(y, 2)) for x, y in chosen], len(good)

SCREWS, n_good = pick_screws()

def pick_pegs():
    path = inset(PEG_D); cands = []
    for i in range(len(path)):
        a, b = path[i], path[(i+1) % len(path)]
        k = max(1, int(math.dist(a, b)/0.5))
        cands += [(a[0]+(b[0]-a[0])*j/k, a[1]+(b[1]-a[1])*j/k) for j in range(k)]
    def ok(p):
        if min(rect_dist(p, *s['c'], 14.0, 14.0, s['rot']) for s in SW.values()) < R_PEG_BASE+0.3: return False
        if min(rect_dist(p, *s['c'], POCKET_X, POCKET_Y, s['rot']) for s in SW.values()) < R_PEG_HOLE+0.8: return False
        if min(math.dist(p, q) for q in SCREWS) < R_POST+R_PEG_BASE+0.5: return False
        if rect_dist(p, PM[0], PM[1], 18.2, 33.2) < R_PEG_BASE+0.5: return False
        if min(loop_dist(p, L) for L in OPENINGS) < R_PEG_HOLE+0.15: return False   # stays hidden under the top
        if USB_X[0]-3 < p[0] < USB_X[1]+3 and p[1] > 30: return False
        if p[0] > 45 and abs(p[1]-CABLE_Y) < CABLE_R+3: return False
        return True
    good = [p for p in cands if ok(p)]
    if len(good) < N_PEGS: raise RuntimeError('not enough peg spots')
    chosen = [max(good, key=lambda p: math.hypot(*p))]
    while len(chosen) < N_PEGS:
        chosen.append(max(good, key=lambda p: min(math.dist(p, q) for q in chosen)))
    return [(round(x, 2), round(y, 2)) for x, y in chosen]

PEGS = pick_pegs()

def rests():
    out = []
    for p in RESTS:
        cl = min(rect_dist(p, *s['c'], HOLE, HOLE, s['rot']) for s in SW.values())
        r = min(2.0, cl-0.25)
        if r >= 1.2 and rect_dist(p, PM[0], PM[1], 18.2, 33.2) > r+0.5: out.append((p[0], p[1], round(r, 2)))
    return out
RESTS_USED = rests()

def make_bottom():
    adds = [([OUTER], 0, Z_FLOOR), ([OUTER, CAVITY], 0.5, Z_SEAM1),
            ([circle(STRAIN[0], STRAIN[1], STRAIN[2])], 0.5, STRAIN[3])]
    adds += [([circle(*p, R_POST)], 0.5, Z_SEAM1) for p in SCREWS]
    adds += [([circle(x, y, r)], 0.5, Z_SEAM1) for x, y, r in RESTS_USED]
    adds += [([circle(*p, R_PEG_BASE)], 0.5, Z_SEAM1) for p in PEGS]
    adds += [([circle(*p, R_PEG)], Z_SEAM1-0.3, Z_SEAM1+PEG_H) for p in PEGS]
    u = [(CABLE_Y+CABLE_R*math.cos(a), CABLE_Z+CABLE_R*math.sin(a)) for a in [math.pi+math.pi*i/24 for i in range(25)]]
    u += [(CABLE_Y+CABLE_R, Z_SEAM1+3), (CABLE_Y-CABLE_R, Z_SEAM1+3)]
    cuts = []
    for p in SCREWS:
        cuts += [([circle(*p, R_THROUGH)], -1, Z_SEAM1+3), ([circle(*p, R_HEAD)], -1, HEAD_Z)]
    cuts.append(([box(USB_X[0], USB_X[1], 35, 50)], USB_Z[0], Z_SEAM1+3))
    cuts.append(([u], 54.5, 70, True))
    return solid('layer_bottom', adds, cuts)

def make_plate():
    cuts = []
    for s in SW.values():
        cuts.append(([rect(*s['c'], HOLE, HOLE, s['rot'], 0.5)], Z_SEAM1-1, Z_SEAM2+1))
        cuts.append(([rect(*s['c'], POCKET_X, POCKET_Y, s['rot'])], Z_SEAM1-1, Z_SEAM2-LEDGE))
    cuts += [([circle(*p, R_THROUGH)], Z_SEAM1-1, Z_SEAM2+1) for p in SCREWS]
    cuts += [([circle(*p, R_PEG_HOLE)], Z_SEAM1-1, Z_SEAM2+1) for p in PEGS]
    cuts.append(([box(USB_X[0], USB_X[1], 35, 50)], Z_SEAM1-1, USB_Z[1]))
    return solid('layer_plate', [([OUTER], Z_SEAM1, Z_SEAM2)], cuts)

def make_top():
    adds = [([OUTER], Z_SEAM2, Z_TOP)] + [([circle(*p, R_PEG)], Z_SEAM2-PEG_H, Z_SEAM2+0.3) for p in PEGS]
    cuts = [([L], Z_SEAM2-2, Z_TOP+1) for L in OPENINGS]
    cuts += [([circle(*p, R_PILOT)], Z_SEAM2-2, PILOT_TOP) for p in SCREWS]
    return solid('layer_top', adds, cuts)

def check(me):
    bm = bmesh.new(); bm.from_mesh(me)
    bad = sum(1 for e in bm.edges if not e.is_manifold)
    seen, shells = set(), 0
    for v in bm.verts:
        if v.index in seen: continue
        shells += 1; st = [v]
        while st:
            k = st.pop()
            if k.index in seen: continue
            seen.add(k.index); st += [e.other_vert(k) for e in k.link_edges]
    vol = bm.calc_volume(signed=True); zs = [v.co.z for v in bm.verts]; xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]
    tris = sum(len(f.verts)-2 for f in bm.faces); bm.free()
    return dict(tris=tris, nonmanifold=bad, shells=shells, vol_cm3=round(vol/1000, 2),
                size=(round(max(xs)-min(xs), 2), round(max(ys)-min(ys), 2), round(max(zs)-min(zs), 2)), z=(round(min(zs), 3), round(max(zs), 3)))

def write_stl(me, path, mirror=False, flip=False):
    """flip = rotate 180 degrees about X so the layer's top face sits on the bed."""
    import struct
    me.calc_loop_triangles()
    co = [(-v.co.x if mirror else v.co.x, -v.co.y if flip else v.co.y, -v.co.z if flip else v.co.z) for v in me.vertices]
    zmin = min(c[2] for c in co)
    co = [(c[0], c[1], c[2]-zmin) for c in co]
    with open(path, 'wb') as f:
        f.write(b'chocofi layered case'.ljust(80, b' ')); f.write(struct.pack('<I', len(me.loop_triangles)))
        for t in me.loop_triangles:
            a, b, c = t.vertices
            if mirror: b, c = c, b
            A, B, C = Vector(co[a]), Vector(co[b]), Vector(co[c])
            f.write(struct.pack('<12fH', *(B-A).cross(C-A).normalized(), *A, *B, *C, 0))

def build():
    meshes = {'bottom': make_bottom(), 'plate': make_plate(), 'top': make_top()}
    return meshes

RIGHT_OFFSET_X = 135.0                # where the right half sits beside the left in Blender

def mirrored(me, name):
    """Copy of a mesh mirrored across X, with faces turned the right way out."""
    from mathutils import Matrix
    bm = bmesh.new(); bm.from_mesh(me)
    bm.transform(Matrix.Scale(-1, 4, (1, 0, 0)))
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    out = bpy.data.meshes.new(name); bm.to_mesh(out); bm.free()
    for m in me.materials: out.materials.append(m)
    return out

def install():
    """Rebuild the layers, swap them into every object using them, export print-ready STLs."""
    names = {'bottom': 'layer_bottom', 'plate': 'layer_plate', 'top': 'layer_top'}
    new = build()
    for k, me in new.items():
        old = bpy.data.meshes.get(names[k]) if bpy.data.meshes.get(names[k]) is not me else None
        ob = bpy.data.objects.get('layer ' + k)
        prev = ob.data if ob else old
        if prev is not None and prev is not me:
            mats = list(prev.materials)
            prev.user_remap(me)
            for m in mats: me.materials.append(m)
            bpy.data.meshes.remove(prev)
        me.name = names[k]
    # right half: a real mirrored mesh, shown beside the left half in the case collection
    coll = bpy.data.collections.get('1 Case - layered') or bpy.context.scene.collection
    for k, me in new.items():
        rm = mirrored(me, names[k] + '_right')
        ob = bpy.data.objects.get('layer %s (right)' % k)
        if ob is None:
            ob = bpy.data.objects.new('layer %s (right)' % k, rm); coll.objects.link(ob)
            ob.location = (RIGHT_OFFSET_X, 0, 0)
        else:
            prev = ob.data; ob.data = rm
            if prev.users == 0: bpy.data.meshes.remove(prev)
        rm.name = names[k] + '_right'
    out = {}
    for k, me in new.items():
        flip = k != 'bottom'             # plate and top print with their top face on the bed
        write_stl(me, HERE + 'left_%s.stl' % k, mirror=False, flip=flip)
        write_stl(me, HERE + 'right_%s.stl' % k, mirror=True, flip=flip)
        out[k] = check(me)
    return out

def export_peg_test(box_xy=(-61.0, -50.0, 15.5, 33.0), gap=6.0):
    """One STL with a real slice of all three layers, in print orientation, side by side.
    The default box holds one peg with its plate hole and one screw position."""
    from mathutils import Matrix
    x0, x1, y0, y1 = box_xy
    scene = bpy.context.scene
    cutter = bpy.data.objects.new('_box', prism_mesh('_box', [box(x0, x1, y0, y1)], -5, 25))
    scene.collection.objects.link(cutter)
    parts, report, cursor = [], {}, 0.0
    for k in ('bottom', 'plate', 'top'):
        t = bpy.data.objects.new('_i', bpy.data.objects['layer ' + k].data.copy())
        scene.collection.objects.link(t)
        m = t.modifiers.new('i', 'BOOLEAN'); m.operation = 'INTERSECT'; m.solver = 'EXACT'; m.object = cutter
        bpy.context.view_layer.update()
        me = bpy.data.meshes.new_from_object(t.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        d = t.data; bpy.data.objects.remove(t); bpy.data.meshes.remove(d)
        report[k] = check(me)
        if k != 'bottom': me.transform(Matrix.Rotation(math.pi, 4, 'X'))
        xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
        me.transform(Matrix.Translation((cursor-min(xs), -min(ys), -min(zs))))
        cursor += max(xs)-min(xs)+gap
        parts.append(me)
    d = cutter.data; bpy.data.objects.remove(cutter); bpy.data.meshes.remove(d)
    bm = bmesh.new()
    for me in parts: bm.from_mesh(me)
    out = bpy.data.meshes.new('_peg_test'); bm.to_mesh(out); bm.free()
    for me in parts: bpy.data.meshes.remove(me)
    write_stl(out, HERE + 'test_peg_and_hole.stl')
    report['combined'] = check(out)
    return report, out

if __name__ == '__main__':
    print(install()); print('screws', SCREWS)
