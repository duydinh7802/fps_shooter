# ============================================================
# TURN BATCH: Bước 18.2 (README) tự động cho nhiều clip turn
# ============================================================
# Cho mỗi file .blend (đã qua mixamo_batch_import.py, CHƯA xử lý xoay):
#   1) Tạo Empty "TurnYaw" và key góc Spine (quanh trục đứng) ở từng frame.
#      Không dùng Copy Rotation chỉ-Z: với clip ngồi (Spine cúi), Euler bị lật 180° ở clip 180°.
#   2) make_turn_in_place.process(): xoay ngược Hips quanh 3D Cursor → Spine đứng yên.
#   3) Xoá dần phần hông còn trôi ngang (clip turn crouch bước lệch 25–40 cm), để cuối clip
#      nhân vật về đúng chỗ ban đầu → không bị giật khi chuyển về idle.
# Lưu ra <thư mục đầu ra>/<tên file>.blend. Sau đó Godot import + tools/godot/bake_turn_curves.gd.
#
# Cách chạy (PowerShell, tại thư mục project):
#   & $blender -b --python tools\blender\turn_batch.py -- <thư mục đầu ra> a.blend b.blend ...
import bpy
import math
import os
import sys

from mathutils import Matrix, Vector

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_turn_in_place.py")
UP = Vector((0.0, 0.0, 1.0))

# Dùng lại các hàm của make_turn_in_place.py (bỏ lệnh main() ở cuối file)
_ns = {"__name__": "make_turn_in_place"}
exec(compile(open(TOOL, encoding="utf-8").read().replace("\nmain()\n", "\n"), TOOL, "exec"), _ns)


def process_file(path, out_dir):
    bpy.ops.wm.open_mainfile(filepath=path)
    name = os.path.splitext(os.path.basename(path))[0]
    scene = bpy.context.scene
    armature = _ns["get_armature"]()
    f0, f1 = (int(round(x)) for x in armature.animation_data.action.frame_range)
    hips = armature.pose.bones["Hips"]
    spine = armature.pose.bones["Spine"]

    # 1) TurnYaw = góc Spine từng frame (cộng dồn, không nhảy dấu)
    angles = _ns["measure"](armature, spine, UP, f0, f1)
    scene.frame_set(f0)
    start = _ns["bone_yaw"](armature, spine, UP)
    yaw = bpy.data.objects.new("TurnYaw", None)
    scene.collection.objects.link(yaw)
    for i, frame in enumerate(range(f0, f1 + 1)):
        yaw.rotation_euler = (0.0, 0.0, start + angles[i])
        yaw.keyframe_insert("rotation_euler", index=2, frame=frame)
    yaw.animation_data.action.name = name + "_yaw"

    # 2) Xoá xoay Spine khỏi clip
    bpy.context.view_layer.objects.active = armature
    if not _ns["process"](armature):
        return

    # 3) Xoá dần phần trôi ngang còn lại của Hips
    def hips_world(frame):
        scene.frame_set(frame)
        return (armature.matrix_world @ hips.matrix).copy()
    p0, p1 = hips_world(f0).translation, hips_world(f1).translation
    drift = Vector((p1.x - p0.x, p1.y - p0.y, 0.0))
    to_armature = armature.matrix_world.inverted_safe()
    for frame in range(f0, f1 + 1):
        shift = Matrix.Translation(-drift * (frame - f0) / (f1 - f0))
        hips.matrix = to_armature @ (shift @ hips_world(frame))
        bpy.context.view_layer.update()
        hips.keyframe_insert("location", frame=frame, group=hips.name)

    print(f"    TurnYaw {math.degrees(angles[-1]):+.1f}°, đã xoá hông trôi {drift.length * 100:.0f} cm")
    scene.frame_set(f0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, name + ".blend"))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(args) < 2:
    raise SystemExit("Cần: <thư mục đầu ra> a.blend b.blend ...")
os.makedirs(args[0], exist_ok=True)
for file in args[1:]:
    process_file(os.path.abspath(file), os.path.abspath(args[0]))
