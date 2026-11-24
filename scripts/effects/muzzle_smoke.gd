class_name MuzzleSmoke
extends Node3D
## Một đám khói sau một phát bắn. MuzzleFlash tạo scene này tại vị trí Muzzle rồi thả vào THẾ GIỚI:
## khói đứng yên chỗ bắn (không đi theo súng), trôi lên, nở ra, mờ dần rồi tự huỷ.
## Phát chuỗi ảnh theo `fps`, có frame blending (trộn khung N với N+1) để mượt ở 60 FPS.
## Cần: SideA / SideB / Front dùng ShaderMaterial (smoke_flipbook.gdshader) đặt ở Material Override,
## và material bật Local to Scene (mỗi đám khói có material riêng → mỗi đám ở một khung khác nhau).

@export var side_frames: Array[Texture2D] = []       ## chuỗi khói side, theo thứ tự (smoke_side/0001 … 0010)
@export var front_frames: Array[Texture2D] = []      ## chuỗi khói front, theo thứ tự (smoke_front/0001 … 0039)
@export var fps := 24.0                              ## tốc độ phát, khung / giây (footage gốc 24)
@export var frame_blending := true                   ## trộn 2 khung liền nhau cho mượt
@export_range(0.0, 2.0, 0.05) var opacity := 1.0     ## độ đậm chung
@export_range(0.0, 1.0, 0.05) var fade_start := 0.6  ## đi được bấy nhiêu phần đời thì bắt đầu mờ dần
@export var rise_speed := 0.25                       ## m/s, khói bay lên
@export var drift_speed := 0.1                       ## m/s, trôi ngang ngẫu nhiên tối đa
@export_range(0.0, 3.0, 0.1) var grow := 0.8         ## cuối đời to thêm bấy nhiêu lần (0.8 = to thêm 80%)

var _time := 0.0
var _lifetime := 1.0
var _velocity := Vector3.ZERO
var _base_scale := Vector3.ONE
var _side_material: ShaderMaterial
var _front_material: ShaderMaterial


func _ready() -> void:
	_side_material = get_node("SideA").material_override as ShaderMaterial
	_front_material = get_node("Front").material_override as ShaderMaterial
	# Sống bằng chuỗi dài nhất (front: 20 khung / 24 = 0.83 s)
	_lifetime = maxf(maxi(side_frames.size(), front_frames.size()), 1) / fps
	var drift := Vector2.from_angle(randf() * TAU) * randf() * drift_speed
	_velocity = Vector3(drift.x, rise_speed, drift.y)
	_base_scale = scale
	_update(0.0)


func _process(delta: float) -> void:
	_time += delta
	if _time >= _lifetime:
		queue_free()
		return
	global_position += _velocity * delta
	_update(_time)


func _update(t: float) -> void:
	var life := t / _lifetime                       # 0 → 1 trong suốt vòng đời
	scale = _base_scale * (1.0 + grow * life)
	var fade := opacity * (1.0 - smoothstep(fade_start, 1.0, life))
	_show_frame(_side_material, side_frames, t, fade)
	_show_frame(_front_material, front_frames, t, fade)


## Chọn khung theo thời gian: khung i và i+1, trộn theo phần lẻ. Chạy hết chuỗi thì ẩn tấm đó.
func _show_frame(material: ShaderMaterial, frames: Array[Texture2D], t: float, fade: float) -> void:
	if material == null or frames.is_empty():
		return
	var f := t * fps
	var last := frames.size() - 1
	var i := mini(int(f), last)
	var next := mini(i + 1, last)
	var mix_amount := clampf(f - i, 0.0, 1.0) if frame_blending else 0.0
	material.set_shader_parameter("frame_a", frames[i])
	material.set_shader_parameter("frame_b", frames[next])
	material.set_shader_parameter("blend", mix_amount)
	material.set_shader_parameter("opacity", fade if f <= last + 1 else 0.0)
