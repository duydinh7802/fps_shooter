class_name SpineTwistModifier
extends SkeletonModifier3D
## Xoay thân trên quanh trục đứng, sau khi AnimationTree đã đặt tư thế.
## Góc twist được chia cho các bone cột sống để lưng cong tự nhiên.

## Góc cần xoay (radian). Dương: xoay sang trái (ngược chiều kim đồng hồ nhìn từ trên)
var twist := 0.0

## Tỉ lệ góc cho từng bone. Tổng = 1.0 để ngực (và tay, súng) chỉ đúng hướng ngắm
@export var bone_weights := {&"Spine": 0.25, &"Chest": 0.35, &"UpperChest": 0.4}

var _bone_ids := {}


func _ready() -> void:
	var skeleton := get_skeleton()
	for bone_name in bone_weights:
		_bone_ids[bone_name] = skeleton.find_bone(bone_name)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_zero_approx(twist):
		return
	for bone_name in bone_weights:
		var bone_id: int = _bone_ids.get(bone_name, -1)
		if bone_id < 0:
			continue
		# Trục đứng (UP) của skeleton, đổi sang hệ toạ độ riêng của bone này
		var bone_basis := skeleton.get_bone_global_pose(bone_id).basis.orthonormalized()
		var up_in_bone := (bone_basis.inverse() * Vector3.UP).normalized()
		# Cộng thêm một phần góc xoay lên trên tư thế animation
		var extra := Quaternion(up_in_bone, twist * bone_weights[bone_name])
		skeleton.set_bone_pose_rotation(bone_id, skeleton.get_bone_pose_rotation(bone_id) * extra)
