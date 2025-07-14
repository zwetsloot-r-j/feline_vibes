extends Node3D

@onready var voxel_generator = $VoxelGenerator

func _ready():
	print("Voxel World Controller ready!")
	print("Press 'R' to regenerate the world")
	print("Press 'P' to print performance stats")
	setup_fog_effect()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			print("Regenerating voxel world...")
			voxel_generator.regenerate_map()
		elif event.keycode == KEY_P:
			print("Printing performance stats...")
			voxel_generator.print_performance_summary()

func setup_fog_effect():
	# Create an Environment resource for fog
	var environment = Environment.new()
	
	# Enable edge-only distance fog
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color.WHITE  # Back to white for edges
	environment.fog_light_energy = 2.0
	environment.fog_sun_scatter = 0.5
	environment.fog_density = 10.0  # Strong but controlled density
	environment.fog_depth_begin = 25.0  # Clear area from 0-100 units
	environment.fog_depth_end = 50.0   # Full fog at 150+ units
	environment.fog_depth_curve = 2.0   # Moderate curve for smooth transition
	environment.fog_aerial_perspective = 0.3
	environment.fog_sky_affect = 0.8
	
	# Set up white background - try sky mode as well
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color.BLACK
	sky_material.sky_horizon_color = Color.BLACK
	sky_material.ground_bottom_color = Color.WHITE
	sky_material.ground_horizon_color = Color.BLACK
	environment.sky.sky_material = sky_material
	
	# Try volumetric fog (may not work with GL Compatibility)
	# Disable volumetric fog for testing basic fog
	environment.volumetric_fog_enabled = false
	environment.volumetric_fog_density = 0.15  # Increased for stronger effect
	environment.volumetric_fog_albedo = Color.WHITE
	environment.volumetric_fog_emission = Color.WHITE * 0.25  # More emission
	environment.volumetric_fog_emission_energy = 0.25
	environment.volumetric_fog_length = 200.0  # Longer range to match depth fog
   
	print("=== FOG TEST SETTINGS ===")
	print("Fog enabled: ", environment.fog_enabled)
	print("Fog mode: ", environment.fog_mode)
	print("Fog density: ", environment.fog_density)
	print("Fog color: ", environment.fog_light_color)
	print("=========================")
	
	# Apply the environment to the scene
	print("Looking for camera...")
	var camera = get_node_or_null("../CameraController")
	print("Camera found at ../CameraController: ", camera != null)
	
	if camera and camera is Camera3D:
		camera.environment = environment
		print("Fog effect applied to CameraController!")
	else:
		# Try different camera paths
		camera = get_node_or_null("CameraController")
		if camera and camera is Camera3D:
			camera.environment = environment
			print("Fog effect applied to CameraController (direct path)!")
		else:
			# Search for any Camera3D in the scene tree
			var all_nodes = get_tree().get_nodes_in_group("_auto_group_Camera3D") 
			if all_nodes.is_empty():
				# Manual search
				all_nodes = []
				_find_cameras_recursive(get_tree().root, all_nodes)
			
			if all_nodes.size() > 0:
				var found_camera = all_nodes[0]
				found_camera.environment = environment
				print("Fog effect applied to found camera: ", found_camera.name)
			else:
				print("Warning: No Camera3D nodes found in scene tree!")

func _find_cameras_recursive(node: Node, camera_list: Array):
	if node is Camera3D:
		camera_list.append(node)
	for child in node.get_children():
		_find_cameras_recursive(child, camera_list)
