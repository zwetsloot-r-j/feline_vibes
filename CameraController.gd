extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 5.0
@export var height: float = 10.0
@export var angle: float = 45.0  # Camera angle in degrees (0 = top-down, 90 = side view)
@export var distance: float = 8.0  # Distance behind the target when angled

var target_position: Vector3

func _ready():
	# Set up initial camera position and rotation for action RPG style
	if not target:
		# Try to find the player if no target is set
		target = get_parent() if get_parent() is CharacterBody3D else null
	
	if target:
		position = target.global_position + Vector3(0, height, distance)
		look_at(target.global_position, Vector3.UP)
	
	print("Camera controller ready!")

func _process(delta):
	if not target:
		return
	
	# Calculate target position based on player position
	var player_pos = target.global_position
	var angle_rad = deg_to_rad(angle)
	
	# For action RPG camera: slightly behind and above the character
	var offset = Vector3(0, height, distance * sin(angle_rad))
	target_position = player_pos + offset
	
	# Smoothly move camera to target position
	global_position = global_position.lerp(target_position, follow_speed * delta)
	
	# Always look at the player with slight downward angle
	var look_target = player_pos + Vector3(0, 1, 0)  # Look slightly above player's feet
	look_at(look_target, Vector3.UP)