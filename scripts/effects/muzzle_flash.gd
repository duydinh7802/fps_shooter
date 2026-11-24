@tool
class_name MuzzleFlash
extends Node3D
## Lửa đầu nòng: ẩn sẵn, mỗi phát bắn (signal `fired` của Weapon) thì chớp lên trong chốc lát,
## và (nếu gán smoke_scene) nhả một đám khói vào thế giới.
## Mỗi lần chớp: xoay ngẫu nhiên quanh nòng, lật gương, co giãn → các phát không giống nhau.
## Đặt scene này làm con của Empty "Muzzle" trên súng (trục −Z = hướng nòng).

@export_range(0.01, 0.2, 0.005) var duration := 0.05      ## lửa sáng bao lâu, giây (0.05 ≈ 3 frame ở 60 FPS)
@export_range(0.0, 0.5, 0.05) var scale_jitter := 0.2     ## to / nhỏ ngẫu nhiên ± bao nhiêu phần
@export_range(0.0, 0.5, 0.05) var length_jitter := 0.25   ## dài / ngắn ngẫu nhiên thêm theo chiều nòng
@export var random_roll := true                           ## xoay ngẫu nhiên quanh trục nòng
@export var random_flip := true                           ## lật gương ngẫu nhiên
@export_group("Smoke")
@export var smoke_scene: PackedScene                      ## scene khói (muzzle_smoke.tscn). Để trống = không nhả khói
@export_range(1, 10) var smoke_every := 1                 ## mỗi bao nhiêu phát nhả 1 đám khói (bắn nhanh mà khói đặc quá thì tăng)
@export_group("")
## Bấm trong Inspector để xem thử một lần chớp ngay trong editor
@export_tool_button("Flash thử") var preview_flash := flash

var _flashing := false
var _time_left := 0.0
var _light: OmniLight3D
var _light_energy := 0.0                                  ## độ sáng gốc của đèn (lấy từ scene)
var _meshes: Array[GeometryInstance3D] = []
var _shot_count := 0


func _ready() -> void:
	for child in get_children():
		if child is OmniLight3D:
			_light = child
		elif child is GeometryInstance3D:
			_meshes.append(child)
	if _light != null:
		_light_energy = _light.light_energy
	if Engine.is_editor_hint():
		return                     # trong editor: luôn hiện để dễ chỉnh, chỉ chớp khi bấm "Flash thử"
	visible = false
	var weapon := _find_weapon()
	if weapon != null:
		weapon.fired.connect(_on_weapon_fired)
	else:
		push_warning("%s: không nằm dưới node Weapon nào → không biết khi nào bắn" % name)


## Đi ngược lên cây node tới khi gặp Weapon (root của scene súng)
func _find_weapon() -> Weapon:
	var node := get_parent()
	while node != null and not (node is Weapon):
		node = node.get_parent()
	return node as Weapon


func _on_weapon_fired(_from: Vector3, _to: Vector3, _collider: Object) -> void:
	flash()
	_spawn_smoke()


## Tạo một đám khói tại đầu nòng rồi thả vào THẾ GIỚI (không làm con của súng)
## → khói đứng yên chỗ bắn khi người chạy / xoay, tự trôi lên và tan.
func _spawn_smoke() -> void:
	if smoke_scene == null:
		return
	_shot_count += 1
	if _shot_count % smoke_every != 0:
		return
	var smoke: Node3D = smoke_scene.instantiate()
	var world := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world.add_child(smoke)
	# Vị trí + hướng của Muzzle (cha của lửa) lúc bắn, xoay ngẫu nhiên quanh nòng cho mỗi đám một khác
	var muzzle_transform: Transform3D = (get_parent() as Node3D).global_transform.orthonormalized()
	smoke.global_transform = muzzle_transform * Transform3D(Basis(Vector3.BACK, randf() * TAU), Vector3.ZERO)


## Bắt đầu một lần chớp
func flash() -> void:
	var size := 1.0 + randf_range(-scale_jitter, scale_jitter)
	var length := size * (1.0 + randf_range(-length_jitter, length_jitter))
	var mirror := -1.0 if random_flip and randf() < 0.5 else 1.0
	var roll := randf() * TAU if random_roll else 0.0
	# Xoay quanh trục nòng (Z) rồi co giãn: X, Y = bề ngang lửa, Z = chiều dài lửa dọc nòng
	transform.basis = Basis(Vector3.BACK, roll) * Basis.from_scale(Vector3(size * mirror, size, length))
	_time_left = duration
	_flashing = true
	visible = true


func _process(delta: float) -> void:
	if not _flashing:
		return
	if _time_left <= 0.0001:               # 0.0001 thay vì 0: tránh sai số làm thừa 1 frame "0%"
		_end_flash()
		return
	# Frame đầu sáng 100%, các frame sau mờ dần (vd 0.05 s ở 60 FPS: 100% → 67% → 33% → tắt)
	_apply_strength(_time_left / duration)
	_time_left -= delta


func _apply_strength(strength: float) -> void:
	for mesh in _meshes:
		mesh.transparency = 1.0 - strength
	if _light != null:
		_light.light_energy = _light_energy * strength


func _end_flash() -> void:
	_flashing = false
	_apply_strength(1.0)                     # trả về trạng thái gốc
	transform.basis = Basis.IDENTITY
	if not Engine.is_editor_hint():
		visible = false
