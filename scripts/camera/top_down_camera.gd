class_name TopDownCamera
extends Node3D
## Rig camera top-down: bám theo vị trí của target, không xoay theo target.
## Camera3D là con của node này, đặt lệch lên cao và chúc xuống.

@export var target: Node3D            ## nhân vật cần bám theo
@export var follow_speed := 8.0       ## càng lớn bám càng sát, càng nhỏ càng "trễ" mượt


func _ready() -> void:
	if target:
		global_position = target.global_position  # vào game là đứng ngay trên nhân vật, không trượt từ xa tới


func _process(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, weight)
