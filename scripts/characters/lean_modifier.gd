class_name LeanModifier
extends SkeletonModifier3D
## Nghiêng NỬA THÂN TRÊN (từ eo trở lên) theo một hướng trong THẾ GIỚI, chạy SAU SpineTwistModifier.
## Hướng nghiêng không phụ thuộc nhân vật đang quay mặt về đâu: Q luôn ngả về bên trái màn hình,
## E luôn ngả về bên phải (controller đổi Q/E sang hướng thế giới theo camera, giống WASD).

## Hướng + độ nghiêng trong thế giới (nằm ngang). Hướng = phía đầu ngả về,
## độ dài = góc nghiêng (radian). Vector3.ZERO = đứng thẳng. Nhân vật gán mỗi frame
var lean := Vector3.ZERO

## Tỉ lệ góc cho từng bone. Tổng = 1.0 → ngực nghiêng đúng bằng góc `lean`.
## Dồn hết vào Spine (bone ngay trên hông) = cả nửa thân trên nghiêng thẳng như một khối từ eo.
## Chia sang Chest / UpperChest = lưng cong dần.
@export var bone_weights := {&"Spine": 1.0, &"Chest": 0.0, &"UpperChest": 0.0}
## Đầu xoay ngược lại bao nhiêu phần góc nghiêng (0 = đầu nghiêng theo người, 1 = đầu thẳng hoàn toàn)
@export_range(0.0, 1.0, 0.05) var head_counter := 0.0

var _bone_ids := {}
var _head_id := -1


func _ready() -> void:
	var skeleton := get_skeleton()
	for bone_name in bone_weights:
		_bone_ids[bone_name] = skeleton.find_bone(bone_name)
	_head_id = skeleton.find_bone(&"Head")


func _process_modification() -> void:
	var skeleton := get_skeleton()
	var angle := lean.length()
	if skeleton == null or is_zero_approx(angle):
		return
	# Trục quay để đỉnh đầu (UP) ngả về hướng `lean`: axis = UP × hướng.
	# (Quay UP quanh axis một góc dương → UP nghiêng về phía axis × UP = hướng lean)
	var axis_world := Vector3.UP.cross(lean / angle)
	# Đổi trục từ thế giới sang hệ toạ độ của skeleton
	var axis := (skeleton.global_basis.orthonormalized().inverse() * axis_world).normalized()
	for bone_name in bone_weights:
		_rotate_bone(skeleton, _bone_ids.get(bone_name, -1), axis, angle * bone_weights[bone_name])
	_rotate_bone(skeleton, _head_id, axis, -angle * head_counter)


## Cộng thêm góc `angle` quanh trục `axis` (hệ skeleton) lên tư thế hiện tại của bone
func _rotate_bone(skeleton: Skeleton3D, bone_id: int, axis: Vector3, angle: float) -> void:
	if bone_id < 0 or is_zero_approx(angle):
		return
	# Đổi trục sang hệ toạ độ riêng của bone (giống SpineTwistModifier)
	var bone_basis := skeleton.get_bone_global_pose(bone_id).basis.orthonormalized()
	var axis_in_bone := (bone_basis.inverse() * axis).normalized()
	skeleton.set_bone_pose_rotation(bone_id, skeleton.get_bone_pose_rotation(bone_id) * Quaternion(axis_in_bone, angle))
