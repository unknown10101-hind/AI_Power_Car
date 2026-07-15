extends VehicleBody3D

@export_category("Sensors")
@export var rays: Array[RayCast3D]
@export var ground_sensor: RayCast3D

@export_category("Movement")
@export var motor_torque := 200.0
@export var max_speed := 40.0
@export var reverse_max_speed := 20.0
@export var brake_force := 100.0

@export_category("Steering")
@export var max_turn_angle := deg_to_rad(30.0)
@export var turn_speed := 5.0

@export_category("UI")
@export var Canvas_layer: CanvasLayer
@export var speed_text: Label
@export var look_dir_text: Label
@export var direction_text: Label
@export var drive_mode: Label

@export_category("Target")
@export var target: StaticBody3D

var speed := 0.0

var move_input := 0.0
var turn_input := 0.0
var brake_input := 0.0

var move_dir := "Stop"
var turn_dir := "Straight"

var auto_drive := false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tab"):
		Canvas_layer.visible = !Canvas_layer.visible

	if event.is_action_pressed("drive_mode"):
		auto_drive = !auto_drive


func _physics_process(delta: float) -> void:
	
	vehicle_movement()
	vehicle_turn(delta)
	update_speed()
	update_ui()
	apply_brake()
	if ground_sensor == null or !ground_sensor.is_colliding():
		engine_force = 0.0
		return

	if auto_drive:
		auto_drive_mode(delta)
	else:
		manual_drive_mode(delta)


func update_speed() -> void:
	speed = linear_velocity.length() * 3.6


func update_ui() -> void:

	if speed_text:
		speed_text.text = "Speed: %d KM/H" % roundi(speed)

	if direction_text:
		direction_text.text = "Direction: %s, %s" % [move_dir, turn_dir]

	if drive_mode:
		drive_mode.text = "Drive Mode: " + ("Auto" if auto_drive else "Manual")


# AUTO MODE
func auto_drive_mode(delta: float) -> void:

	move_input = 1.0
	
	if target == null:
		return

	var direction := target.global_position - global_position
	var look_dir := global_transform.basis.inverse() * direction.normalized()

	if look_dir_text:
		look_dir_text.text = "X: %.2f, Z: %.2f" % [look_dir.x, look_dir.z]

	if look_dir.z > 0.0:

		move_dir = "Forward"

		if look_dir.x > 0.1:
			turn_input = 1.0
			turn_dir = "Left"

		elif look_dir.x < -0.1:
			turn_input = -1.0
			turn_dir = "Right"

		else:
			turn_input = 0.0
			turn_dir = "Straight"

	else:

		move_dir = "Forward"

		if look_dir.x > 0:
			turn_input = 1.0
			turn_dir = "Left"
		else:
			turn_input = -1.0
			turn_dir = "Right"
	_detect()


# MANUAL MODE
func manual_drive_mode(delta: float) -> void:

	move_input = Input.get_axis("move_backward", "move_forward")
	turn_input = Input.get_axis("turn_right", "turn_left")

	var target_steering = max_turn_angle * turn_input

	steering = move_toward(
		steering,
		target_steering,
		turn_speed * delta
	)

	if move_input > 0:
		move_dir = "Forward"
	elif move_input < 0:
		move_dir = "Backward"
	else:
		move_dir = "Stop"

	if turn_input > 0:
		turn_dir = "Left"
	elif turn_input < 0:
		turn_dir = "Right"
	else:
		turn_dir = "Straight"


func vehicle_movement() -> void:

	if move_input > 0.0:
		if speed < max_speed:
			engine_force = motor_torque
		else:
			engine_force = 0.0 

	elif move_input < 0.0:
		if speed > -reverse_max_speed:
			engine_force = -motor_torque
		else:
			engine_force = 0.0

	else:
		engine_force = 0.0


func vehicle_turn(delta: float) -> void:

	var target_steering := max_turn_angle * turn_input

	steering = move_toward(
		steering,
		target_steering,
		turn_speed * delta
	)


func apply_brake() -> void:
	if brake_input > 0.0:
		brake = brake_force * brake_input
		engine_force = 0.0
	else:
		brake = 0.0


func _detect() -> void:

	var detected := []

	for ray in rays:
		if ray and ray.is_colliding():
			detected.append(ray.name)
	
	brake_input = 1.0
	
	if "Middle" in detected:
		print("Middle")
	elif "Left" in detected or "Middle_Left" in detected:
		print("Left")
	elif "Right" in detected or "Middle_Right" in detected:
		print("Right")

		
