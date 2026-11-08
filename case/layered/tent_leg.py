"""Fold-flat tenting leg for the layered Chocofi case (one fixed angle).

Run inside Blender after build_case.py is available:
    exec(compile(open(path).read(), path, 'exec'), {'__name__': '__main__'})

A U-shaped bracket screws under the inner edge with the two inner-edge case screws
(swap them for M2x14). Bosses on the bracket sit in the screw-head recesses so it
locates. No pin: the leg has printed axle stubs that drop into U-slots in the bracket,
open toward the case. Screwing the bracket on closes the slots, trapping the axles.
Opened, a square tail on the leg hits the case floor at 90 degrees, so typing load
pushes it into that stop instead of folding it.
"""
import math, bmesh, bpy
from mathutils import Matrix

HERE = '/Users/siah/Dev/chocofi/case/layered/'
_g = {'__name__': 'case'}
exec(compile(open(HERE + 'build_case.py').read(), HERE + 'build_case.py', 'exec'), _g)
prism_mesh, circle, box, write_stl, check, mirrored, rect = (_g[k] for k in
    ('prism_mesh', 'circle', 'box', 'write_stl', 'check', 'mirrored', 'rect'))
SCREWS = _g['SCREWS']

TENT_DEG = 10.0
T = 3.5                                   # leg thickness (z -T..0 under the floor, folded)
LEG_Y = (-7.0, 29.0)                      # leg width
GAP = 0.4                                 # clearance around the leg
AXLE_R, AXLE_LEN, SLOT_GAP = 1.2, 3.0, 0.15  # printed axle stubs on the leg, slots in the bracket
AXIS_X, AXIS_Z = 56.0, -T + AXLE_R        # hinge axis along y; axles touch the bed so the leg prints without supports
RK = -AXIS_Z                              # knuckle radius: the leg's round end just clears the case floor
BR_T = T + 0.6                            # bracket is a bit thicker so the slot keeps a floor under the axle
BR_X, BR_Y = (27.0, 59.2), (-19.0, 39.0)  # bracket footprint
R_HOLE, R_CBORE = 1.15, 2.2
CBORE_D = BR_T - 1.5                      # head sits 1.5 mm below the floor, so an M2x14 still bites ~2.7 mm
R_BOSS, BOSS_H = 2.05, 2.8                # fits the 4.4 x 3 mm head recess in the floor
# case pivots on its outer feet (~x -58); leg length so the inner edge rises to TENT_DEG
LEG_LEN = (AXIS_X + 58.0) * math.tan(math.radians(TENT_DEG)) + (AXIS_Z + BR_T)
INNER = [p for p in SCREWS if p[0] > 50]   # the two inner-edge screws

def xz_prism(name, loop, y0, y1):
    """Polygon in (x, z), extruded along y."""
    me = prism_mesh(name, [loop], y0, y1)                 # built as (x, y=z, z=y)
    bm = bmesh.new(); bm.from_mesh(me)
    bm.transform(Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free(); return me

def boolean(name, base, adds=(), cuts=()):
    sc = bpy.context.scene.collection
    objs = []
    def ob(me):
        o = bpy.data.objects.new('_b', me); sc.objects.link(o); objs.append(o); return o
    b = ob(base)
    for op, items in (('UNION', adds), ('DIFFERENCE', cuts)):
        for me in items:
            m = b.modifiers.new(op, 'BOOLEAN'); m.operation = op; m.solver = 'EXACT'; m.object = ob(me)
            ob_ = m.object; ob_.hide_viewport = True
    bpy.context.view_layer.update()
    out = bpy.data.meshes.new_from_object(b.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    for o in objs:
        d = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(d)
    bm = bmesh.new(); bm.from_mesh(out)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts[:], edges=bm.edges[:])
    bm.to_mesh(out); bm.free(); out.name = name
    return out

def pin_hole(y0, y1, r):
    return xz_prism('_pin', circle(AXIS_X, AXIS_Z, r, 32), y0, y1)

def make_bracket():
    base = prism_mesh('_br', [rect((BR_X[0]+BR_X[1])/2, (BR_Y[0]+BR_Y[1])/2, BR_X[1]-BR_X[0], BR_Y[1]-BR_Y[0], 0, 4.0)], -BR_T, 0)
    bosses = [prism_mesh('_boss', [circle(*p, R_BOSS)], -0.2, BOSS_H) for p in INNER]
    # window for the folded leg, open toward the inner edge; leaves the outer bar and two arms
    win = prism_mesh('_win', [box(AXIS_X - LEG_LEN - GAP - 0.2, BR_X[1] + 1, LEG_Y[0] - GAP, LEG_Y[1] + GAP)], -BR_T - 1, 1)
    finger = prism_mesh('_fn', [circle(AXIS_X - LEG_LEN - GAP - 0.2, sum(LEG_Y) / 2, 4.0)], -BR_T - 1, 1)   # finger notch to flick the leg out
    # U-slots for the axles, open at the top (z = 0) so the case floor closes them
    r = AXLE_R + SLOT_GAP
    y0, y1 = LEG_Y[0] - GAP - AXLE_LEN - 0.3, LEG_Y[1] + GAP + AXLE_LEN + 0.3
    slot = [(AXIS_X + r * math.cos(a), AXIS_Z + r * math.sin(a)) for a in [math.pi + math.pi * i / 16 for i in range(17)]]
    slot += [(AXIS_X + r, 1.0), (AXIS_X - r, 1.0)]
    cuts = [win, finger, xz_prism('_slot', slot, y0, y1)]
    for p in INNER:
        cuts += [prism_mesh('_h', [circle(*p, R_HOLE)], -BR_T - 1, BOSS_H + 1),
                 prism_mesh('_c', [circle(*p, R_CBORE)], -BR_T - 1, -BR_T + CBORE_D)]
    return boolean('tent_bracket', base, bosses, cuts)

def make_leg():
    t = math.tan(math.radians(TENT_DEG))
    x_tip = AXIS_X - LEG_LEN
    # folded profile: flat leg, round knuckle (radius RK) over the hinge, square heel below it.
    # Opening 90 degrees swings the heel corner up to exactly the case floor: that is the stop.
    prof = [(x_tip - T * t / 2, -T), (AXIS_X + RK, -T), (AXIS_X + RK, AXIS_Z)]
    prof += [(AXIS_X + RK * math.cos(a), AXIS_Z + RK * math.sin(a)) for a in [math.pi/2 * i / 12 for i in range(1, 13)]]
    prof += [(x_tip + T * t / 2, 0.0)]
    leg = xz_prism('_leg', prof, LEG_Y[0], LEG_Y[1])
    axles = [pin_hole(LEG_Y[0] - GAP - AXLE_LEN, LEG_Y[0] + 1, AXLE_R),
             pin_hole(LEG_Y[1] - 1, LEG_Y[1] + GAP + AXLE_LEN, AXLE_R)]
    return boolean('tent_leg', leg, axles, ())

def opened(me, name):
    """Leg rotated to its open stop (90 degrees about the hinge axis)."""
    out = me.copy(); out.name = name
    M = Matrix.Translation((AXIS_X, 0, AXIS_Z)) @ Matrix.Rotation(math.radians(-90), 4, 'Y') @ Matrix.Translation((-AXIS_X, 0, -AXIS_Z))
    out.transform(M); return out

def install():
    parts = {'bracket': make_bracket(), 'leg': make_leg()}
    write_stl(parts['bracket'], HERE + 'left_tent_bracket.stl', flip=False)
    write_stl(parts['bracket'], HERE + 'right_tent_bracket.stl', mirror=True, flip=False)
    # leg prints flat on its wide face
    write_stl(parts['leg'], HERE + 'tent_leg.stl', flip=False)
    return parts

if __name__ == '__main__':
    p = install()
    print({k: check(v) for k, v in p.items()}, 'leg length', round(LEG_LEN, 2), 'screws', INNER)
