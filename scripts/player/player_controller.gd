class_name PlayerController
extends Node3D
## Đọc input của người chơi và ra lệnh cho nhân vật.
## Nhân vật (HumanoidCharacter) không biết gì về bàn phím hay chuột.

@export var character: HumanoidCharacter  ## nhân vật được điều khiển
@export var camera: Camera3D              ## camera dùng để tính hướng di chuyển và tia chuột
@export var aim_height := 1.2             ## độ cao mặt phẳng ngắm (ngang ngực / nòng súng), m
@export var aim_dead_zone := 0.3          ## chuột gần nhân vật hơn khoảng này thì giữ hướng cũ, m


func _physics_process(_delta: float) -> void:
	if character == null or camera == null:
		return
	character.move_input = _get_move_input()
	character.is_running = Input.is_action_pressed("run")
	var aim_point = _get_aim_point()
	if aim_point != null:
		var to_aim: Vector3 = aim_point - character.global_position
		to_aim.y = 0.0
		if to_aim.length() > aim_dead_zone:
			character.aim_direction = to_aim


## WASD → hướng di chuyển trong thế giới, tính theo góc xoay ngang của camera
func _get_move_input() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_yaw := Basis(Vector3.UP, camera.global_rotation.y)
	return camera_yaw * Vector3(input.x, 0.0, input.y)


## Tia từ camera đi qua con trỏ chuột, cắt mặt phẳng ngang ở độ cao aim_height.
## Trả về điểm cắt (Vector3), hoặc null nếu tia không cắt (ví dụ chuột chỉ lên trời).
func _get_aim_point() -> Variant:
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_dir := camera.project_ray_normal(mouse)
	var plane_point := character.global_position + Vector3.UP * aim_height
	var aim_plane := Plane(Vector3.UP, plane_point)
	return aim_plane.intersects_ray(ray_origin, ray_dir)
