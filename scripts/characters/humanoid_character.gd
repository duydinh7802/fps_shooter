class_name HumanoidCharacter
extends CharacterBody3D
## Thân nhân vật dùng chung: di chuyển, xoay theo luật ngưỡng, cập nhật BlendSpace2D.
## Controller (player/AI) chỉ cần gán move_input và aim_direction.

@export_group("Movement")
@export var walk_speed := 1.8        ## m/s, khớp tốc độ của animation walk Mixamo
@export var run_speed := 5.8         ## m/s, khớp tốc độ của animation sprint (giữ Shift)
@export var crouch_speed := 1.95     ## m/s, khớp tốc độ clip crouch_walk (đo được 1.96)
@export var acceleration := 12.0     ## m/s² khi tăng tốc hoặc giảm tốc
@export var blend_smoothing := 10.0  ## độ mượt khi chuyển blend_position

@export_group("Turning")
@export var max_twist_angle := 60.0   ## độ. Đứng yên: lệch quá góc này thì cả người xoay theo
@export var turn_delay := 0.1         ## giây. Phải lệch quá ngưỡng liên tục bấy lâu mới bắt đầu xoay chân
## Curve góc Spine theo thời gian của từng clip turn (turn_curves/*_yaw.tres).
## Góc cuối của mỗi curve = toạ độ điểm của clip đó trong BlendSpace1D TurnInPlace.
## (Muốn dùng file _yaw.res kiểu Animation thì đổi qua _yaw_to_curve() — xem hàm đó.)
@export var turn_curves: Array[Curve] = []
## Như turn_curves nhưng cho clip xoay khi ngồi (turn_curves/crouch_turn_*_yaw.tres),
## góc cuối = toạ độ điểm trong BlendSpace1D CrouchTurn.
@export var crouch_turn_curves: Array[Curve] = []
@export var moving_turn_speed := 12.0 ## tốc độ thân bám theo hướng ngắm khi đang đi
@export var moving_threshold := 0.2   ## m/s. Nhanh hơn mức này coi là "đang đi"
@export var twist_smoothing := 15.0   ## độ mượt khi thân trên xoay theo hướng ngắm

@export_group("Lean")
@export_range(0.0, 45.0, 0.5) var max_lean_angle := 22.0   ## độ. Góc nghiêng tối đa khi giữ Q / E
@export_range(0.0, 1.0, 0.05) var crouch_lean_scale := 0.7 ## khi ngồi chỉ nghiêng bằng chừng này phần
@export var lean_smoothing := 10.0                         ## độ mượt khi nghiêng / về thẳng

@export_group("Weapon")
## Node WeaponSocket (dưới RightHandAttachment). Tay trái sẽ bám vào Empty "LeftHandGrip" của súng bên trong nó
@export var weapon_socket: Node3D
@export var left_hand_ik := true      ## tắt để xem tay trái theo animation gốc
@export var reload_animation := &"rifle_upper/reload"   ## clip nạp đạn (dùng để tính tốc độ phát)
@export var ik_fade_time := 0.2                         ## giây tắt / bật IK tay trái khi nạp

@export_group("Debug")
@export var show_debug := true        ## mũi tên ngắm (đỏ), mũi tên chân (xanh), chữ thông số

## Hướng muốn di chuyển, toạ độ thế giới, độ dài 0..1
var move_input := Vector3.ZERO
## Hướng muốn ngắm, toạ độ thế giới. Mặc định là −Z (phía trước của Godot)
var aim_direction := Vector3.FORWARD
## true khi đang giữ nút chạy (controller gán)
var is_running := false
## true khi đang ngồi (controller bật/tắt)
var is_crouching := false
## Muốn nghiêng: −1 = trái (Q), +1 = phải (E), 0 = thẳng (controller gán)
var lean_input := Vector3.ZERO
## Nghiêng hiện tại trong thế giới (đã làm mượt): hướng = phía đầu ngả về, độ dài = góc (radian)
var lean := Vector3.ZERO
## Đang bóp cò (controller gán)
var trigger := false
## Điểm ngắm trong thế giới, và có bắn thẳng vào nó không (controller gán, xem Weapon._shot_direction)
var aim_point := Vector3.ZERO
var aim_at_point := false
## Súng đang cầm, tìm trong weapon_socket lúc _ready
var weapon: Weapon

## Góc ngắm (radian), tính từ aim_direction
var aim_yaw := 0.0
## Độ lệch của hướng ngắm so với thân (radian, đã giới hạn). Dương: ngắm lệch sang trái thân
var twist := 0.0
## true khi đang xoay chân tại chỗ (đứng yên mà lệch quá max_twist_angle)
var is_turning := false

const BLEND_PATH := &"parameters/StateMachine/Locomotion/blend_position"
const PLAYBACK_PATH := &"parameters/StateMachine/playback"
const TURN_BLEND_PATH := &"parameters/StateMachine/TurnInPlace/blend_position"
const CROUCH_BLEND_PATH := &"parameters/StateMachine/Crouch/blend_position"
const CROUCH_TURN_BLEND_PATH := &"parameters/StateMachine/CrouchTurn/blend_position"
const RELOAD_REQUEST_PATH := &"parameters/Reload/request"   ## OneShot thân trên
const RELOAD_SPEED_PATH := &"parameters/ReloadSpeed/scale"  ## TimeScale: co giãn clip cho vừa thời gian nạp
const YAW_TRACK := ^"TurnYaw"     ## tên Empty trong Blender = tên track trong animation _yaw.res
const YAW_SAMPLE_FPS := 30.0      ## Mixamo 30 frame/giây

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var skeleton: Skeleton3D = $Model/Skeleton_Reference/GeneralSkeleton

var _blend := Vector2.ZERO
var _playback: AnimationNodeStateMachinePlayback
var _anim_state := &"Locomotion"
var _over_threshold_time := 0.0
var _spine_twist: SpineTwistModifier
var _lean_modifier: LeanModifier
var _left_hand_ik: LeftHandIKModifier
var _ik_tween: Tween
var _aim_arrow: MeshInstance3D
var _body_arrow: MeshInstance3D
var _debug_label: Label3D
var _turn_curves: Array[Curve] = []  ## các curve dùng để chọn clip (lấy từ turn_curves trong _ready)
var _turn_curve: Curve        ## curve của clip đang xoay
var _turn_time := 0.0         ## đã xoay được bao lâu (giây)
var _turn_start_yaw := 0.0    ## góc thân lúc bắt đầu xoay (radian)
var _turn_state := &"TurnInPlace"  ## state đang phát clip xoay: TurnInPlace (đứng) hoặc CrouchTurn (ngồi)


func _ready() -> void:
	# Bật lại phòng khi lỡ tắt Active trong editor để xem trước clip bằng AnimationPlayer
	anim_tree.active = true
	_playback = anim_tree.get(PLAYBACK_PATH)
	aim_yaw = rotation.y
	_spine_twist = SpineTwistModifier.new()
	skeleton.add_child(_spine_twist)
	# Thêm SAU twist: modifier chạy theo thứ tự node con → vặn theo chuột trước, nghiêng sau
	_lean_modifier = LeanModifier.new()
	skeleton.add_child(_lean_modifier)
	# IK tay trái: dùng node có sẵn trong scene (để xem trước trong editor), không có thì tạo mới.
	for child in skeleton.get_children():
		if child is LeftHandIKModifier:
			_left_hand_ik = child
	if _left_hand_ik == null:
		_left_hand_ik = LeftHandIKModifier.new()
		skeleton.add_child(_left_hand_ik)
	# Dời xuống CUỐI: thân trên đã xoay + nghiêng xong thì mới kéo tay trái vào súng.
	# (Node trong scene có sẵn từ trước, nên nếu không dời thì nó đứng TRƯỚC twist/lean vừa thêm bằng code)
	skeleton.move_child(_left_hand_ik, -1)
	_left_hand_ik.active = left_hand_ik
	if weapon_socket != null:
		# owned = false: LeftHandGrip nằm trong scene súng được instance, không "thuộc" scene này
		_left_hand_ik.target = weapon_socket.find_child("LeftHandGrip", true, false)
	if _left_hand_ik.target == null:
		push_warning("%s: chưa gán Weapon Socket (hoặc súng không có LeftHandGrip) → tay trái không bám súng" % name)
	if weapon_socket != null:
		for child in weapon_socket.get_children():
			if child is Weapon:
				weapon = child
	if weapon != null:
		weapon.owner_body = self     # tia đạn bỏ qua thân mình + dùng để chống bắn xuyên tường
		weapon.reload_started.connect(_on_reload_started)
		weapon.reload_finished.connect(_on_reload_ended)
		weapon.reload_cancelled.connect(_on_reload_ended)
	_setup_upper_body_filter()
	_turn_curves.assign(turn_curves)
	if _turn_curves.is_empty():
		push_warning("%s: chưa gán Turn Curves → đứng yên sẽ không xoay chân, chỉ vặn thân trên" % name)
	if crouch_turn_curves.is_empty():
		push_warning("%s: chưa gán Crouch Turn Curves → ngồi yên sẽ không xoay chân" % name)
	if show_debug:
		_create_debug()


func _physics_process(delta: float) -> void:
	_apply_movement(delta)
	_update_facing(delta)
	_update_state_machine()
	_update_animation(delta)
	_update_spine_twist(delta)
	_update_lean(delta)
	_update_weapon()
	_update_debug()


func _apply_movement(delta: float) -> void:
	var max_speed := walk_speed
	if is_crouching:
		max_speed = crouch_speed
	elif is_running:
		max_speed = run_speed
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
	elif is_turning:
		# 2b) Đang xoay tại chỗ: trục nhân vật xoay CÙNG Spine trong clip gốc.
		#     Clip đã bị tách phần xoay (Spine đứng yên), curve giữ lại góc Spine theo thời gian
		#     → góc thân = góc lúc bắt đầu + góc Spine đã xoay tới thời điểm này.
		_turn_time += delta
		var spine_turned := _turn_curve.sample(minf(_turn_time, _turn_curve.max_domain))
		rotation.y = wrapf(_turn_start_yaw + deg_to_rad(spine_turned), -PI, PI)
		if _turn_time >= _turn_curve.max_domain:
			is_turning = false   # hết clip → về Locomotion; còn lệch nhiều thì lần sau xoay tiếp
			_over_threshold_time = 0.0
	else:
		# 2c) Đứng yên: chỉ xoay khi lệch quá ngưỡng đủ lâu
		if absf(diff) > deg_to_rad(max_twist_angle):
			_over_threshold_time += delta
		else:
			_over_threshold_time = 0.0
		if _over_threshold_time >= turn_delay:
			_start_turn(diff)

	# 3) Phần lệch còn lại giao cho thân trên
	var max_twist := deg_to_rad(max_twist_angle)
	twist = clampf(angle_difference(rotation.y, aim_yaw), -max_twist, max_twist)


## DỰ PHÒNG (chưa dùng): đổi file yaw sang Curve: X = thời gian (giây), Y = góc Spine (độ, + = trái).
## Animation (_yaw.res, Godot import từ Empty "TurnYaw" đã bake trong Blender — README Bước 18):
## lấy góc quanh trục Y của track "TurnYaw" ở từng frame, cộng dồn (clip 185° không nhảy dấu ±180°).
## Cách dùng: đổi export thành Array[Resource], rồi trong _ready:
##     for res in turn_curves: var c := _yaw_to_curve(res); if c: _turn_curves.append(c)
func _yaw_to_curve(res: Resource) -> Curve:
	if res is Curve:
		return res
	var anim := res as Animation
	var track := anim.find_track(YAW_TRACK, Animation.TYPE_ROTATION_3D) if anim else -1
	if track == -1:
		push_warning("%s: %s không phải Curve, cũng không có track xoay '%s'" % [name, res.resource_path if res else "null", YAW_TRACK])
		return null
	var curve := Curve.new()
	curve.min_value = -360.0      # đặt khoảng TRƯỚC khi thêm điểm (Curve kẹp điểm vào khoảng này)
	curve.max_value = 360.0
	curve.max_domain = anim.length
	var previous := anim.rotation_track_interpolate(track, 0.0).get_euler().y
	var total := 0.0
	for f in roundi(anim.length * YAW_SAMPLE_FPS) + 1:
		var time := minf(f / YAW_SAMPLE_FPS, anim.length)
		var yaw := anim.rotation_track_interpolate(track, time).get_euler().y
		total += angle_difference(previous, yaw)
		previous = yaw
		curve.add_point(Vector2(time, rad_to_deg(total)), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve


## Chọn clip có góc xoay gần góc lệch nhất (cùng chiều), chốt lại và bắt đầu xoay.
## Đang ngồi → chọn trong crouch_turn_curves và phát ở state CrouchTurn.
func _start_turn(diff: float) -> void:
	var wanted := rad_to_deg(diff)
	var best: Curve = null
	var best_angle := 0.0
	for curve in (crouch_turn_curves if is_crouching else _turn_curves):
		var angle := curve.sample(curve.max_domain)   # góc cuối = tổng góc Spine xoay trong clip
		if signf(angle) != signf(wanted):
			continue
		if best == null or absf(angle - wanted) < absf(best_angle - wanted):
			best = curve
			best_angle = angle
	if best == null:
		return
	_turn_curve = best
	_turn_time = 0.0
	_turn_start_yaw = rotation.y
	is_turning = true
	# Chốt state lúc bắt đầu: bấm ngồi/đứng giữa chừng thì clip xoay vẫn chạy hết
	_turn_state = &"CrouchTurn" if is_crouching else &"TurnInPlace"
	# BlendSpace1D ở chế độ Discrete: đặt đúng toạ độ điểm → phát đúng clip đó
	anim_tree.set(CROUCH_TURN_BLEND_PATH if is_crouching else TURN_BLEND_PATH, best_angle)


func _update_state_machine() -> void:
	# Đang xoay tại chỗ → state xoay (clip do _start_turn chọn), còn lại → Crouch / Locomotion
	var wanted := &"Locomotion"
	if is_turning:
		wanted = _turn_state
	elif is_crouching:
		wanted = &"Crouch"
	if wanted != _anim_state:
		_anim_state = wanted
		_playback.travel(wanted)


func _update_animation(delta: float) -> void:
	# Đổi vận tốc sang hệ toạ độ của thân: x = sang phải, −z = phía trước
	var local := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	# Chia cho tốc độ clip đi của tư thế hiện tại → điểm walk luôn nằm ở bán kính 1
	var target := Vector2(local.x, -local.z) / (crouch_speed if is_crouching else walk_speed)
	_blend = _blend.lerp(target.limit_length(run_speed / walk_speed), clampf(blend_smoothing * delta, 0.0, 1.0))
	anim_tree.set(BLEND_PATH, _blend)
	anim_tree.set(CROUCH_BLEND_PATH, _blend.limit_length(1.0))   # Crouch không có vòng sprint


func _update_spine_twist(delta: float) -> void:
	var weight := clampf(twist_smoothing * delta, 0.0, 1.0)
	_spine_twist.twist = lerp_angle(_spine_twist.twist, twist, weight)


func _update_lean(delta: float) -> void:
	# Đang sprint (giữ Shift và chạy nhanh hơn đi bộ) → không nghiêng
	var sprinting := is_running and Vector2(velocity.x, velocity.z).length() > walk_speed
	var direction := Vector3(lean_input.x, 0.0, lean_input.z).limit_length(1.0)
	var target := Vector3.ZERO if sprinting else direction * deg_to_rad(max_lean_angle)
	if is_crouching:
		target *= crouch_lean_scale
	# Làm mượt cả hướng lẫn độ lớn (đổi Q ↔ E thì người đi qua tư thế thẳng, không bật ngang)
	lean = lean.lerp(target, clampf(lean_smoothing * delta, 0.0, 1.0))
	_lean_modifier.lean = lean

## Nạp đạn (controller / AI gọi). Trả về true nếu bắt đầu nạp
func reload() -> bool:
	return weapon != null and weapon.reload()

## Truyền lệnh cho súng. Đang sprint thì không cho bắn.
func _update_weapon() -> void:
	if weapon == null:
		return
	var sprinting := is_running and Vector2(velocity.x, velocity.z).length() > walk_speed
	if sprinting and weapon.is_reloading:
		weapon.cancel_reload()           # chạy = hạ súng → huỷ nạp (đạn không đổi)	
	weapon.can_fire = not sprinting
	weapon.trigger = trigger
	weapon.aim_point = aim_point
	weapon.aim_at_point = aim_at_point
	weapon.fallback_direction = aim_direction


func _weapon_debug_text() -> String:
	if weapon == null or weapon.data == null:
		return "no weapon"
	var text := "ammo %d/%d | %d" % [weapon.ammo, weapon.data.magazine_size, weapon.reserve]
	if weapon.is_reloading:
		text += "  RELOAD %.1fs" % weapon.reload_time_left
	elif not weapon.can_fire:
		text += "  (sprint)"
	return text

# ---------- Nạp đạn: lớp thân trên ----------

## OneShot "Reload" chỉ tác động lên Spine và mọi xương con (lưng, vai, tay, ngón, cổ, đầu).
## Hông và chân vẫn theo state machine → vừa đi / ngồi / xoay vừa thay băng.
func _setup_upper_body_filter() -> void:
	var blend_tree := anim_tree.tree_root as AnimationNodeBlendTree
	if blend_tree == null or not blend_tree.has_node(&"Reload"):
		push_warning("%s: AnimationTree chưa có OneShot 'Reload' → không có animation nạp đạn" % name)
		return
	var one_shot := blend_tree.get_node(&"Reload")
	one_shot.filter_enabled = true
	var spine := skeleton.find_bone(&"Spine")
	for bone in skeleton.get_bone_count():
		var b := bone                                   # đi ngược lên cha xem có gặp Spine không
		while b >= 0 and b != spine:
			b = skeleton.get_bone_parent(b)
		one_shot.set_filter_path(NodePath("%GeneralSkeleton:" + skeleton.get_bone_name(bone)), b == spine)


func _on_reload_started(duration: float) -> void:
	# Co giãn clip cho vừa thời gian nạp của súng (clip 3.3 s, SCAR-L 2.5 s → phát nhanh 1.33 lần)
	var player := anim_tree.get_node(anim_tree.anim_player) as AnimationPlayer
	var clip: Animation = player.get_animation(reload_animation) if player.has_animation(reload_animation) else null
	anim_tree.set(RELOAD_SPEED_PATH, clip.length / duration if clip != null and duration > 0.0 else 1.0)
	anim_tree.set(RELOAD_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_fade_left_hand_ik(0.0)                             # tay trái rời ốp súng, đi theo clip (lấy băng)


func _on_reload_ended() -> void:
	anim_tree.set(RELOAD_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_fade_left_hand_ik(1.0)                             # tay trái về lại ốp súng


## Tắt / bật IK tay trái mượt bằng `influence` (1 = bám súng, 0 = theo animation)
func _fade_left_hand_ik(target: float) -> void:
	if _left_hand_ik == null:
		return
	if _ik_tween != null:
		_ik_tween.kill()
	_ik_tween = create_tween()
	_ik_tween.tween_property(_left_hand_ik, "influence", target, ik_fade_time)

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
	_debug_label.text = "body %4d°  aim %4d°\ntwist %+4d°  lean %2d°  %s\n%s" % [
		roundi(rad_to_deg(rotation.y)), roundi(rad_to_deg(aim_yaw)),
		roundi(rad_to_deg(twist)), roundi(rad_to_deg(lean.length())), _playback.get_current_node(),
		_weapon_debug_text()]
