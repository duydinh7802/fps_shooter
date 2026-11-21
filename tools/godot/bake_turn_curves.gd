@tool
extends EditorScript
## Chuyển đường cong xoay (đã bake trong Blender) thành Curve resource cho code nhân vật.
##
## Trong Blender, mỗi file turn có một Empty tên TurnYaw: Copy Rotation (chỉ Z) theo bone Spine,
## rồi Bake Action → keyframe góc xoay của Spine theo thời gian (xem được trong Graph Editor).
## Godot import Empty đó thành node "TurnYaw" có track xoay. Script này đọc track đó,
## lấy góc quanh trục Y ở từng frame, tạo Curve rồi lưu bằng ResourceSaver.
##
## Cách chạy: mở file này trong Script Editor → menu File → Run (Ctrl+Shift+X).

const SOURCE_DIR := "res://assets/characters/animations/humanoid/source/locomotion/turn/"
const OUTPUT_DIR := "res://assets/characters/animations/humanoid/turn_curves/"
const YAW_NODE := "TurnYaw"  ## tên Empty trong Blender = tên node/track trong Godot
const SAMPLE_FPS := 30.0     ## Mixamo 30 frame/giây → mỗi frame một điểm
const EXTENSION := "tres"    ## "tres" = văn bản (đọc được, diff được), "res" = nhị phân


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	for file in DirAccess.get_files_at(SOURCE_DIR):
		if file.get_extension() not in ["blend", "glb", "gltf", "fbx"]:
			continue
		var curve := bake(SOURCE_DIR + file)
		if curve == null:
			continue
		var out := OUTPUT_DIR + file.get_basename() + "_yaw." + EXTENSION
		var err := ResourceSaver.save(curve, out)
		print("[Bake Turn] %-22s %+7.1f°  %.3f s  %d điểm  → %s %s" % [
			file, curve.sample(curve.max_domain), curve.max_domain, curve.point_count, out,
			"" if err == OK else "LỖI %d" % err])
	EditorInterface.get_resource_filesystem().scan()   # cho dock FileSystem thấy file mới


## Đọc track TurnYaw trong scene `path`. Trả về Curve: X = thời gian (giây), Y = góc đã xoay (độ).
static func bake(path: String) -> Curve:
	var root: Node = (load(path) as PackedScene).instantiate()
	var player: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false).front()

	# 1) Tìm animation chứa track xoay của TurnYaw (cái có nhiều key nhất)
	var animation: Animation = null
	var track := -1
	if player:
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			var t := anim.find_track(NodePath(YAW_NODE), Animation.TYPE_ROTATION_3D)
			if t != -1 and (track == -1 or anim.track_get_key_count(t) > animation.track_get_key_count(track)):
				animation = anim
				track = t
	root.free()
	if track == -1 or animation.track_get_key_count(track) < 2:
		push_error("[Bake Turn] %s: không có track xoay của '%s' (chưa bake Empty trong Blender?)" % [path, YAW_NODE])
		return null

	# 2) Lấy mẫu từng frame: quaternion → góc quanh trục Y, cộng dồn (clip 185° không bị nhảy dấu)
	var points: Array[Vector2] = []
	var previous := 0.0
	var total := 0.0
	var frames := roundi(animation.length * SAMPLE_FPS)
	for f in frames + 1:
		var time := minf(f / SAMPLE_FPS, animation.length)
		var q := animation.rotation_track_interpolate(track, time)
		var yaw := q.get_euler().y
		if f > 0:
			total += angle_difference(previous, yaw)
		previous = yaw
		points.append(Vector2(time, rad_to_deg(total)))

	# 3) Tạo Curve. Đặt khoảng giá trị TRƯỚC khi thêm điểm, vì Curve kẹp điểm vào khoảng đó
	var low := 0.0
	var high := 0.0
	for p in points:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var curve := Curve.new()
	curve.min_value = floorf(low) - 1.0
	curve.max_value = ceilf(high) + 1.0
	curve.min_domain = 0.0
	curve.max_domain = animation.length              # code nhân vật đọc max_domain làm thời lượng xoay
	for p in points:
		curve.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve
