class_name HumanoidCharacter
extends CharacterBody3D
## Thân nhân vật dùng chung: di chuyển, xoay theo luật ngưỡng, cập nhật BlendSpace2D.
## Controller (player/AI) chỉ cần gán move_input và aim_direction.

@export_group("Movement")
@export var walk_speed := 1.8        ## m/s, khớp tốc độ của animation walk Mixamo
@export var run_speed := 5.8         ## m/s, khớp tốc độ của animation sprint (giữ Shift)
@export var acceleration := 12.0     ## m/s² khi tăng tốc hoặc giảm tốc
@export var blend_smoothing := 10.0  ## độ mượt khi chuyển blend_position

@export_group("Turning")
@export var max_twist_angle := 60.0   ## độ. Đứng yên: lệch quá góc này thì cả người xoay theo
@export var turn_stop_angle := 5.0    ## độ. Đang xoay tại chỗ: lệch còn dưới góc này thì dừng
@export var turn_delay := 0.1         ## giây. Phải lệch quá ngưỡng liên tục bấy lâu mới bắt đầu xoay chân
@export var idle_turn_speed := 150.0  ## độ/giây. Tốc độ xoay chân khi đứng yên (đều, không chậm dần)
@export var moving_turn_speed := 12.0 ## tốc độ thân bám theo hướng ngắm khi đang đi
@export var moving_threshold := 0.2   ## m/s. Nhanh hơn mức này coi là "đang đi"
@export var twist_smoothing := 15.0   ## độ mượt khi thân trên xoay theo hướng ngắm

@export_group("Debug")
@export var show_debug := true        ## mũi tên ngắm (đỏ), mũi tên chân (xanh), chữ thông số

## Hướng muốn di chuyển, toạ độ thế giới, độ dài 0..1
var move_input := Vector3.ZERO
## Hướng muốn ngắm, toạ độ thế giới. Mặc định là −Z (phía trước của Godot)
var aim_direction := Vector3.FORWARD
## true khi đang giữ nút chạy (controller gán)
var is_running := false

## Góc ngắm (radian), tính từ aim_direction
var aim_yaw := 0.0
## Độ lệch của hướng ngắm so với thân (radian, đã giới hạn). Dương: ngắm lệch sang trái thân
var twist := 0.0
## true khi đang xoay chân tại chỗ (đứng yên mà lệch quá max_twist_angle)
var is_turning := false

const BLEND_PATH := &"parameters/Locomotion/blend_position"
const PLAYBACK_PATH := &"parameters/playback"

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var skeleton: Skeleton3D = $Model/Skeleton_Reference/GeneralSkeleton

var _blend := Vector2.ZERO
var _playback: AnimationNodeStateMachinePlayback
var _anim_state := &"Locomotion"
var _over_threshold_time := 0.0
var _spine_twist: SpineTwistModifier
var _aim_arrow: MeshInstance3D
var _body_arrow: MeshInstance3D
var _debug_label: Label3D


func _ready() -> void:
	_playback = anim_tree.get(PLAYBACK_PATH)
	aim_yaw = rotation.y
	_spine_twist = SpineTwistModifier.new()
	skeleton.add_child(_spine_twist)
	if show_debug:
		_create_debug()


func _physics_process(delta: float) -> void:
	_apply_movement(delta)
	_update_facing(delta)
	_update_state_machine()
	_update_animation(delta)
	_update_spine_twist(delta)
	_update_debug()


func _apply_movement(delta: float) -> void:
	var max_speed := run_speed if is_running else walk_speed
	var target := Vector3(move_input.x, 0.0, move_input.z).limit_length(1.0) * max_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()


func _update_facing(delta: float) -> void:
	# 1) Hướng ngắm → góc ngắm
	var dir := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if dir.length_squared() > 0.0001:
		aim_yaw = atan2(-dir.x, -dir.z)

	var diff := angle_difference(rotation.y, aim_yaw)
	var is_moving := Vector2(velocity.x, velocity.z).length() > moving_threshold

	if is_moving:
		# 2a) Đang đi: thân bám theo hướng ngắm, chân để BlendSpace lo
		is_turning = false
		_over_threshold_time = 0.0
		rotation.y = lerp_angle(rotation.y, aim_yaw, moving_turn_speed * delta)
	else:
		# 2b) Đứng yên: chỉ xoay chân khi lệch quá ngưỡng đủ lâu
		if absf(diff) > deg_to_rad(max_twist_angle):
			_over_threshold_time += delta
		else:
			_over_threshold_time = 0.0
		if not is_turning and _over_threshold_time >= turn_delay:
			is_turning = true
		if is_turning:
			var step := deg_to_rad(idle_turn_speed) * delta
			rotation.y = wrapf(rotation.y + clampf(diff, -step, step), -PI, PI)
			if absf(angle_difference(rotation.y, aim_yaw)) < deg_to_rad(turn_stop_angle):
				is_turning = false

	# 3) Phần lệch còn lại giao cho thân trên
	var max_twist := deg_to_rad(max_twist_angle)
	twist = clampf(angle_difference(rotation.y, aim_yaw), -max_twist, max_twist)

func _update_state_machine() -> void:
	# Đứng yên mà đang xoay chân → phát animation xoay đúng chiều, còn lại → Locomotion
	var wanted := &"Locomotion"
	if is_turning:
		wanted = &"TurnLeft" if angle_difference(rotation.y, aim_yaw) > 0.0 else &"TurnRight"
	if wanted != _anim_state:
		_anim_state = wanted
		_playback.travel(wanted)


func _update_animation(delta: float) -> void:
	# Đổi vận tốc sang hệ toạ độ của thân: x = sang phải, −z = phía trước
	var local := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	var target := Vector2(local.x, -local.z) / walk_speed
	_blend = _blend.lerp(target.limit_length(run_speed / walk_speed), clampf(blend_smoothing * delta, 0.0, 1.0))
	anim_tree.set(BLEND_PATH, _blend)


func _update_spine_twist(delta: float) -> void:
	var weight := clampf(twist_smoothing * delta, 0.0, 1.0)
	_spine_twist.twist = lerp_angle(_spine_twist.twist, twist, weight)


# ---------- Debug ----------

func _create_debug() -> void:
	_aim_arrow = _make_arrow(Color.RED, 1.0)
	_body_arrow = _make_arrow(Color.DODGER_BLUE, 0.7)
	_debug_label = Label3D.new()
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # luôn quay mặt về camera
	_debug_label.no_depth_test = true                          # không bị model che
	_debug_label.font_size = 48
	_debug_label.pixel_size = 0.004
	_debug_label.top_level = true
	add_child(_debug_label)


func _make_arrow(color: Color, length: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var arrow := MeshInstance3D.new()
	arrow.mesh = mesh
	arrow.top_level = true  # không xoay theo thân, tự đặt transform bằng code
	add_child(arrow)
	return arrow


func _place_arrow(arrow: MeshInstance3D, yaw: float, height: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var length: float = (arrow.mesh as BoxMesh).size.z
	# Hộp có tâm ở giữa: đẩy về trước nửa chiều dài + 0.1 m để mũi tên chĩa ra từ thân
	var offset := b * Vector3(0, 0, -(length * 0.5 + 0.1))
	arrow.global_transform = Transform3D(b, global_position + Vector3.UP * height + offset)


func _update_debug() -> void:
	if _aim_arrow == null:
		return
	_place_arrow(_aim_arrow, aim_yaw, 1.3)       # đỏ: hướng ngắm (ngang ngực)
	_place_arrow(_body_arrow, rotation.y, 0.15)  # xanh: hướng chân (sát sàn)
	_debug_label.global_position = global_position + Vector3.UP * 2.1
	_debug_label.text = "body %4d°  aim %4d°\ntwist %+4d°  %s" % [
		roundi(rad_to_deg(rotation.y)), roundi(rad_to_deg(aim_yaw)),
		roundi(rad_to_deg(twist)), _playback.get_current_node()]
