# Make In Place: xoá chuyển động tiến/ngang của Hips (giữ nhún lên xuống và lắc nhẹ)
import bpy
from mathutils import Vector

ROOT_BONE = "Hips"

arm = bpy.context.view_layer.objects.active
if arm is None or arm.type != 'ARMATURE':
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
action = arm.animation_data.action
pb = arm.pose.bones[ROOT_BONE]
f0, f1 = (int(round(x)) for x in action.frame_range)
scene = bpy.context.scene

def hips_world(f):
    scene.frame_set(f)
    return (arm.matrix_world @ pb.matrix).translation.copy()

p0, p1 = hips_world(f0), hips_world(f1)
drift_world = Vector((p1.x - p0.x, p1.y - p0.y, 0.0))          # chỉ mặt phẳng ngang (Blender: Z là trục lên)
drift_arm = arm.matrix_world.inverted().to_3x3() @ drift_world  # sang hệ toạ độ armature
drift_loc = pb.bone.matrix_local.to_3x3().inverted() @ drift_arm # sang hệ toạ độ location của bone

# Lấy F-Curve location của Hips (hỗ trợ cả action kiểu cũ lẫn slotted action của Blender 4.4+)
path = f'pose.bones["{ROOT_BONE}"].location'
def all_fcurves(act):
    if hasattr(act, "layers") and act.layers:
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    yield from bag.fcurves
    else:
        yield from act.fcurves
curves = {fc.array_index: fc for fc in all_fcurves(action) if fc.data_path == path}

span = float(f1 - f0) or 1.0
for i, fc in curves.items():
    for kp in fc.keyframe_points:
        t = (kp.co.x - f0) / span
        off = drift_loc[i] * t
        kp.co.y -= off
        kp.handle_left.y -= off
        kp.handle_right.y -= off
    fc.update()

q0, q1 = hips_world(f0), hips_world(f1)
print(f"[In Place] {action.name}: drift before = {drift_world.length:.3f} m, after = {Vector((q1.x-q0.x, q1.y-q0.y)).length:.4f} m")
