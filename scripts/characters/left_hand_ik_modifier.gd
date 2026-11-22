@tool
class_name LeftHandIKModifier
extends SkeletonModifier3D
## IK 2 xương cho tay trái: kéo bàn tay trái tới điểm `target` trên súng (Empty LeftHandGrip).
## Chạy SAU SpineTwist và Lean, để tính trên tư thế cuối cùng của thân trên.
##
## Vì sao tự tính vị trí đích thay vì đọc target.global_position?
## BoneAttachment3D (súng) chỉ cập nhật SAU khi mọi modifier chạy xong, nên vị trí của súng
## đọc lúc này là của frame trước, tay trái sẽ bị trễ 1 frame và rung khi đi.
## Vì vậy ta đọc xương tay phải NGAY BÂY GIỜ rồi cộng độ lệch (cố định) từ tay phải tới LeftHandGrip.
##
## @tool: chạy cả trong editor → mở swat_character.tscn là thấy tay trái bám súng ở mọi tư thế,
## chỉnh thông số / dời WeaponSocket là thấy kết quả ngay, không cần F6.

## Empty LeftHandGrip trên súng. Để trống = tự tìm node tên "LeftHandGrip" dưới skeleton.
## Lúc chạy game, nhân vật gán lại từ weapon_socket (để sau này đổi súng).
var target: Node3D:
	set(value):
		target = value
		_cache_target()

## IK đặt "điểm tiếp xúc" của bàn tay trái (không phải cổ tay) trùng với LeftHandGrip.
## Điểm tiếp xúc nằm trên đoạn cổ tay (LeftHand) → TRUNG BÌNH khớp gốc của các ngón trong danh sách:
##   chỉ LeftIndexProximal                → súng tì vào gốc ngón trỏ (lệch về phía ngón cái)
##   Index + Middle + Ring + LittleProximal → súng nằm ngang giữa hàng khớp gốc 4 ngón
## Các xương này là con của LeftHand nên khoảng cách tới cổ tay cố định → IK vẫn giải tới LeftHand.
@export var contact_bones: Array[StringName] = [&"LeftIndexProximal"]:
	set(value):
		contact_bones = value
		_update_contact_offset()
## 0 = ngay cổ tay, 0.55 ≈ giữa lòng bàn tay, 1 = đúng hàng khớp gốc ngón.
## Tăng = súng dịch lên phía ngón tay, giảm = súng lùi về phía cổ tay.
@export_range(0.0, 1.2, 0.05) var contact_amount := 0.85:
	set(value):
		contact_amount = value
		_update_contact_offset()
## Độ dày nửa bàn tay (m), theo trục +Z của xương LeftHand (phía quay vào súng).
## Để mặt lòng bàn tay chạm ốp súng thay vì xương lún vào trong. Tăng = tay lùi xa súng.
@export var palm_depth := 0.015:
	set(value):
		palm_depth = value
		_update_contact_offset()

@export_group("Hand Rotation")
## 0 = bàn tay xoay theo animation (mỗi tư thế một kiểu), 1 = bàn tay khoá theo súng (luôn nắm giống nhau)
@export_range(0.0, 1.0, 0.05) var hand_lock := 1.0
## Xoay thêm bàn tay (độ), tính theo trục của SÚNG (LeftHandGrip):
##   X = lật cổ tay quanh trục ngang (gập lên / xuống)
##   Y = xoay quanh trục đứng của súng (ngón tay chĩa về trước / về sau)
##   Z = xoay quanh nòng súng (lòng bàn tay ngửa lên / nghiêng sang bên)
## Gốc (0, 0, 0): lòng bàn tay ngửa lên ôm mặt dưới ốp, ngón tay chĩa sang PHẢI súng, ngón trỏ về phía nòng.
## Mặc định Y = 30: ngón tay chĩa chéo về trước → cổ tay bẻ ít nhất (≤ 34° ở mọi tư thế, test headless).
@export var hand_rotation := Vector3(0.0, 30.0, 0.0):
	set(value):
		hand_rotation = value
		_update_hand_in_grip()

@export_group("Fingers")
## 0 = ngón tay theo animation, 1 = ngón tay nắm theo các góc dưới
@export_range(0.0, 1.0, 0.05) var finger_grip := 1.0
## Góc gập (độ) của từng khớp 4 ngón (trỏ, giữa, nhẫn, út). Dương = co vào lòng bàn tay
@export_range(-30.0, 110.0, 1.0) var finger_curl_base := 15.0   ## khớp gốc ngón (Proximal)
@export_range(-30.0, 110.0, 1.0) var finger_curl_mid := 70.0    ## đốt giữa (Intermediate)
@export_range(-30.0, 110.0, 1.0) var finger_curl_tip := 45.0    ## đốt đầu (Distal)
## Ngón cái: quanh X = vắt ngang lòng bàn tay, quanh Z = gập lên phía súng
@export_range(-60.0, 90.0, 1.0) var thumb_across := 0.0
@export_range(-60.0, 90.0, 1.0) var thumb_bend := 0.0

const FINGERS := [&"Index", &"Middle", &"Ring", &"Little"]
const FINGER_JOINTS := [&"Proximal", &"Intermediate", &"Distal"]
const THUMB_JOINTS := [&"Metacarpal", &"Proximal", &"Distal"]

var _finger_ids := []    ## [[proximal, intermediate, distal], ...] cho 4 ngón
var _thumb_ids := []
## Hướng bàn tay trong hệ LeftHandGrip. Cột: X bàn tay (phía ngón út) = +Z súng (về sau),
## Y bàn tay (phía ngón tay) = +X súng (sang phải), Z bàn tay (lòng bàn tay) = +Y súng (lên trên)
const HAND_IN_GRIP_BASE := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
var _hand_in_grip := HAND_IN_GRIP_BASE

var _upper := -1
var _lower := -1
var _hand := -1
var _contact_offset := Vector3.ZERO           ## điểm tiếp xúc trong hệ toạ độ xương LeftHand
var _anchor_bone := -1                      ## xương mà súng bám theo (RightHand)
var _target_in_anchor := Transform3D.IDENTITY  ## LeftHandGrip trong hệ toạ độ của xương đó


func _ready() -> void:
	var skeleton := get_skeleton()
	_upper = skeleton.find_bone(&"LeftUpperArm")
	_lower = skeleton.find_bone(&"LeftLowerArm")
	_hand = skeleton.find_bone(&"LeftHand")
	_finger_ids.clear()
	for finger in FINGERS:
		var ids := []
		for joint in FINGER_JOINTS:
			ids.append(skeleton.find_bone("Left%s%s" % [finger, joint]))
		_finger_ids.append(ids)
	_thumb_ids.clear()
	for joint in THUMB_JOINTS:
		_thumb_ids.append(skeleton.find_bone("LeftThumb%s" % joint))
	_update_contact_offset()
	_update_hand_in_grip()
	if target == null:
		target = skeleton.find_child("LeftHandGrip", true, false)   # setter tự gọi _cache_target()
	else:
		_cache_target()


## Vị trí khớp ngón trỏ so với cổ tay cố định (chiều dài xương bàn tay), lấy từ rest pose.
## Ngón tay co duỗi chỉ xoay khớp, không làm khớp gốc dịch chuyển.
func _update_contact_offset() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var knuckle := Vector3.ZERO
	var count := 0
	for bone_name in contact_bones:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		# Cộng dồn vị trí của bone trong hệ LeftHand (đi ngược lên cha, phòng khi bone không phải con trực tiếp)
		var pos := Vector3.ZERO
		while bone >= 0 and bone != _hand:
			pos = skeleton.get_bone_rest(bone) * pos
			bone = skeleton.get_bone_parent(bone)
		if bone == _hand:
			knuckle += pos
			count += 1
	knuckle = knuckle / count if count > 0 else Vector3(0.0, 0.1, 0.0)
	_contact_offset = knuckle * contact_amount + Vector3(0.0, 0.0, palm_depth)


func _update_hand_in_grip() -> void:
	var r := hand_rotation * (PI / 180.0)
	_hand_in_grip = Basis.from_euler(r) * HAND_IN_GRIP_BASE


## Đi ngược từ target lên tới BoneAttachment3D, nhân dồn transform cục bộ.
## Transform cục bộ không đổi theo animation nên chỉ cần tính một lần.
func _cache_target() -> void:
	_anchor_bone = -1
	var skeleton := get_skeleton()
	if target == null or skeleton == null:
		return
	var rel := Transform3D.IDENTITY
	var node: Node = target
	while node != null and not (node is BoneAttachment3D):
		rel = (node as Node3D).transform * rel
		node = node.get_parent()
	if node == null:
		push_warning("LeftHandIK: target không nằm dưới BoneAttachment3D nào")
		return
	_anchor_bone = skeleton.find_bone((node as BoneAttachment3D).bone_name)
	_target_in_anchor = rel


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if Engine.is_editor_hint() and is_instance_valid(target):
		_cache_target()   # trong editor bạn có thể dời WeaponSocket / súng bất cứ lúc nào → tính lại mỗi frame
	if skeleton == null or _anchor_bone < 0 or _upper < 0 or _lower < 0 or _hand < 0:
		return
	# Mọi phép tính dưới đây đều trong hệ toạ độ skeleton
	var grip := skeleton.get_bone_global_pose(_anchor_bone) * _target_in_anchor
	# Hướng bàn tay: trộn giữa hướng của animation và hướng khoá theo súng
	var anim_basis := skeleton.get_bone_global_pose(_hand).basis.orthonormalized()
	var gun_basis := grip.basis.orthonormalized() * _hand_in_grip
	var hand_basis := anim_basis.slerp(gun_basis, hand_lock).orthonormalized()
	# Cổ tay phải đứng sao cho điểm tiếp xúc (tính theo hướng bàn tay MỚI) trùng LeftHandGrip
	var wrist_target := grip.origin - hand_basis * _contact_offset
	_solve_two_bone(skeleton, wrist_target)
	# Cánh tay xoay làm bàn tay xoay theo → đặt bàn tay về đúng hướng đã chọn
	var hand_now := skeleton.get_bone_global_pose(_hand).basis.orthonormalized()
	_rotate_global(skeleton, _hand, Quaternion(hand_basis * hand_now.inverse()))
	_apply_finger_grip(skeleton)


## Co ngón tay: đặt mỗi đốt = tư thế nghỉ (rest) xoay thêm một góc, rồi trộn với animation theo finger_grip.
## Trục gập đo được trên skeleton này: 4 ngón gập quanh +X của từng đốt (đầu ngón cong về phía lòng bàn tay).
func _apply_finger_grip(skeleton: Skeleton3D) -> void:
	if is_zero_approx(finger_grip):
		return
	var angles := [finger_curl_base, finger_curl_mid, finger_curl_tip]
	for ids in _finger_ids:
		for i in 3:
			_set_joint(skeleton, ids[i], Quaternion(Vector3.RIGHT, deg_to_rad(angles[i])))
	# Ngón cái: chia đều góc cho 3 đốt
	var thumb := Quaternion(Vector3.RIGHT, deg_to_rad(thumb_across) / 3.0) * Quaternion(Vector3.BACK, deg_to_rad(thumb_bend) / 3.0)
	for id in _thumb_ids:
		_set_joint(skeleton, id, thumb)


func _set_joint(skeleton: Skeleton3D, bone: int, curl: Quaternion) -> void:
	if bone < 0:
		return
	var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	var anim := skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, anim.slerp(rest * curl, finger_grip))


## IK 2 xương bằng định lý cos: a = vai (UpperArm), b = khuỷu (LowerArm), c = cổ tay (Hand), t = đích
func _solve_two_bone(skeleton: Skeleton3D, t: Vector3) -> void:
	var a := skeleton.get_bone_global_pose(_upper).origin
	var b := skeleton.get_bone_global_pose(_lower).origin
	var c := skeleton.get_bone_global_pose(_hand).origin
	var lab := a.distance_to(b)   # dài cánh tay trên
	var lcb := b.distance_to(c)   # dài cẳng tay
	# Đích xa quá thì duỗi thẳng tay hết cỡ (không kéo dãn xương)
	var lat := clampf(a.distance_to(t), 0.01, lab + lcb - 0.001)

	# Góc hiện tại của animation
	var ac_ab_0 := _angle(c - a, b - a)   # góc ở vai
	var ba_bc_0 := _angle(a - b, c - b)   # góc ở khuỷu
	var ac_at_0 := _angle(c - a, t - a)   # tay đang chỉ lệch đích bao nhiêu
	# Góc cần có để khoảng cách vai → cổ tay = lat (định lý cos)
	var ac_ab_1 := acos(clampf((lcb * lcb - lab * lab - lat * lat) / (-2.0 * lab * lat), -1.0, 1.0))
	var ba_bc_1 := acos(clampf((lat * lat - lab * lab - lcb * lcb) / (-2.0 * lab * lcb), -1.0, 1.0))

	# Trục gập khuỷu: vuông góc mặt phẳng vai–khuỷu–cổ tay → khuỷu gập đúng hướng animation đang gập
	var axis0 := (c - a).cross(b - a)
	if axis0.length_squared() < 1e-8:            # tay đang thẳng tưng → mượn hướng "khuỷu chĩa xuống"
		axis0 = (c - a).cross(Vector3.DOWN)
	axis0 = axis0.normalized()
	# 1) Co/duỗi: đổi góc vai và góc khuỷu
	_rotate_global(skeleton, _upper, Quaternion(axis0, ac_ab_1 - ac_ab_0))
	_rotate_global(skeleton, _lower, Quaternion(axis0, ba_bc_1 - ba_bc_0))
	# 2) Xoay cả cánh tay từ hướng cũ (a→c) sang hướng đích (a→t)
	var axis1 := (c - a).cross(t - a)
	if axis1.length_squared() > 1e-10:
		_rotate_global(skeleton, _upper, Quaternion(axis1.normalized(), ac_at_0))


## Xoay bone thêm `q` (hệ skeleton) quanh gốc của chính nó, giữ nguyên các bone con theo sau
func _rotate_global(skeleton: Skeleton3D, bone: int, q: Quaternion) -> void:
	var global_basis := skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var new_local := parent_basis.inverse() * Basis(q) * global_basis
	skeleton.set_bone_pose_rotation(bone, new_local.get_rotation_quaternion())


func _angle(u: Vector3, v: Vector3) -> float:
	return acos(clampf(u.normalized().dot(v.normalized()), -1.0, 1.0))
