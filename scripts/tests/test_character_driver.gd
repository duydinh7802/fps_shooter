extends Node3D
## Chỉ để test Giai đoạn 2: WASD di chuyển, nhân vật luôn nhìn về −Z (lên trên màn hình).
## Giữ chuột phải: nhân vật nhìn sang phải (+X), để test animation đi ngang và đi lùi.

@onready var character: HumanoidCharacter = $SwatCharacter


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	character.move_input = Vector3(input.x, 0.0, input.y)
	character.aim_direction = Vector3.RIGHT if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else Vector3.FORWARD

