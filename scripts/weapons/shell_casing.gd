class_name ShellCasing
extends RigidBody3D
## Một vỏ đạn. Kết hợp ANIMATION + PHYSICS:
##   Pha 1 (animation): là con của EjectPort, clip "eject" đẩy vỏ ra khỏi cửa nhả vỏ (sắc nét, lần nào cũng giống).
##   Pha 2 (physics):   hết clip → tách ra thế giới, nhận vận tốc của đoạn cuối clip + vận tốc của súng → rơi, nảy, lăn.
##   Pha 3: nằm yên đủ `lifetime` giây → thu nhỏ rồi tự xoá.
## Scene cần: AnimationPlayer (clip "eject", KHÔNG loop) và node con "Model" (hình vỏ đạn).

@export var lifetime := 8.0                         ## giây, kể từ lúc rời súng
@export var shrink_time := 0.4                      ## giây thu nhỏ trước khi xoá
@export_range(0.0, 1.0, 0.05) var velocity_jitter := 0.25  ## vận tốc ngẫu nhiên ± bao nhiêu phần
@export var extra_spin := 10.0                      ## rad/s quay ngẫu nhiên thêm (lộn vòng)
@export var eject_animation := &"weapons/eject"     ## tên clip văng vỏ: "thư viện/clip"
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _model: Node3D = $Model

var _released := false
var _age := 0.0
var _parent_prev := Vector3.ZERO     ## vị trí cửa nhả vỏ ở frame trước → vận tốc của súng
var _parent_velocity := Vector3.ZERO


func _ready() -> void:
	freeze = true                                    # pha 1: physics chưa chạy, animation điều khiển
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_parent_prev = (get_parent() as Node3D).global_position
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play(eject_animation)
	_anim.seek(0.0, true)                            # áp keyframe đầu ngay, không để vỏ hiện sai chỗ 1 frame


func _physics_process(delta: float) -> void:
	if not _released:
		# Theo dõi chuyển động của cửa nhả vỏ (người chạy / xoay) để cộng vào vận tốc lúc thả
		var parent_pos := (get_parent() as Node3D).global_position
		_parent_velocity = (parent_pos - _parent_prev) / delta
		_parent_prev = parent_pos
		return
	_age += delta
	if _age > lifetime:
		var t := clampf((_age - lifetime) / shrink_time, 0.0, 1.0)
		_model.scale = Vector3.ONE * (1.0 - t)       # thu nhỏ hình, không đụng scale của RigidBody
		if t >= 1.0:
			queue_free()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == eject_animation:
		_release.call_deferred()                     # đổi cha ngay trong lúc AnimationPlayer đang chạy không an toàn


## Pha 2: tách khỏi súng, bật physics, gán vận tốc lấy từ chính clip "eject"
func _release() -> void:
	if _released:
		return
	var port := get_parent() as Node3D
	var clip := _anim.get_animation(eject_animation)
	# Vận tốc ở đoạn cuối clip, trong hệ toạ độ của cửa nhả vỏ (đạo hàm số: 10 ms cuối)
	var dt := minf(0.01, clip.length)
	var local_velocity := (_sample(clip, ".:position", clip.length) - _sample(clip, ".:position", clip.length - dt)) / dt
	var local_spin := (_sample(clip, ".:rotation", clip.length) - _sample(clip, ".:rotation", clip.length - dt)) / dt
	var port_basis := port.global_basis.orthonormalized()
	var jitter := 1.0 + randf_range(-velocity_jitter, velocity_jitter)

	_anim.active = false                             # tắt hẳn animation, kẻo nó kéo vỏ về keyframe
	reparent(_world(), true)                         # giữ nguyên vị trí / hướng trong thế giới
	freeze = false
	linear_velocity = port_basis * local_velocity * jitter + _parent_velocity
	angular_velocity = port_basis * local_spin + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * extra_spin
	reset_physics_interpolation()                    # vừa đổi cha: không nội suy từ vị trí cũ (tránh vệt kéo)
	_released = true


## Giá trị của một track value trong clip tại thời điểm t (Vector3.ZERO nếu không có track)
func _sample(clip: Animation, path: String, t: float) -> Vector3:
	var track := clip.find_track(NodePath(path), Animation.TYPE_VALUE)
	return clip.value_track_interpolate(track, t) if track >= 0 else Vector3.ZERO


func _world() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root