@tool
extends EditorScenePostImport
## Import Script cho clip xoay tại chỗ của Mixamo (FBX / GLB / BLEND), không cần qua Blender.
##
## Gắn vào file ở dock Import → Import Script → Path, rồi bấm Reimport. Khi Godot import xong
## (đã retarget sang tên bone chuẩn bằng BoneMap), script:
##   1) Đo hướng bone Spine ở từng frame (quanh trục đứng), cộng dồn thành góc xoay theo thời gian.
##   2) Lưu đường cong đó thành Curve:   turn_curves/<tên file>_yaw.tres
##   3) Xoay ngược Hips đúng góc đó quanh trục đứng đi qua gốc → Spine đứng yên trong clip,
##      bước chân giữ nguyên.  Lưu clip:  clips/turn/<tên file>.res
## Trong game, code nhân vật xoay CharacterBody3D theo curve → trục nhân vật xoay cùng Spine.
##
## Đặt tên file nguồn đúng tên clip muốn có, ví dụ turn_right_180.fbx.

const CLIP_DIR := "res://assets/characters/animations/humanoid/clips/turn/"
const CURVE_DIR := "res://assets/characters/animations/humanoid/turn_curves/"
const ROOT_BONE := "Hips"         ## bone gốc: xoay bone này = xoay cả bộ xương
const REFERENCE_BONE := "Spine"   ## bone làm mốc hướng nhân vật
const SAMPLE_FPS := 30.0          ## Mixamo 30 frame/giây → mỗi frame một mẫu


func _post_import(scene: Node) -> Object:
	var clip_name := get_source_file().get_file().get_basename()
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false).front()
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false).front()
	if player == null or skeleton == null:
		push_error("[Turn Import] %s: không có AnimationPlayer / Skeleton3D" % clip_name)
		return scene
	var names := Array(player.get_animation_list()).filter(func(n): return n != "RESET")
	if names.is_empty():
		push_error("[Turn Import] %s: không có animation" % clip_name)
		return scene
	var root := skeleton.find_bone(ROOT_BONE)
	var reference := skeleton.find_bone(REFERENCE_BONE)
	if root == -1 or reference == -1:
		push_error("[Turn Import] %s: không thấy bone %s / %s. Đã gán BoneMap (Retarget) chưa?" % [clip_name, ROOT_BONE, REFERENCE_BONE])
		return scene

	var animation: Animation = player.get_animation(names[0]).duplicate(true)
	var skeleton_path := _skeleton_track_prefix(animation, skeleton, root)
	var rot_track := animation.find_track(NodePath(skeleton_path + ":" + ROOT_BONE), Animation.TYPE_ROTATION_3D)
	var pos_track := animation.find_track(NodePath(skeleton_path + ":" + ROOT_BONE), Animation.TYPE_POSITION_3D)
	if rot_track == -1:
		push_error("[Turn Import] %s: không có track xoay của %s" % [clip_name, ROOT_BONE])
		return scene

	# Hướng "lên" trong hệ toạ độ của skeleton (thường đúng là Vector3.UP)
	var skeleton_basis := _node_basis_to_scene(skeleton, scene)
	var up := (skeleton_basis.inverse() * Vector3.UP).normalized()

	# ---------- 1) Đo góc Spine từng frame (trên clip GỐC) ----------
	var frames := roundi(animation.length * SAMPLE_FPS)
	var times: Array[float] = []
	var angles: Array[float] = []      # radian, cộng dồn so với frame đầu
	var previous := 0.0
	var total := 0.0
	for f in frames + 1:
		var time := minf(f / SAMPLE_FPS, animation.length)
		var spine_basis := skeleton_basis * _bone_basis(animation, skeleton, skeleton_path, reference, time)
		var side := spine_basis * Vector3.RIGHT              # trục ngang của Spine (vai ↔ vai)
		var yaw := atan2(-side.z, side.x)                     # cùng dấu với rotation.y: + = trái
		if f > 0:
			total += angle_difference(previous, yaw)
		previous = yaw
		times.append(time)
		angles.append(total)

	# ---------- 2) Lưu Curve ----------
	var curve := _make_curve(times, angles, animation.length)
	DirAccess.make_dir_recursive_absolute(CURVE_DIR)
	var curve_path := CURVE_DIR + clip_name + "_yaw.tres"
	ResourceSaver.save(curve, curve_path)

	# ---------- 3) Xoay ngược Hips quanh trục đứng qua gốc skeleton ----------
	# Ghi lại track Hips dày đặc 30 frame/giây: lấy giá trị gốc ở từng frame, xoay ngược, ghi đè.
	var rotations: Array[Quaternion] = []
	var positions: Array[Vector3] = []
	for i in times.size():
		rotations.append(animation.rotation_track_interpolate(rot_track, times[i]))
		if pos_track != -1:
			positions.append(animation.position_track_interpolate(pos_track, times[i]))
	_clear_keys(animation, rot_track)
	if pos_track != -1:
		_clear_keys(animation, pos_track)
	for i in times.size():
		var unturn := Quaternion(up, -angles[i])
		animation.rotation_track_insert_key(rot_track, times[i], (unturn * rotations[i]).normalized())
		if pos_track != -1:
			animation.position_track_insert_key(pos_track, times[i], unturn * positions[i])
	animation.loop_mode = Animation.LOOP_NONE

	DirAccess.make_dir_recursive_absolute(CLIP_DIR)
	var clip_path := CLIP_DIR + clip_name + ".res"
	ResourceSaver.save(animation, clip_path)

	print("[Turn Import] %s: Spine xoay %+.1f° (%s) trong %.3f s → %s, %s" % [
		clip_name, rad_to_deg(total), "TRÁI" if total > 0.0 else "PHẢI", animation.length, clip_path, curve_path])
	return scene


## Hướng (basis) của bone trong hệ skeleton ở thời điểm `time`: nhân xoay của bone với mọi bone cha.
## Bone nào có track xoay thì lấy từ track, không có thì lấy tư thế nghỉ (rest).
func _bone_basis(animation: Animation, skeleton: Skeleton3D, prefix: String, bone: int, time: float) -> Basis:
	var result := Basis.IDENTITY
	while bone != -1:
		var track := animation.find_track(NodePath(prefix + ":" + skeleton.get_bone_name(bone)), Animation.TYPE_ROTATION_3D)
		var q := animation.rotation_track_interpolate(track, time) if track != -1 else skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		result = Basis(q) * result
		bone = skeleton.get_bone_parent(bone)
	return result


## Phần đường dẫn trước dấu ":" của track bone, ví dụ "%GeneralSkeleton" hoặc "Skeleton3D".
func _skeleton_track_prefix(animation: Animation, skeleton: Skeleton3D, bone: int) -> String:
	var bone_name := skeleton.get_bone_name(bone)
	for i in animation.get_track_count():
		var path := animation.track_get_path(i)
		if path.get_subname_count() > 0 and path.get_subname(0) == bone_name:
			return str(path).get_slice(":", 0)
	return "%" + skeleton.name


## Xoay của node so với gốc scene (scene chưa nằm trong tree nên tự nhân các transform cha).
func _node_basis_to_scene(node: Node, scene: Node) -> Basis:
	var result := Basis.IDENTITY
	while node != null and node != scene:
		if node is Node3D:
			result = (node as Node3D).basis.orthonormalized() * result
		node = node.get_parent()
	return result


func _make_curve(times: Array[float], angles: Array[float], length: float) -> Curve:
	var low := 0.0
	var high := 0.0
	for a in angles:
		low = minf(low, rad_to_deg(a))
		high = maxf(high, rad_to_deg(a))
	var curve := Curve.new()
	# Đặt khoảng giá trị TRƯỚC khi thêm điểm, vì Curve kẹp điểm vào khoảng đó
	curve.min_value = floorf(low) - 1.0
	curve.max_value = ceilf(high) + 1.0
	curve.min_domain = 0.0
	curve.max_domain = length              # code nhân vật đọc max_domain làm thời lượng xoay
	for i in times.size():
		curve.add_point(Vector2(times[i], rad_to_deg(angles[i])), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve


func _clear_keys(animation: Animation, track: int) -> void:
	for k in range(animation.track_get_key_count(track) - 1, -1, -1):
		animation.track_remove_key(track, k)
