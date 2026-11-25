class_name PlayerController
extends Node3D
## Đọc input của người chơi và ra lệnh cho nhân vật.
## Nhân vật (HumanoidCharacter) không biết gì về bàn phím hay chuột.

@export var character: HumanoidCharacter  ## nhân vật được điều khiển
@export var camera: Camera3D              ## camera dùng để tính hướng di chuyển và tia chuột
@export var aim_height := 1.2             ## độ cao mặt phẳng ngắm (ngang ngực / nòng súng), m
@export var aim_dead_zone := 0.3          ## chuột gần nhân vật hơn khoảng này thì giữ hướng cũ, m
@export var target_min_height := 0.25     ## con trỏ đè lên vật cao hơn chân bấy nhiêu mét thì bắn THẲNG vào vật
@export_flags_3d_physics var aim_mask := 0b101  ## tia ngắm từ camera trúng layer nào: 1 world + 3 enemy


func _physics_process(_delta: float) -> void:
	if character == null or camera == null:
		return
	character.move_input = _get_move_input()
	character.is_running = Input.is_action_pressed("run")
	if Input.is_action_just_pressed("crouch"):
		character.is_crouching = not character.is_crouching   # C = bật/tắt ngồi
	if character.is_running:
		character.is_crouching = false                        # giữ Shift = đứng dậy chạy luôn
	character.lean_input = _get_lean_input()
	character.trigger = Input.is_action_pressed("shoot")   # chuột trái (action có sẵn)
	if Input.is_action_just_pressed("reload"):
		character.reload()                                   # R	
	var aim_point = _get_aim_point()
	if aim_point != null:
		var to_aim: Vector3 = aim_point - character.global_position
		to_aim.y = 0.0
		if to_aim.length() > aim_dead_zone:
			character.aim_direction = to_aim
	_update_aim_target(aim_point)


## WASD → hướng di chuyển trong thế giới, tính theo góc xoay ngang của camera
func _get_move_input() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_yaw := Basis(Vector3.UP, camera.global_rotation.y)
	return camera_yaw * Vector3(input.x, 0.0, input.y)


## Q / E → hướng nghiêng trong thế giới: trái / phải của MÀN HÌNH (theo camera, giống WASD),
## không phụ thuộc nhân vật đang quay mặt về đâu. Giữ cả hai = 0.
func _get_lean_input() -> Vector3:
	var side := Input.get_axis("lean_left", "lean_right")
	var camera_yaw := Basis(Vector3.UP, camera.global_rotation.y)
	return camera_yaw * Vector3(side, 0.0, 0.0)


## Tia từ camera đi qua con trỏ chuột, cắt mặt phẳng ngang ở độ cao aim_height.
## Trả về điểm cắt (Vector3), hoặc null nếu tia không cắt (ví dụ chuột chỉ lên trời).
func _get_aim_point() -> Variant:
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_dir := camera.project_ray_normal(mouse)
	var plane_point := character.global_position + Vector3.UP * aim_height
	var aim_plane := Plane(Vector3.UP, plane_point)
	return aim_plane.intersects_ray(ray_origin, ray_dir)


## Con trỏ đè lên một vật (hộp, tường, kẻ địch) cao hơn chân target_min_height → bắn THẲNG vào điểm đó.
## Con trỏ chỉ vào sàn trống → dùng điểm trên mặt phẳng ngắm, súng sẽ bắn NGANG theo hướng đó.
func _update_aim_target(plane_point: Variant) -> void:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to, aim_mask, [character.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.position.y > character.global_position.y + target_min_height:
		character.aim_point = hit.position
		character.aim_at_point = true
	elif plane_point != null:
		character.aim_point = plane_point
		character.aim_at_point = false
