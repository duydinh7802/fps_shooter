# Make Turn In Place: xoá phần XOAY quanh trục đứng của Hips trong animation xoay tại chỗ
# (Rifle Turn Left / Right). Bước chân, nhún, nghiêng người được giữ nguyên.
# Trong game, code sẽ tự xoay thân nhân vật, nên animation không được xoay thêm nữa.
import bpy
from mathutils import Matrix, Vector
import math

ROOT_BONE = "Hips"
LEFT_THIGH = "LeftUpLeg"
RIGHT_THIGH = "RightUpLeg"

arm = bpy.context.view_layer.objects.active
if arm is None or arm.type != 'ARMATURE':
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
# Ở Edit Mode, Blender không tính tư thế animation → phải về Object Mode trước
bpy.context.view_layer.objects.active = arm
if arm.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
action = arm.animation_data.action
pb = arm.pose.bones[ROOT_BONE]
f0, f1 = (int(round(x)) for x in action.frame_range)
scene = bpy.context.scene


def hips_yaw():
    """Hướng hông quanh trục Z (Blender: Z là trục lên), đo bằng đường nối 2 đùi."""
    l = arm.matrix_world @ arm.pose.bones[LEFT_THIGH].head
    r = arm.matrix_world @ arm.pose.bones[RIGHT_THIGH].head
    across = l - r
    return math.atan2(across.y, across.x)


# Lượt 1: đo góc hông ở từng frame (so với frame đầu) và lưu ma trận thế giới của Hips
scene.frame_set(f0)
yaw0 = hips_yaw()
samples = []
for f in range(f0, f1 + 1):
    scene.frame_set(f)
    yaw = math.atan2(math.sin(hips_yaw() - yaw0), math.cos(hips_yaw() - yaw0))  # bọc về -pi..pi
    samples.append((f, yaw, (arm.matrix_world @ pb.matrix).copy()))
total = math.degrees(samples[-1][1])

# Lượt 2: xoay ngược Hips quanh trục đứng đi qua chính nó, rồi ghi keyframe xoay mới
for f, yaw, world in samples:
    scene.frame_set(f)
    pivot = world.translation
    unturn = Matrix.Translation(pivot) @ Matrix.Rotation(-yaw, 4, 'Z') @ Matrix.Translation(-pivot)
    pb.matrix = arm.matrix_world.inverted() @ (unturn @ world)
    pb.keyframe_insert("rotation_quaternion", frame=f)

# Kiểm tra lại
scene.frame_set(f0)
yaw0 = hips_yaw()
worst = 0.0
for f in range(f0, f1 + 1):
    scene.frame_set(f)
    d = math.degrees(math.atan2(math.sin(hips_yaw() - yaw0), math.cos(hips_yaw() - yaw0)))
    worst = max(worst, abs(d))
print(f"[Turn In Place] {action.name}: frames {f0}-{f1}, hips turned {total:+.1f} deg -> now max {worst:.2f} deg")
print(f"[Turn In Place] Ghi lại: góc xoay = {abs(total):.0f} độ, thời lượng = {(f1 - f0) / scene.render.fps:.2f} s")
