@tool
class_name MagazineHandler
extends Node
## Băng đạn khi nạp (kết hợp animation + physics):
##   drop_at   : băng cũ biến khỏi súng → một bản sao RigidBody rơi xuống sàn
##   grab_at   : băng mới hiện trong tay trái (Node3D "MagSocket" gắn trên xương LeftHand của nhân vật)
##   insert_at : băng mới biến khỏi tay → băng trên súng hiện lại (đã lắp)
## Mốc thời gian = phần trăm thời gian nạp, khớp với clip reload của nhân vật (clip được co giãn cho vừa).
## Đặt node này làm con của root súng (Weapon). Huỷ nạp giữa chừng → mọi thứ trở về như cũ.

@export var magazine: MeshInstance3D                   ## node "Mag" trên súng
@export_range(0.0, 1.0, 0.01) var drop_at := 0.22
@export_range(0.0, 1.0, 0.01) var grab_at := 0.32
@export_range(0.0, 1.0, 0.01) var insert_at := 0.50
@export var hand_socket_name := &"MagSocket"           ## tên Node3D trên tay trái nhân vật
@export var drop_lifetime := 10.0                      ## giây băng rỗng nằm trên sàn
@export var drop_mass := 0.2                           ## kg (băng rỗng)
## Bật trong editor để thấy băng đạn trong tay trái → chỉnh vị trí / góc của MagSocket cho khớp
@export var preview_in_hand := false:
	set(value):
		preview_in_hand = value
		if is_inside_tree() and Engine.is_editor_hint():
			_set_hand_mag_visible(value)

var _weapon: Weapon
var _hand_mag: Node3D
var _active := false
var _elapsed := 0.0
var _duration := 1.0
var _stage := 0                                        ## 0: chưa thả, 1: đã thả, 2: đã cầm băng mới, 3: đã lắp


func _ready() -> void:
	if Engine.is_editor_hint():
		if preview_in_hand:
			_set_hand_mag_visible.call_deferred(true)
		return
	_weapon = _find_weapon()
	if _weapon == null or magazine == null:
		push_warning("%s: cần nằm dưới Weapon và gán Magazine" % name)
		return
	_weapon.reload_started.connect(_on_reload_started)
	_weapon.reload_finished.connect(_restore)
	_weapon.reload_cancelled.connect(_restore)


func _find_weapon() -> Weapon:
	var node := get_parent()
	while node != null and not (node is Weapon):
		node = node.get_parent()
	return node as Weapon


func _on_reload_started(duration: float) -> void:
	_active = true
	_elapsed = 0.0
	_duration = maxf(duration, 0.01)
	_stage = 0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _active:
		return
	_elapsed += delta
	var f := _elapsed / _duration
	if _stage == 0 and f >= drop_at:
		_drop_old_magazine()
		_stage = 1
	if _stage == 1 and f >= grab_at:
		_set_hand_mag_visible(true)
		_stage = 2
	if _stage == 2 and f >= insert_at:
		_set_hand_mag_visible(false)
		magazine.visible = true
		_stage = 3


## Nạp xong hoặc bị huỷ: băng trên súng hiện, băng trong tay ẩn
func _restore() -> void:
	_active = false
	_set_hand_mag_visible(false)
	if magazine != null:
		magazine.visible = true


## Băng cũ: ẩn băng trên súng, tạo bản sao RigidBody đúng chỗ đó để nó rơi
func _drop_old_magazine() -> void:
	magazine.visible = false
	var aabb := magazine.get_aabb()
	var body := RigidBody3D.new()
	body.collision_layer = 8                            # layer 4 debris
	body.collision_mask = 1                             # chỉ va với world
	body.mass = drop_mass
	body.continuous_cd = true
	body.linear_damp = 0.3
	body.angular_damp = 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = magazine.mesh
	mesh.position = -aabb.get_center()                  # tâm khối hộp va chạm = tâm băng đạn
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	shape.shape = box
	body.add_child(shape)
	var world := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world.add_child(body)
	body.global_transform = magazine.global_transform.orthonormalized() * Transform3D(Basis.IDENTITY, aabb.get_center())
	body.linear_velocity = -magazine.global_basis.y.normalized() * 0.8   # tuột xuống khỏi khe băng đạn
	body.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	body.reset_physics_interpolation()
	get_tree().create_timer(drop_lifetime).timeout.connect(body.queue_free)


func _set_hand_mag_visible(value: bool) -> void:
	if value and _hand_mag == null:
		_create_hand_mag()
	if _hand_mag != null:
		_hand_mag.visible = value


## Băng mới trong tay: bản sao hình băng đạn, gắn vào MagSocket trên xương LeftHand
func _create_hand_mag() -> void:
	if magazine == null:
		return
	var socket := _find_hand_socket()
	if socket == null:
		push_warning("%s: không tìm thấy '%s' trên tay trái nhân vật" % [name, hand_socket_name])
		return
	_hand_mag = Node3D.new()
	_hand_mag.name = "HandMag"
	var mesh := MeshInstance3D.new()
	mesh.mesh = magazine.mesh
	mesh.position = -magazine.get_aabb().get_center()   # MagSocket = tâm băng đạn
	_hand_mag.add_child(mesh)
	socket.add_child(_hand_mag)                         # không gán owner → không bị lưu vào scene


## Tìm MagSocket: lúc chơi qua nhân vật (owner_body); trong editor thì tìm trong skeleton phía trên
func _find_hand_socket() -> Node3D:
	if _weapon != null and _weapon.owner_body != null:
		return _weapon.owner_body.find_child(hand_socket_name, true, false) as Node3D
	var node := get_parent()
	while node != null and not (node is Skeleton3D):
		node = node.get_parent()
	return node.find_child(hand_socket_name, true, false) as Node3D if node != null else null