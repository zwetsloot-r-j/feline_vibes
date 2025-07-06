extends CharacterBody3D

@export var speed: float = 5.0
@export var dash_force: float = 15.0
@export var dash_duration: float = 0.3
@export var rotation_speed: float = 10.0

var gravity: float = 9.8
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

func _ready():
	print("Player controller ready!")

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle dash
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		# Start dash in current facing direction or movement direction
		var dash_dir = Vector3.ZERO
		
		# Get current input direction
		var input_dir = Vector2()
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1
		if Input.is_action_pressed("move_forward"):
			input_dir.y -= 1
		if Input.is_action_pressed("move_backward"):
			input_dir.y += 1
		
		if input_dir != Vector2.ZERO:
			# Dash in movement direction
			dash_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
		else:
			# Dash forward in facing direction
			dash_dir = -transform.basis.z
		
		dash_direction = dash_dir
		dash_timer = dash_duration
	
	# Update dash timer
	if dash_timer > 0.0:
		dash_timer -= delta
	
	# Get input direction for movement
	var input_dir = Vector2()
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	
	# Handle movement
	if dash_timer > 0.0:
		# Apply dash movement
		velocity.x = dash_direction.x * dash_force
		velocity.z = dash_direction.z * dash_force
	elif input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var direction = Vector3(input_dir.x, 0, input_dir.y)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Rotate character to face movement direction
		if direction.length() > 0:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 3)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 3)
	
	move_and_slide()