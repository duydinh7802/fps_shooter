class_name HumanoidCharacter
extends CharacterBody3D
## Thân nhân vật dùng chung: di chuyển, xoay theo hướng nhìn, cập nhật BlendSpace2D.
## Controller (player/AI) chỉ cần gán move_input và look_direction.

@export var walk_speed := 1.8        ## m/s, khớp tốc độ của animation walk Mixamo
@export var acceleration := 12.0     ## m/s² khi tăng tốc hoặc giảm tốc
@export var turn_speed := 12.0       ## tốc độ xoay về hướng nhìn
@export var blend_smoothing := 10.0  ## độ mượt khi chuyển blend_position

## Hướng muốn di chuyển, toạ độ thế giới, độ dài 0..1
var move_input := Vector3.ZERO
## Hướng muốn nhìn, toạ độ thế giới. Mặc định là −Z (phía trước của Godot)
var look_direction := Vector3.FORWARD

const BLEND_PATH := &"parameters/Locomotion/blend_position"

@onready var anim_tree: AnimationTree = $AnimationTree

var _blend := Vector2.ZERO


func _physics_process(delta: float) -> void:
	_apply_movement(delta)
	_apply_facing(delta)
	_update_animation(delta)


func _apply_movement(delta: float) -> void:
	var target := Vector3(move_input.x, 0.0, move_input.z).limit_length(1.0) * walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()


func _apply_facing(delta: float) -> void:
	var dir := Vector3(look_direction.x, 0.0, look_direction.z)
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)  # yaw khi mặt nhìn về −Z
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)


func _update_animation(delta: float) -> void:
	# Đổi vận tốc sang hệ toạ độ của nhân vật: x = sang phải, −z = phía trước
	var local := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	var target := Vector2(local.x, -local.z) / walk_speed
	_blend = _blend.lerp(target.limit_length(1.0), clampf(blend_smoothing * delta, 0.0, 1.0))
	anim_tree.set(BLEND_PATH, _blend)
