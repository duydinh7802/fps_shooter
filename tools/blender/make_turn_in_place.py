# ============================================================
# MAKE TURN IN PLACE (mốc: bone Spine)
# ============================================================
# Clip xoay tại chỗ của Mixamo (Turn 90 / 180) xoay cả người trong animation.
# Trong game, CharacterBody3D mới là thứ xoay → phải tách phần xoay ra khỏi clip:
#
#   1) Đo góc của bone SPINE quanh trục đứng ở từng frame (so với frame đầu).
#   2) Xoay ngược cả bộ xương (qua Hips) đúng góc đó, quanh trục đứng đi qua 3D Cursor
#      (= gốc object, dưới chân = gốc của CharacterBody3D trong Godot).
#      → Spine luôn nhìn thẳng một hướng; hông, chân vặn bên dưới như clip gốc.
#
# Đường cong góc Spine KHÔNG do script này xuất. Trước khi chạy script, hãy bake nó vào
# Empty "TurnYaw" (Copy Rotation theo Spine → Bake Action). Godot đọc Empty đó bằng
# tools/godot/bake_turn_curves.gd và lưu thành Curve (.tres).
# Trong Godot, code xoay CharacterBody3D theo curve → trục nhân vật xoay cùng Spine.
#
# Cách dùng:
#   1) Trong Blender (tab Scripting): mở file .blend, Run Script, rồi Ctrl+S.
#   2) Hàng loạt (tự lưu):
#      blender -b --python make_turn_in_place.py -- a.blend b.blend ...
#
# Chỉ chạy trên clip CHƯA xử lý (import thẳng từ FBX Mixamo). Clip đã xử lý không còn
# góc xoay → script cảnh báo và bỏ qua, không ghi đè.

import bpy
import math
import os
import sys

from mathutils import Matrix, Vector


# ============================================================
# CONFIGURATION
# ============================================================

ROOT_BONE = "Hips"         # bone gốc: xoay bone này = xoay cả bộ xương
REFERENCE_BONE = "Spine"   # bone làm mốc hướng của nhân vật
MIN_TURN_DEGREES = 5.0     # dưới ngưỡng này coi như clip không có xoay (đã xử lý rồi)


# ============================================================
# HELPERS
# ============================================================

def wrap_angle(angle):
    """Đưa góc về [-PI, PI]."""
    return math.atan2(math.sin(angle), math.cos(angle))


def get_armature():
    """Lấy armature (đang chọn, hoặc cái đầu tiên trong file) và chuyển về Object Mode."""
    armature = bpy.context.view_layer.objects.active
    if armature is None or armature.type != "ARMATURE":
        armature = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if armature is None:
        raise RuntimeError("Không tìm thấy Armature trong file.")
    # Ở Edit Mode, Blender không tính tư thế animation → phải về Object Mode
    bpy.context.view_layer.objects.active = armature
    if armature.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def get_pivot(scene):
    """Điểm xoay = 3D Cursor, trục xoay = trục Z (Blender dùng Z là trục ĐỨNG)."""
    cursor = scene.cursor
    axis = (cursor.rotation_euler.to_matrix() @ Vector((0.0, 0.0, 1.0))).normalized()
    if axis.z < 0.99:
        print("CẢNH BÁO: 3D Cursor đang bị xoay. Reset: N → View → 3D Cursor → Rotation = 0.")
    return cursor.location.copy(), Vector((0.0, 0.0, 1.0))


def bone_yaw(armature, bone, axis):
    """
    Hướng của bone quanh trục đứng (radian).
    Dùng trục X local của bone (trục ngang, vai trái ↔ vai phải với Spine của Mixamo)
    chiếu xuống mặt đất. Chỉ cần góc TƯƠNG ĐỐI giữa các frame nên mốc 0 ở đâu không quan trọng.
    """
    side = (armature.matrix_world @ bone.matrix).to_3x3() @ Vector((1.0, 0.0, 0.0))
    side -= axis * side.dot(axis)
    if side.length < 1e-6:
        raise RuntimeError(f"Trục X của bone '{bone.name}' đang thẳng đứng, không đo được góc.")
    return math.atan2(side.y, side.x)


def measure(armature, bone, axis, frame_start, frame_end):
    """Góc xoay tích luỹ ở từng frame. Cộng dồn từng bước nhỏ → clip 185° không bị nhảy dấu."""
    scene = bpy.context.scene
    scene.frame_set(frame_start)
    previous = bone_yaw(armature, bone, axis)
    accumulated = 0.0
    angles = []
    for frame in range(frame_start, frame_end + 1):
        scene.frame_set(frame)
        current = bone_yaw(armature, bone, axis)
        accumulated += wrap_angle(current - previous)
        previous = current
        angles.append(accumulated)
    return angles


# ============================================================
# PROCESS ONE FILE
# ============================================================

def process(armature):
    scene = bpy.context.scene
    action = armature.animation_data.action if armature.animation_data else None
    if action is None:
        raise RuntimeError("Armature không có Action.")
    for name in (ROOT_BONE, REFERENCE_BONE):
        if name not in armature.pose.bones:
            raise RuntimeError(f"Không có bone '{name}'.")
    root = armature.pose.bones[ROOT_BONE]
    reference = armature.pose.bones[REFERENCE_BONE]
    frame_start = int(round(action.frame_range[0]))
    frame_end = int(round(action.frame_range[1]))
    original_frame = scene.frame_current
    fps = scene.render.fps / scene.render.fps_base
    pivot, axis = get_pivot(scene)
    file_name = os.path.basename(bpy.data.filepath)

    # ---------- PASS 1: đo góc Spine + lưu Hips gốc ----------
    angles = measure(armature, reference, axis, frame_start, frame_end)
    total = math.degrees(angles[-1])
    if abs(total) < MIN_TURN_DEGREES:
        print(f"[Turn In Place] {file_name}: Spine chỉ xoay {total:+.1f}° → BỎ QUA "
              f"(đã xử lý rồi? hãy import lại từ FBX gốc)")
        scene.frame_set(original_frame)
        return False
    root_world = []
    for frame in range(frame_start, frame_end + 1):
        scene.frame_set(frame)
        root_world.append((armature.matrix_world @ root.matrix).copy())

    # ---------- PASS 2: xoay ngược cả bộ xương (qua Hips) quanh trục đứng qua cursor ----------
    to_armature = armature.matrix_world.inverted_safe()
    rotation_path = "rotation_quaternion" if root.rotation_mode == "QUATERNION" else "rotation_euler"
    max_shift = 0.0
    for i, frame in enumerate(range(frame_start, frame_end + 1)):
        scene.frame_set(frame)
        unturn = Matrix.Translation(pivot) @ Matrix.Rotation(-angles[i], 4, axis) @ Matrix.Translation(-pivot)
        corrected = unturn @ root_world[i]
        shift = corrected.translation - root_world[i].translation
        shift.z = 0.0
        max_shift = max(max_shift, shift.length)
        root.matrix = to_armature @ corrected
        bpy.context.view_layer.update()
        # Key cả location: xoay quanh điểm nằm ngoài Hips làm Hips dịch chỗ
        root.keyframe_insert("location", frame=frame, group=root.name)
        root.keyframe_insert(rotation_path, frame=frame, group=root.name)

    # ---------- PASS 3: kiểm tra Spine không còn xoay ----------
    residual = max(abs(math.degrees(a)) for a in measure(armature, reference, axis, frame_start, frame_end))
    scene.frame_set(original_frame)

    print(f"[Turn In Place] {file_name}")
    print(f"    frames {frame_start}-{frame_end}, clip Godot dài {frame_end / fps:.3f} s")
    print(f"    Spine xoay {total:+.1f}° ({'TRÁI' if total > 0 else 'PHẢI'}) → còn tối đa {residual:.2f}°, "
          f"Hips dịch tối đa {max_shift * 100:.1f} cm")
    return True


# ============================================================
# MAIN
# ============================================================

def main():
    files = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not files:
        process(get_armature())          # chạy trong Blender: bạn tự Ctrl+S sau đó
        return
    for path in files:                   # chạy hàng loạt: mở → xử lý → lưu
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(path))
        if process(get_armature()):
            bpy.ops.wm.save_mainfile()
            print(f"    đã lưu {path}")


main()
