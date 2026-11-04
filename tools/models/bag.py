"""Plastic bag: very low-poly T-shirt bag lying flat (13 tris), flat shaded, one material.
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
# T-shirt shopping bag lying almost flat: rectangle body, U-notch with two straps at +X, centre ridge, one folded corner.
V = bm.verts.new
P = [(-0.30, -0.20, 0.01), (-0.30, 0.20, 0.01), (0.08, 0.21, 0.01), (0.30, 0.18, 0.015), (0.30, 0.09, 0.015),
     (0.14, 0.08, 0.01), (0.14, -0.08, 0.01), (0.30, -0.09, 0.015), (0.30, -0.18, 0.015), (0.08, -0.21, 0.01),
     (-0.10, 0.0, 0.06), (0.10, 0.0, 0.04),
     (-0.22, -0.14, 0.07), (-0.30, -0.08, 0.012), (-0.14, -0.20, 0.012)]
v = [V(p) for p in P]
T = [(0, 1, 10), (1, 2, 10), (2, 11, 10), (2, 3, 4), (2, 4, 5), (2, 5, 11), (5, 6, 11), (6, 9, 11), (9, 10, 11), (9, 0, 10),
     (9, 8, 7), (9, 7, 6), (12, 13, 14)]
for t in T:
    bm.faces.new([v[i] for i in t])
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
