extends Camera3D

## The node this camera follows and looks at.
@export var target: Node3D

@export_group("Follow")
@export var follow_speed := 5.0
@export var height := 4.0
@export var distance := 7.0

@export_group("Look")
@export var look_height := 1.0
@export var rotation_speed := 5.0


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var target_position := (
		target.global_position
		+ target.global_transform.basis.z * distance
		+ Vector3.UP * height
	)

	global_position = global_position.lerp(
		target_position,
		minf(follow_speed * delta, 1.0)
	)

	var look_target := target.global_position + Vector3.UP * look_height
	var desired_transform := global_transform.looking_at(look_target, Vector3.UP)

	global_transform.basis = global_transform.basis.slerp(
		desired_transform.basis,
		minf(rotation_speed * delta, 1.0)
	)
