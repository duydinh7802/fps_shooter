# Mixamo batch import: chuẩn hoá hàng loạt file FBX tải từ Mixamo (Without Skin) thành .blend
# cho Godot import trực tiếp.
#
# Cho mỗi file .fbx trong thư mục đầu vào:
#   1. Import FBX (Automatic Bone Orientation tắt, Ignore Leaf Bones tắt)
#   2. Bỏ prefix tên bone ("mixamorig:Hips" → "Hips"); Blender tự cập nhật track animation
#   3. Đặt tên action = "mixamo.com", khung thời gian của scene = độ dài action
#   4. (tuỳ chọn --in-place) đo quãng đường hông trôi → in ra tốc độ m/s, rồi xoá phần trôi
#   5. Lưu ở Object Mode thành <thư mục đầu ra>/<tên file>.blend
#
# Cách chạy (PowerShell, tại thư mục project):
#   & $blender -b --python tools\blender\mixamo_batch_import.py -- <thư mục fbx> <thư mục .blend> [--in-place]
import bpy
import os
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) < 2:
    raise SystemExit("Cần 2 tham số: <thư mục fbx> <thư mục .blend> [--in-place]")
in_dir, out_dir = os.path.abspath(argv[0]), os.path.abspath(argv[1])
do_in_place = "--in-place" in argv
os.makedirs(out_dir, exist_ok=True)

ROOT_BONE = "Hips"


def all_fcurves(action):
    """F-Curve của action, hỗ trợ cả action kiểu cũ lẫn slotted action (Blender 4.4+)."""
    if hasattr(action, "layers") and action.layers:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    yield from bag.fcurves
    else:
        yield from action.fcurves


def hips_world(arm, frame):
    bpy.context.scene.frame_set(frame)
    return (arm.matrix_world @ arm.pose.bones[ROOT_BONE].matrix).translation.copy()


def make_in_place(arm, action, f0, f1):
    """Xoá phần trôi ngang của Hips (giữ nhún, lắc). Trả về quãng đường đã trôi (m)."""
    pb = arm.pose.bones[ROOT_BONE]
    p0, p1 = hips_world(arm, f0), hips_world(arm, f1)
    drift_world = Vector((p1.x - p0.x, p1.y - p0.y, 0.0))
    drift_arm = arm.matrix_world.inverted().to_3x3() @ drift_world
    drift_loc = pb.bone.matrix_local.to_3x3().inverted() @ drift_arm
    path = f'pose.bones["{ROOT_BONE}"].location'
    span = float(f1 - f0) or 1.0
    curves = [fc for fc in all_fcurves(action) if fc.data_path == path]
    for fc in curves:
        for kp in fc.keyframe_points:
            off = drift_loc[fc.array_index] * (kp.co.x - f0) / span
            kp.co.y -= off
            kp.handle_left.y -= off
            kp.handle_right.y -= off
        fc.update()
    # Đưa hông về tâm: vị trí ngang trung bình của hông trùng vị trí hông ở rest pose
    rest = arm.matrix_world @ pb.bone.head_local
    frames = range(f0, f1 + 1)
    avg = sum((hips_world(arm, f) for f in frames), Vector()) / len(frames)
    offset_world = Vector((avg.x - rest.x, avg.y - rest.y, 0.0))
    offset_loc = pb.bone.matrix_local.to_3x3().inverted() @ (arm.matrix_world.inverted().to_3x3() @ offset_world)
    for fc in curves:
        for kp in fc.keyframe_points:
            kp.co.y -= offset_loc[fc.array_index]
            kp.handle_left.y -= offset_loc[fc.array_index]
            kp.handle_right.y -= offset_loc[fc.array_index]
        fc.update()
    return drift_world.length


results = []
for name in sorted(os.listdir(in_dir)):
    if not name.lower().endswith(".fbx"):
        continue
    stem = os.path.splitext(name)[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(in_dir, name),
                             automatic_bone_orientation=False, ignore_leaf_bones=False)
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    bpy.context.view_layer.objects.active = arm
    if arm.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    # Bỏ prefix (phần trước dấu ":") của mọi bone và các Empty đầu ngón
    for bone in arm.data.bones:
        if ":" in bone.name:
            bone.name = bone.name.split(":")[-1]
    for obj in bpy.context.scene.objects:
        if ":" in obj.name:
            obj.name = obj.name.split(":")[-1]

    action = arm.animation_data.action
    action.name = "mixamo.com"
    f0, f1 = (int(round(x)) for x in action.frame_range)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = f0, f1
    fps = scene.render.fps
    duration = (f1 - f0) / fps

    # Kiểm tra track animation đã theo tên bone mới
    left_prefix = sum(1 for fc in all_fcurves(action) if ":" in fc.data_path)

    drift = make_in_place(arm, action, f0, f1) if do_in_place else 0.0
    out_path = os.path.join(out_dir, stem + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=out_path)
    results.append((stem, duration, drift, left_prefix))

print("\n[Mixamo Batch] ======================================================")
print(f"[Mixamo Batch] {'clip':32s} {'dài (s)':>8s} {'trôi (m)':>9s} {'tốc độ (m/s)':>13s}")
for stem, duration, drift, left_prefix in results:
    speed = drift / duration if duration > 0 else 0.0
    warn = f"  ⚠ còn {left_prefix} track có prefix" if left_prefix else ""
    print(f"[Mixamo Batch] {stem:32s} {duration:8.2f} {drift:9.3f} {speed:13.2f}{warn}")
print(f"[Mixamo Batch] Đã lưu {len(results)} file vào {out_dir}")
