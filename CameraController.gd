extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 5.0
@export var fixed_distance: float = 6.0  # Fixed distance from character in world space
@export var height_offset: float = 10.0  # Height above character for top-down view

var target_position: Vector3

func _ready():
	# Set up initial camera position
	if not target:
		# Try to find the player node in the scene
		var parent = get_parent()
		if parent:
			target = parent.get_node_or_null("Player")

func _process(delta):
	if not target:
		return
	
	# Calculate camera position at fixed distance from character
	var player_pos = target.global_position
	
	# Calculate position using fixed world-space offset independent of character rotation
	# This creates a consistent camera position regardless of character facing direction
	var world_offset = Vector3(0, height_offset, fixed_distance)
	target_position = player_pos + world_offset
	
	# Update camera position every frame to maintain exact fixed distance
	# Use lerp for smooth following, or direct assignment for instant positioning
	if follow_speed > 0:
		global_position = global_position.lerp(target_position, follow_speed * delta)
	else:
		global_position = target_position
	
	# Always look at the character to keep it in view
	look_at(player_pos, Vector3.UP)
