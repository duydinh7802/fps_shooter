class_name ShellEjector
extends Marker3D
## Cửa nhả vỏ (đặt trên súng, trục: +X phải, +Y lên, −Z về phía nòng).
## Mỗi phát bắn (signal `fired` của Weapon):
##   - có `gun_animator` → phát clip khoá nòng (`fire_animation`), clip đó gọi eject() bằng Call Method track
##     → vỏ bật ra đúng lúc khoá nòng lùi hết cỡ;
##   - không có → nhả vỏ ngay.
## Giữ tối đa `max_shells` vỏ trên sàn, quá thì xoá vỏ cũ nhất.

@export var shell_scene: PackedScene                 ## shell_casing.tscn
@export var gun_animator: AnimationPlayer            ## AnimationPlayer của súng (clip khoá nòng). Để trống = nhả vỏ ngay
@export var fire_animation := &"fire"
@export_range(1, 200) var max_shells := 40

var _shells: Array[Node] = []


func _ready() -> void:
	var weapon := _find_weapon()
	if weapon != null:
		weapon.fired.connect(_on_weapon_fired)
	else:
		push_warning("%s: không nằm dưới node Weapon nào → không biết khi nào bắn" % name)


func _find_weapon() -> Weapon:
	var node := get_parent()
	while node != null and not (node is Weapon):
		node = node.get_parent()
	return node as Weapon


func _on_weapon_fired(_from: Vector3, _to: Vector3, _collider: Object) -> void:
	if gun_animator != null and gun_animator.has_animation(fire_animation):
		gun_animator.play(fire_animation)
		gun_animator.seek(0.0, true)                 # bắn liên tục: luôn chạy lại từ đầu
	else:
		eject()


## Tạo một vỏ đạn tại cửa nhả vỏ. Được gọi bởi Call Method track của clip khoá nòng (hoặc trực tiếp)
func eject() -> void:
	if shell_scene == null:
		return
	var shell := shell_scene.instantiate()
	add_child(shell)                                 # pha animation: vỏ là con của cửa nhả vỏ, đi theo súng
	_shells = _shells.filter(func(s): return is_instance_valid(s))
	_shells.append(shell)
	while _shells.size() > max_shells:
		var oldest: Node = _shells.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()