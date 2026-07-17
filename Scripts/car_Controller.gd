extends VehicleBody3D

@export_category("Sensors")
@export var obsticle_check: Array[RayCast3D]
@export var ground_check: Array[RayCast3D]
@export var ground_sensor: RayCast3D

@export_category("Movement")
@export var motor_torque := 100.0
@export var max_speed := 40.0
@export var reverse_max_speed := 20.0
@export var brake_force := 200.0

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

@export_category("Obsticle")
@export var obsticle: Node3D
@export var obsticle_detect := false

var speed := 0.0

var move_input := 0.0
var turn_input := 0.0
var brake_input := 0.0

var move_dir := "Stop"
var turn_dir := "Straight"

var auto_drive := false
var turn := 0.0	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tab"):
		Canvas_layer.visible = !Canvas_layer.visible

	if event.is_action_pressed("drive_mode"):
		auto_drive = !auto_drive


func is_grounded() -> bool:
	for child in get_children():
		if child is VehicleWheel3D or child.get_class() == "VehicleWheel3D":
			if child.is_in_contact():
				return true
	if ground_sensor and ground_sensor.is_colliding():
		return true
	for ray in ground_check:
		if ray and ray.is_colliding():
			return true
	return false


func _physics_process(delta: float) -> void:
	if auto_drive:
		auto_drive_mode(delta)
	else:
		manual_drive_mode(delta)

	if not is_grounded():
		engine_force = 0.0
		apply_brake(delta)
		vehicle_turn(delta)
		update_speed()
		update_ui()
		return

	vehicle_movement()
	vehicle_turn(delta)
	apply_brake(delta)
	update_speed()
	update_ui()
	
	if obsticle != null:
		var direction := obsticle.global_position - global_position
		var look_dir := global_transform.basis.inverse() * direction.normalized()
		
		if look_dir.z < 0.0:
			obsticle = null
			obsticle_detect = false
			print("remove")

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
	
	brake_input = 0.0
	var ground_correction_applied := _detect()

	if not ground_correction_applied and not obsticle_detect:
		max_speed = 40.0
		if look_dir.z > 0.0:
			move_dir = "Forward"

			if look_dir.x > 0.1:
				turn_input = 1.0
				turn_dir = "Right"

			elif look_dir.x < -0.1:
				turn_input = -1.0
				turn_dir = "Left"

			else:
				turn_input = 0.0
				turn_dir = "Straight"

		else:
			move_dir = "Forward"

			if look_dir.x > 0.0:
				turn_input = 1.0
				turn_dir = "Right"
			else:
				turn_input = -1.0
				turn_dir = "Left"


# MANUAL MODE
func manual_drive_mode(delta: float) -> void:
	move_input = Input.get_axis("move_backward", "move_forward")
	turn_input = Input.get_axis("turn_left", "turn_right")
	brake_input = 1.0 if Input.is_action_pressed("brake") else 0.0

	if move_input > 0.0:
		move_dir = "Forward"
	elif move_input < 0.0:
		move_dir = "Backward"
	else:
		move_dir = "Stop"

	if turn_input > 0.0:
		turn_dir = "Right"
	elif turn_input < 0.0:
		turn_dir = "Left"
	else:
		turn_dir = "Straight"


func vehicle_movement() -> void:
	if move_input > 0.0:
		if speed < max_speed:
			engine_force = motor_torque
		else:
			engine_force = 0.0

	elif move_input < 0.0:
		if speed < reverse_max_speed:
			engine_force = - motor_torque
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


func apply_brake(delta: float) -> void:
	if brake_input > 0.0:
		brake = brake_force * delta
		engine_force = 0.0
	else:
		brake = 0.0


func _detect() -> bool:
	obsticle_detect = false
	var ground_correction := false
	var detected: Array[String] = []
	var distance: float = 0.0
	
	for ray in ground_check:
		if ray and not ray.is_colliding():
			if ray.name == "Left_check":
				turn_input = -1.0
				turn_dir = "Left"
				ground_correction = true
			elif ray.name == "Right_check":
				turn_input = 1.0
				turn_dir = "Right"
				ground_correction = true
	
	for ray in obsticle_check:
		if ray and ray.is_colliding():
			var object := ray.get_collider()
			if object.name == "Finish_Point":
				brake_input = 1.0
				break
			obsticle_detect = true
			if obsticle == null:
				obsticle = object
				print("Obsticle find")
			detected.append(ray.name)
			distance = ray.global_position.distance_to(ray.get_collision_point())
			
	if obsticle_detect:
		if not ground_correction:
			handle_turn(detected, distance)
		max_speed = 20.0
	elif ground_correction:
		max_speed = 20.0
		
	return ground_correction
	
func handle_turn(detect: Array[String], distance: float) -> void:
	var dir: String = ""
	
	if "Middle" in detect:
		dir = "Middle"
		if "Left" not in detect:
			turn_input = 1.0
			turn_dir = "Right"
		elif "Right" not in detect:
			turn_input = -1.0
			turn_dir = "Left"
		else:
			turn_input = [-1.0, 1.0].pick_random()
			turn_dir = "Left" if turn_input < 0.0 else "Right"
			
	elif "Left" in detect or "Middle_Left" in detect:
		dir = "Left"
		turn_input = -1.0
		turn_dir = "Left"
	elif "Right" in detect or "Middle_Right" in detect:
		dir = "Right"
		turn_input = 1.0
		turn_dir = "Right"
	else:
		turn_input = 0.0
		turn_dir = "Straight"
