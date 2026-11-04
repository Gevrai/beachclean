"""Plastic bag: crumpled, flattened low-poly (~56 tris), flat shaded, one material, handle loops.
Run: blender -b -P tools/models/bag.py   -> assets/models/items/bag.glb
Units match the old primitive bag (Model-space, before the prefab's 0.6 scale): ~0.6 x 0.44 x 0.1, Y up in Godot.
"""
import math, os, random
import bpy, bmesh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "items", "bag.glb")
rng = random.Random(7)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

bm = bmesh.new()
NX, NY = 5, 4  # vertex grid -> 4x3 quads per side
W, D = 0.6, 0.44
top, bot = [], []
for j in range(NY):
    rt, rb = [], []
    for i in range(NX):
        u, v = i / (NX - 1) - 0.5, j / (NY - 1) - 0.5
        # rounded outline: pull corners in
        k = 1.0 - 0.25 * (abs(u) * 2) ** 2 * (abs(v) * 2) ** 2
        x, y = u * W * k + rng.uniform(-0.03, 0.03), v * D * k + rng.uniform(-0.03, 0.03)
        edge = i in (0, NX - 1) or j in (0, NY - 1)
        h = 0.0 if edge else 0.05 + rng.uniform(0.0, 0.06)
        rt.append(bm.verts.new((x, y, 0.012 + h)))
        rb.append(bm.verts.new((x, y, 0.012)) if not edge else rt[-1])
    top.append(rt)
    bot.append(rb)
for j in range(NY - 1):
    for i in range(NX - 1):
        bm.faces.new((top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i]))
        q = (bot[j][i], bot[j + 1][i], bot[j + 1][i + 1], bot[j][i + 1])
        if len(set(q)) == 4 or True:
            try:
                bm.faces.new(q)
            except ValueError:
                pass
# two handle loops at the +X end: a bent strip of 2 quads each
for s in (-1, 1):
    y0 = s * 0.09
    a = bm.verts.new((0.25, y0 - 0.03, 0.05))
    b = bm.verts.new((0.25, y0 + 0.03, 0.05))
    c = bm.verts.new((0.36, y0 - 0.02, 0.13))
    d = bm.verts.new((0.36, y0 + 0.04, 0.12))
    e = bm.verts.new((0.44, y0 - 0.01, 0.04))
    f = bm.verts.new((0.44, y0 + 0.05, 0.04))
    bm.faces.new((a, c, d, b))
    bm.faces.new((c, e, f, d))
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
me = bpy.data.meshes.new("Bag")
bm.to_mesh(me)
print("TRIS", len(me.polygons))
for p in me.polygons:
    p.use_smooth = False
ob = bpy.data.objects.new("Bag", me)
bpy.context.scene.collection.objects.link(ob)
mat = bpy.data.materials.new("bag")
me.materials.append(mat)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", use_selection=True, export_apply=True)
