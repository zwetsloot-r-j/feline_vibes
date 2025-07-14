extends CharacterBody3D

@export var speed: float = 5.0
@export var dash_force: float = 15.0
@export var dash_duration: float = 0.3
@export var rotation_speed: float = 10.0
@export var step_height: float = 1.3  # Slightly higher than voxel size (1.2)
@export var step_check_distance: float = 0.8  # How far ahead to check for steps

var gravity: float = 9.8
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var voxel_skeleton: VoxelSkeleton
var map_generation_complete: bool = false

func _ready():
	print("Player controller ready!")
	setup_voxel_character()
	connect_to_map_generator()

func _physics_process(delta):
	# Only apply gravity after map generation is complete
	if map_generation_complete and not is_on_floor():
		velocity.y -= gravity * delta
	elif not map_generation_complete:
		# Debug output to see if gravity is being skipped
		if velocity.y != 0:
			print("DEBUG: Gravity disabled, resetting Y velocity from ", velocity.y, " to 0")
			velocity.y = 0  # Force Y velocity to 0 while waiting
	
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
	
	# Apply step-up functionality before moving
	if is_on_floor() and velocity.length() > 0:
		attempt_step_up()
	
	# Only process movement if map generation is complete or if on the ground
	if map_generation_complete or is_on_floor():
		move_and_slide()
	else:
		# Ensure player doesn't move while waiting for map generation
		velocity = Vector3.ZERO

func attempt_step_up():
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() < 0.1:
		return
	
	var move_direction = horizontal_velocity.normalized()
	var space_state = get_world_3d().direct_space_state
	
	# Debug movement direction
	var direction_name = get_direction_name(move_direction)
	
	# Use a more aggressive approach - check ground level directly ahead
	var check_distance = step_check_distance * 1.5  # Look further ahead
	var target_position = global_position + move_direction * check_distance
	
	# Check ground level at target position
	var ground_check_start = target_position + Vector3(0, step_height, 0)
	var ground_check_end = target_position + Vector3(0, -step_height, 0)
	
	var ground_query = PhysicsRayQueryParameters3D.create(ground_check_start, ground_check_end)
	ground_query.exclude = [self]
	var ground_result = space_state.intersect_ray(ground_query)
	
	if not ground_result:
		# Try checking closer if no ground found
		target_position = global_position + move_direction * (check_distance * 0.5)
		ground_check_start = target_position + Vector3(0, step_height, 0)
		ground_check_end = target_position + Vector3(0, -step_height, 0)
		
		ground_query = PhysicsRayQueryParameters3D.create(ground_check_start, ground_check_end)
		ground_query.exclude = [self]
		ground_result = space_state.intersect_ray(ground_query)
		
		if not ground_result:
			return  # Still no ground found
	
	var target_ground_height = ground_result.position.y
	var current_ground_height = global_position.y
	var step_up_height = target_ground_height - current_ground_height
	
	# Step up if it's a reasonable height (positive and within limit)
	if step_up_height > 0.1 and step_up_height <= step_height:
		# Simple clearance check - just make sure character fits
		var clearance_start = Vector3(target_position.x, target_ground_height + 0.1, target_position.z)
		var clearance_end = clearance_start + Vector3(0, 2.0, 0)  # Character height check
		
		var clearance_query = PhysicsRayQueryParameters3D.create(clearance_start, clearance_end)
		clearance_query.exclude = [self]
		var clearance_result = space_state.intersect_ray(clearance_query)
		
		if not clearance_result:  # No ceiling blocking
			# Move the character up smoothly
			global_position.y = target_ground_height + 0.1

func get_direction_name(direction: Vector3) -> String:
	var abs_x = abs(direction.x)
	var abs_z = abs(direction.z)
	
	if abs_x > abs_z:
		return "EAST" if direction.x > 0 else "WEST"
	else:
		return "SOUTH" if direction.z > 0 else "NORTH"

func setup_voxel_character():
	# Remove the existing CharacterSkin if it exists
	var existing_skin = get_node_or_null("CharacterSkin")
	if existing_skin:
		existing_skin.queue_free()
	
	# Create and add VoxelSkeleton
	voxel_skeleton = VoxelSkeleton.new()
	add_child(voxel_skeleton)
	
	# Load our saved cat model
	var model_path = "res://models/cat_001.json"
	if FileAccess.file_exists(model_path):
		if voxel_skeleton.load_skeleton_from_file(model_path):
			print("Successfully loaded cat model!")
			# Scale down the model to fit better with the player
			voxel_skeleton.scale = Vector3(0.25, 0.25, 0.25)
			# Rotate 180 degrees around Y-axis to align front/back with movement direction
			voxel_skeleton.rotation.y = PI
		else:
			print("Failed to load cat model, creating default")
			create_default_character()
	else:
		print("Cat model not found, creating default")
		create_default_character()

func create_default_character():
	# Fallback: create a simple default character if cat model isn't available
	var part = VoxelPart.new()
	part.part_name = "body"
	part.add_voxel(Vector3i(0, 0, 0), Color.BLUE)
	part.add_voxel(Vector3i(0, 1, 0), Color.BLUE)
	voxel_skeleton.add_part(part)
	voxel_skeleton.set_root_part(part)

func connect_to_map_generator():
	# Find the VoxelGenerator and connect to its signal
	var voxel_generator = get_node_or_null("../VoxelGenerator")
	print("DEBUG: Looking for VoxelGenerator at ../VoxelGenerator: ", voxel_generator != null)
	
	if voxel_generator:
		voxel_generator.initial_map_generation_complete.connect(_on_map_generation_complete)
		print("DEBUG: Player connected to VoxelGenerator signals")
		print("DEBUG: Initial generation already complete? ", voxel_generator.initial_generation_complete)
		print("DEBUG: Player gravity disabled until map generation complete")
		
		# Check if generation is already complete (in case player loads after)
		if voxel_generator.initial_generation_complete:
			_on_map_generation_complete()
	else:
		print("WARNING: VoxelGenerator not found, enabling gravity immediately")
		map_generation_complete = true

func _on_map_generation_complete():
	print("Map generation complete - enabling player gravity!")
	map_generation_complete = true
	
	# If player is above ground level due to delayed gravity, give a small downward velocity
	if global_position.y > 25:  # Above typical ground level
		velocity.y = -2.0  # Small downward push to start falling
