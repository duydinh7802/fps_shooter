class_name Weapon
extends Node3D
## Súng: nhận lệnh bóp cò từ nhân vật, đếm nhịp bắn, trừ đạn, bắn tia (hitscan) từ Muzzle.
## Không đọc bàn phím. Nhân vật (hoặc AI sau này) gán trigger / aim_point mỗi frame.

## Phát ra mỗi phát bắn: from = đầu nòng, to = điểm trúng (hoặc cuối tầm), collider = vật trúng (null nếu trượt)
signal fired(from: Vector3, to: Vector3, collider: Object)
signal ammo_changed(ammo: int, reserve: int)
signal reload_started(duration: float)   ## bắt đầu nạp, duration = thời gian nạp (giây)
signal reload_finished                   ## nạp xong, đạn đã chuyển vào băng
signal reload_cancelled                  ## bị huỷ giữa chừng (vd chạy), đạn không đổi
signal dry_fired                         ## bóp cò khi băng rỗng (tiếng "tạch")

@export var data: WeaponData                             ## thông số súng (file .tres)
@export_flags_3d_physics var hit_mask := 0b101           ## tia đạn trúng layer nào: 1 world + 3 enemy
@export var show_debug := true                           ## vẽ tia đỏ mỗi phát bắn
@export var debug_line_time := 0.1                       ## tia đỏ hiện bao lâu, giây
@export var auto_reload := true                          ## bóp cò khi băng rỗng → tự nạp (nếu còn dự trữ)

# ---- Nhân vật gán mỗi frame ----
var trigger := false                    ## đang bóp cò
var can_fire := true                    ## false khi đang sprint, nạp đạn…
var aim_point := Vector3.ZERO           ## điểm ngắm trong thế giới
var aim_at_point := false               ## true: bắn thẳng vào aim_point. false: bắn NGANG theo hướng aim_point
var fallback_direction := Vector3.FORWARD  ## hướng bắn khi con trỏ ở sát người
var owner_body: CollisionObject3D       ## thân nhân vật: loại khỏi tia đạn + dùng chống bắn xuyên tường

var ammo := 0
var reserve := 0
var is_reloading := false
var reload_time_left := 0.0             ## còn bao lâu nạp xong, giây

var _muzzle: Node3D
var _cooldown := 0.0          ## còn bao lâu mới được bắn phát tiếp
var _burst_left := 0          ## số phát còn phải bắn (SEMI = 1, BURST = burst_count)
var _was_pressed := false
var _debug_mesh: ImmediateMesh
var _debug_lines := []        ## [[from, to, trúng?, thời gian còn lại], ...]


func _ready() -> void:
	_muzzle = find_child("Muzzle", true, false)
	if _muzzle == null:
		push_warning("%s: không tìm thấy Empty 'Muzzle' → bắn từ gốc súng" % name)
		_muzzle = self
	if data == null:
		push_warning("%s: chưa gán WeaponData → súng không bắn" % name)
		return
	ammo = data.magazine_size
	reserve = data.reserve_ammo
	if show_debug:
		_create_debug()


func _physics_process(delta: float) -> void:
	if data == null:
		return
	_update_reload(delta)
	_update_trigger(delta)
	_update_debug(delta)


func _update_trigger(delta: float) -> void:
	var pressed := trigger and can_fire and not is_reloading
	var just_pressed := pressed and not _was_pressed
	_was_pressed = pressed
	if not can_fire or is_reloading:
		_burst_left = 0                     # đang bắn dở loạt mà bị cấm (chạy, nạp đạn) → dừng
	if just_pressed and ammo <= 0:
		dry_fired.emit()
		if auto_reload:
			reload()
		return                              # hết đạn: không bắn
	match data.fire_mode:
		WeaponData.FireMode.SEMI:
			if just_pressed:
				_burst_left = 1
		WeaponData.FireMode.BURST:
			if just_pressed and _burst_left == 0:
				_burst_left = data.burst_count
	var auto := data.fire_mode == WeaponData.FireMode.AUTO and pressed

	_cooldown -= delta
	# CỘNG DỒN thời gian chờ (không gán lại) → phần lẻ không bị mất, đúng nhịp dù FPS dao động.
	# while: nếu một frame dài hơn khoảng cách 2 phát (FPS rất thấp) thì bắn bù luôn trong frame đó.
	while (auto or _burst_left > 0) and _cooldown <= 0.0 and ammo > 0:
		_fire_one()
		_cooldown += 60.0 / data.fire_rate
		if _burst_left > 0:
			_burst_left -= 1
	if ammo <= 0:
		_burst_left = 0
	# Không bắn thì không "để dành" thời gian chờ, tránh bóp cò lại là bắn dồn nhiều phát cùng lúc
	_cooldown = maxf(_cooldown, 0.0)


func _fire_one() -> void:
	ammo -= 1
	ammo_changed.emit(ammo, reserve)
	var from := _muzzle.global_position
	var to := from + _shot_direction(from) * data.max_range
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if owner_body != null:
		exclude.append(owner_body.get_rid())
	var hit := {}
	# Chống bắn xuyên tường: đứng sát tường thì nòng súng có thể thò qua tường.
	# Bắn một tia ngắn từ giữa người (cùng độ cao nòng) → nòng; trúng tường thì phát đạn dừng ở đó.
	if owner_body != null:
		var body_center := owner_body.global_position
		body_center.y = from.y
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(body_center, from, hit_mask, exclude))
	if hit.is_empty():
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, hit_mask, exclude))
	var end: Vector3 = hit.position if not hit.is_empty() else to
	var collider: Object = hit.collider if not hit.is_empty() else null
	fired.emit(from, end, collider)
	if show_debug:
		_debug_lines.append([from, end, collider != null, debug_line_time])


## Hướng bắn (đã chuẩn hoá):
##   aim_at_point = true  → thẳng vào aim_point (con trỏ đang đè lên một vật)
##   aim_at_point = false → NGANG ở độ cao nòng, theo hướng aim_point (con trỏ chỉ vào sàn trống)
##   aim_point ở sát người (gần hơn nòng súng) → theo fallback_direction
func _shot_direction(from: Vector3) -> Vector3:
	var to_aim := aim_point - from
	var flat := Vector3(to_aim.x, 0.0, to_aim.z)
	var origin := owner_body.global_position if owner_body != null else from
	var aim_distance := Vector2(aim_point.x - origin.x, aim_point.z - origin.z).length()
	var muzzle_distance := Vector2(from.x - origin.x, from.z - origin.z).length()
	if aim_distance <= muzzle_distance + 0.1 or flat.length_squared() < 0.0001:
		var fallback := Vector3(fallback_direction.x, 0.0, fallback_direction.z)
		return fallback.normalized() if fallback.length_squared() > 0.0001 else -global_basis.z
	return to_aim.normalized() if aim_at_point else flat.normalized()

# ---------- Nạp đạn ----------

## Có nạp được không: không đang nạp, băng chưa đầy, còn đạn dự trữ
func can_reload() -> bool:
	return data != null and not is_reloading and ammo < data.magazine_size and reserve > 0


## Bắt đầu nạp. Trả về false nếu không nạp được. Nhân vật / AI gọi hàm này
func reload() -> bool:
	if not can_reload():
		return false
	is_reloading = true
	reload_time_left = data.reload_time
	_burst_left = 0
	reload_started.emit(data.reload_time)
	return true


## Huỷ nạp giữa chừng (vd bắt đầu chạy): đạn giữ nguyên như trước khi nạp
func cancel_reload() -> void:
	if not is_reloading:
		return
	is_reloading = false
	reload_time_left = 0.0
	reload_cancelled.emit()


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return
	reload_time_left -= delta
	if reload_time_left > 0.0:
		return
	# Đạn còn trong băng cũ được giữ lại; chỉ lấy từ dự trữ phần còn thiếu
	var take := mini(data.magazine_size - ammo, reserve)
	ammo += take
	reserve -= take
	is_reloading = false
	reload_time_left = 0.0
	ammo_changed.emit(ammo, reserve)
	reload_finished.emit()

# ---------- Debug: tia đỏ (trúng) / vàng (trượt) ----------

func _create_debug() -> void:
	_debug_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _debug_mesh
	mi.top_level = true                  # toạ độ thế giới, không đi theo súng
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	add_child(mi)


func _update_debug(delta: float) -> void:
	if _debug_mesh == null:
		return
	_debug_mesh.clear_surfaces()
	for line in _debug_lines:
		line[3] -= delta
	_debug_lines = _debug_lines.filter(func(l): return l[3] > 0.0)
	if _debug_lines.is_empty():
		return
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for line in _debug_lines:
		var color := Color.RED if line[2] else Color.YELLOW
		_debug_mesh.surface_set_color(color)
		_debug_mesh.surface_add_vertex(line[0])
		_debug_mesh.surface_add_vertex(line[1])
		# dấu + nhỏ ở điểm cuối
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			_debug_mesh.surface_add_vertex(line[1] - axis * 0.08)
			_debug_mesh.surface_add_vertex(line[1] + axis * 0.08)
	_debug_mesh.surface_end()
