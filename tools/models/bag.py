"""Plastic bag: very low-poly crumpled sheet (~11 tris), flat shaded, one material, two splayed handle ears.
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
# Flat crumpled sheet: 7-vertex outline near the ground, 2 raised interior verts, 2 splayed handle ears at +X.
# Blender XY plane (Z up in Blender -> Y up in glTF), ~0.6 x 0.44.
V = bm.verts.new
ring = [V(p) for p in [(0.22, 0.0, 0.015), (0.14, 0.17, 0.025), (-0.12, 0.22, 0.012), (-0.30, 0.08, 0.04),
                       (-0.27, -0.12, 0.012), (-0.02, -0.21, 0.03), (0.17, -0.16, 0.012)]]
c1 = V((-0.06, 0.05, 0.045)); c2 = V((0.08, -0.06, 0.03))
# 7 outline verts + 2 centres: fan-ish, 12 tris; use a ring of triangles to c1/c2
tris = [(0, 1, 7), (1, 2, 7), (2, 3, 7), (3, 4, 7), (4, 5, 8), (5, 6, 8), (6, 0, 8), (0, 7, 8), (4, 8, 7)]
allv = ring + [c1, c2]
for t in tris:
    bm.faces.new([allv[i] for i in t])
# two ears: flat tapered triangles lying splayed on the sand at the +X end
for s_ in (-1, 1):
    a = V((0.17, s_ * 0.03, 0.02)); b = V((0.21, s_ * 0.10, 0.025))
    tip = V((0.40, s_ * 0.20, 0.02))
    bm.faces.new((a, tip, b) if s_ > 0 else (a, b, tip))
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
