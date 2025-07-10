extends Node3D

@onready var voxel_skeleton = $VoxelSkeleton
@onready var animation_system = $VoxelSkeleton/VoxelAnimationSystem
@onready var constraint_system = $VoxelSkeleton/VoxelConstraintSystem

@onready var entity_label = $UI/VBoxContainer/EntityTypeLabel
@onready var animation_label = $UI/VBoxContainer/AnimationLabel
@onready var file_dialog = $UI/FileDialog

@onready var humanoid_btn = $UI/VBoxContainer/EntityButtons/HumanoidBtn
@onready var quadruped_btn = $UI/VBoxContainer/EntityButtons/QuadrupedBtn
@onready var bird_btn = $UI/VBoxContainer/EntityButtons/BirdBtn

@onready var idle_btn = $UI/VBoxContainer/AnimationButtons/IdleBtn
@onready var walk_btn = $UI/VBoxContainer/AnimationButtons/WalkBtn
@onready var run_btn = $UI/VBoxContainer/AnimationButtons/RunBtn

@onready var import_btn = $UI/VBoxContainer/ImportBtn

var current_entity_type: VoxelSkeleton.EntityType = VoxelSkeleton.EntityType.HUMANOID
var last_imported_file: String = ""

# Camera control variables
var camera_distance: float = 10.0
var camera_angle_h: float = 0.0
var camera_angle_v: float = 30.0
var camera_target: Vector3 = Vector3.ZERO
var mouse_sensitivity: float = 0.5
var zoom_speed: float = 2.0
var is_rotating: bool = false

func _ready():
	setup_ui_connections()
	create_initial_skeleton()
	setup_camera_controls()
	print("Voxel Animation System Example Ready!")
	print("Use the UI buttons to switch between entity types and animations")
	print("You can also import OBJ files to create custom voxel entities")
	print("Camera controls: Right-click + drag to rotate, scroll wheel to zoom")

func setup_ui_connections():
	humanoid_btn.pressed.connect(_on_humanoid_pressed)
	quadruped_btn.pressed.connect(_on_quadruped_pressed)
	bird_btn.pressed.connect(_on_bird_pressed)
	
	idle_btn.pressed.connect(_on_idle_pressed)
	walk_btn.pressed.connect(_on_walk_pressed)
	run_btn.pressed.connect(_on_run_pressed)
	
	import_btn.pressed.connect(_on_import_pressed)
	
	# Add batch import button
	var batch_btn = Button.new()
	batch_btn.text = "Load Multiple OBJ Files"
	batch_btn.pressed.connect(_on_batch_import_pressed)
	$UI/VBoxContainer.add_child(batch_btn)
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.files_selected.connect(_on_files_selected)
	
	animation_system.animation_started.connect(_on_animation_started)
	animation_system.animation_finished.connect(_on_animation_finished)
	constraint_system.constraint_violated.connect(_on_constraint_violated)

func setup_camera_controls():
	# Add camera control UI
	var camera_controls = VBoxContainer.new()
	var camera_label = Label.new()
	camera_label.text = "Camera Controls: (Right-click + drag to rotate, wheel to zoom)"
	camera_controls.add_child(camera_label)
	
	var zoom_controls = HBoxContainer.new()
	var zoom_out_btn = Button.new()
	zoom_out_btn.text = "Zoom Out"
	zoom_out_btn.pressed.connect(_on_zoom_out)
	var zoom_in_btn = Button.new()
	zoom_in_btn.text = "Zoom In"
	zoom_in_btn.pressed.connect(_on_zoom_in)
	var reset_btn = Button.new()
	reset_btn.text = "Reset View"
	reset_btn.pressed.connect(_on_reset_camera)
	
	zoom_controls.add_child(zoom_out_btn)
	zoom_controls.add_child(zoom_in_btn)
	zoom_controls.add_child(reset_btn)
	camera_controls.add_child(zoom_controls)
	
	$UI/VBoxContainer.add_child(camera_controls)
	
	# Create a transparent input area that covers the viewport for camera controls
	var input_area = ColorRect.new()
	input_area.color = Color(0, 0, 0, 0)  # Transparent
	input_area.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse events to pass through
	input_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(input_area)
	$UI.move_child(input_area, 0)  # Move to back so UI elements are on top
	
	# Connect mouse events to this input area
	input_area.gui_input.connect(_on_input_area_input)
	
	# Set initial camera position
	update_camera_position()

func _on_input_area_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(camera_distance - zoom_speed, 2.0)
			update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(camera_distance + zoom_speed, 100.0)
			update_camera_position()
	
	elif event is InputEventMouseMotion and is_rotating:
		camera_angle_h += event.relative.x * mouse_sensitivity
		camera_angle_v = clamp(camera_angle_v - event.relative.y * mouse_sensitivity, -80.0, 80.0)
		update_camera_position()

func update_camera_position():
	var camera = $Camera3D
	if not camera:
		return
		
	var rad_h = deg_to_rad(camera_angle_h)
	var rad_v = deg_to_rad(camera_angle_v)
	
	var x = camera_distance * cos(rad_v) * sin(rad_h)
	var y = camera_distance * sin(rad_v)
	var z = camera_distance * cos(rad_v) * cos(rad_h)
	
	camera.position = camera_target + Vector3(x, y, z)
	camera.look_at(camera_target, Vector3.UP)

func _on_zoom_out():
	camera_distance = min(camera_distance * 1.5, 100.0)
	update_camera_position()

func _on_zoom_in():
	camera_distance = max(camera_distance / 1.5, 2.0)
	update_camera_position()

func _on_reset_camera():
	camera_distance = 10.0
	camera_angle_h = 0.0
	camera_angle_v = 30.0
	camera_target = Vector3.ZERO
	update_camera_position()

func create_initial_skeleton():
	create_skeleton_for_entity_type(VoxelSkeleton.EntityType.HUMANOID)

func create_skeleton_for_entity_type(entity_type: VoxelSkeleton.EntityType):
	current_entity_type = entity_type
	
	var template: EntityTemplate
	match entity_type:
		VoxelSkeleton.EntityType.HUMANOID:
			template = EntityTemplate.create_humanoid_template()
			entity_label.text = "Entity Type: Humanoid"
		VoxelSkeleton.EntityType.QUADRUPED:
			template = EntityTemplate.create_quadruped_template()
			entity_label.text = "Entity Type: Quadruped"
		VoxelSkeleton.EntityType.BIRD:
			template = EntityTemplate.create_bird_template()
			entity_label.text = "Entity Type: Bird"
	
	if template and template.validate_template():
		voxel_skeleton.create_skeleton_from_template(template)
		animation_system.skeleton = voxel_skeleton
		constraint_system.skeleton = voxel_skeleton
		
		animation_system.create_default_animations_for_entity_type(entity_type)
		
		constraint_system.setup_default_constraints_for_entity_type(entity_type)
		
		if entity_type == VoxelSkeleton.EntityType.HUMANOID:
			constraint_system.create_gait_pattern("walk", entity_type)
			constraint_system.create_gait_pattern("run", entity_type)
		elif entity_type == VoxelSkeleton.EntityType.QUADRUPED:
			constraint_system.create_gait_pattern("walk", entity_type)
			constraint_system.create_gait_pattern("gallop", entity_type)
		elif entity_type == VoxelSkeleton.EntityType.BIRD:
			constraint_system.create_gait_pattern("fly", entity_type)
		
		print("Created ", template.template_name, " skeleton with ", template.part_definitions.size(), " parts")
		
		# animation_system.play_animation("idle", true)  # Disabled to test positioning
	else:
		push_error("Failed to create valid template for entity type: " + str(entity_type))

func _on_humanoid_pressed():
	create_skeleton_for_entity_type(VoxelSkeleton.EntityType.HUMANOID)

func _on_quadruped_pressed():
	create_skeleton_for_entity_type(VoxelSkeleton.EntityType.QUADRUPED)

func _on_bird_pressed():
	create_skeleton_for_entity_type(VoxelSkeleton.EntityType.BIRD)

func _on_idle_pressed():
	animation_system.play_animation("idle", true)

func _on_walk_pressed():
	animation_system.play_animation("walk", true)

func _on_run_pressed():
	var animation_name = "run"
	if current_entity_type == VoxelSkeleton.EntityType.QUADRUPED:
		animation_name = "gallop"
	elif current_entity_type == VoxelSkeleton.EntityType.BIRD:
		animation_name = "fly"
	
	animation_system.play_animation(animation_name, true)

func _on_import_pressed():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()

func _on_batch_import_pressed():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	print("Loading OBJ file: ", path)
	last_imported_file = path
	load_obj_file(path)

func _on_files_selected(paths: PackedStringArray):
	print("Loading multiple OBJ files: ", paths)
	load_multiple_obj_files(paths)

func load_obj_file(file_path: String):
	print("Loading OBJ file: ", file_path)
	
	var obj_data = VoxelMeshLoader.load_obj_file(file_path)
	print("OBJ data loaded - vertices: ", obj_data.get("vertices", []).size(), " faces: ", obj_data.get("faces", []).size())
	
	if obj_data.is_empty():
		print("ERROR: Failed to load OBJ data")
		return
	
	# Convert with fixed 0.1 voxel size
	var best_voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, true)
	var best_voxel_count = 0
	for part_name in best_voxel_parts:
		best_voxel_count += best_voxel_parts[part_name].size()
	
	print("Using voxel size: 0.1")
	print("Voxel conversion complete - parts: ", best_voxel_parts.keys())
	for part_name in best_voxel_parts:
		print("  Part '", part_name, "': ", best_voxel_parts[part_name].size(), " voxels")
	
	var template = VoxelMeshLoader.create_entity_template_from_obj(
		file_path, 
		"ImportedModel", 
		current_entity_type
	)
	
	if template and template.validate_template():
		print("Template created successfully with ", template.part_definitions.size(), " parts")
		
		voxel_skeleton.create_skeleton_from_template(template)
		animation_system.skeleton = voxel_skeleton
		constraint_system.skeleton = voxel_skeleton
		
		animation_system.create_default_animations_for_entity_type(current_entity_type)
		constraint_system.setup_default_constraints_for_entity_type(current_entity_type)
		
		print("Successfully imported OBJ file with ", template.part_definitions.size(), " parts")
		
		# Move camera to see the imported model
		var camera = get_node("Camera3D")
		if camera:
			camera.position = Vector3(0, 5, 10)
			camera.look_at(Vector3.ZERO, Vector3.UP)
		
		# animation_system.play_animation("idle", true)  # Disabled to test positioning
	else:
		push_error("Failed to import OBJ file: " + file_path)

func load_multiple_obj_files(file_paths: PackedStringArray):
	print("Loading multiple OBJ files...")
	
	var template = EntityTemplate.new()
	template.template_name = "BatchImported"
	template.entity_type = current_entity_type
	
	# Use fixed 0.1 voxel size for batch imports
	var part_positions = {}
	
	for file_path in file_paths:
		var filename = file_path.get_file().get_basename()
		var part_name = map_filename_to_part_name(filename)
		
		print("Processing file: ", filename, " -> part: ", part_name)
		
		var obj_data = VoxelMeshLoader.load_obj_file(file_path)
		if obj_data.is_empty():
			print("ERROR: Failed to load ", file_path)
			continue
			
		print("  OBJ vertices: ", obj_data.vertices.size(), " faces: ", obj_data.faces.size())
		if obj_data.vertices.size() > 0:
			print("    First few vertices: ", obj_data.vertices.slice(0, min(4, obj_data.vertices.size())))
		
		var voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, false)
		if "main" in voxel_parts and voxel_parts["main"].size() > 0:
			var part_type = guess_part_type_from_name(part_name)
			var colors = []
			for i in range(voxel_parts["main"].size()):
				colors.append(get_color_for_part_type(part_type))
			
			template.add_part_definition(part_name, part_type, voxel_parts["main"], colors, 
										Vector3.ZERO, part_name == "torso" or part_name == "body")
			
			print("  Added part '", part_name, "' with ", voxel_parts["main"].size(), " voxels")
			print("    Voxel positions: ", voxel_parts["main"])
		else:
			print("  WARNING: No voxels generated for ", part_name)
	
	# Auto-generate connections based on entity type
	auto_connect_parts(template)
	
	if template.validate_template():
		voxel_skeleton.create_skeleton_from_template(template)
		animation_system.skeleton = voxel_skeleton
		constraint_system.skeleton = voxel_skeleton
		
		animation_system.create_default_animations_for_entity_type(current_entity_type)
		constraint_system.setup_default_constraints_for_entity_type(current_entity_type)
		
		print("Successfully imported ", template.part_definitions.size(), " parts from multiple OBJ files")
		
		# Auto-adjust camera distance based on model size
		auto_adjust_camera_for_model()
		
		# animation_system.play_animation("idle", true)  # Disabled to test positioning
	else:
		push_error("Failed to create valid template from multiple OBJ files")

func map_filename_to_part_name(filename: String) -> String:
	var name_lower = filename.to_lower()
	
	# Common naming patterns from MagicaVoxel exports
	if "head" in name_lower or "skull" in name_lower:
		return "head"
	elif "torso" in name_lower or "body" in name_lower or "chest" in name_lower:
		return "torso"
	elif "arm" in name_lower and ("left" in name_lower or "_l" in name_lower):
		return "arm_left"
	elif "arm" in name_lower and ("right" in name_lower or "_r" in name_lower):
		return "arm_right"
	elif "leg" in name_lower and ("left" in name_lower or "_l" in name_lower):
		return "leg_left"
	elif "leg" in name_lower and ("right" in name_lower or "_r" in name_lower):
		return "leg_right"
	elif "tail" in name_lower:
		return "tail"
	elif "wing" in name_lower and ("left" in name_lower or "_l" in name_lower):
		return "wing_left"
	elif "wing" in name_lower and ("right" in name_lower or "_r" in name_lower):
		return "wing_right"
	else:
		return filename  # Use filename as fallback

func guess_part_type_from_name(part_name: String) -> VoxelPart.PartType:
	match part_name:
		"head":
			return VoxelPart.PartType.HEAD
		"torso", "body":
			return VoxelPart.PartType.TORSO
		"arm_left":
			return VoxelPart.PartType.ARM_LEFT
		"arm_right":
			return VoxelPart.PartType.ARM_RIGHT
		"leg_left":
			return VoxelPart.PartType.LEG_LEFT
		"leg_right":
			return VoxelPart.PartType.LEG_RIGHT
		"tail":
			return VoxelPart.PartType.TAIL
		"wing_left":
			return VoxelPart.PartType.WING_LEFT
		"wing_right":
			return VoxelPart.PartType.WING_RIGHT
		_:
			return VoxelPart.PartType.BODY

func get_color_for_part_type(part_type: VoxelPart.PartType) -> Color:
	match part_type:
		VoxelPart.PartType.HEAD:
			return Color.BEIGE
		VoxelPart.PartType.TORSO:
			return Color.BLUE
		VoxelPart.PartType.ARM_LEFT, VoxelPart.PartType.ARM_RIGHT:
			return Color.BEIGE
		VoxelPart.PartType.LEG_LEFT, VoxelPart.PartType.LEG_RIGHT:
			return Color.BROWN
		VoxelPart.PartType.TAIL:
			return Color.BROWN
		VoxelPart.PartType.WING_LEFT, VoxelPart.PartType.WING_RIGHT:
			return Color.GRAY
		_:
			return Color.WHITE

func auto_connect_parts(template: EntityTemplate):
	var root_part = template.get_root_part_definition()
	if not root_part:
		return
	
	# Basic connection rules based on entity type
	for part_def in template.part_definitions:
		if part_def == root_part:
			continue
			
		var offset = Vector3.ZERO
		match part_def.name:
			"head":
				offset = Vector3(0, 2, 0)
			"arm_left":
				offset = Vector3(-1.5, 1, 0)
			"arm_right":
				offset = Vector3(1.5, 1, 0)
			"leg_left":
				offset = Vector3(-0.5, -1.5, 0)
			"leg_right":
				offset = Vector3(0.5, -1.5, 0)
			"tail":
				offset = Vector3(0, 0, -1)
			"wing_left":
				offset = Vector3(-1, 0.5, 0)
			"wing_right":
				offset = Vector3(1, 0.5, 0)
		
		template.add_connection(root_part.name, part_def.name, offset)

func auto_adjust_camera_for_model():
	if not voxel_skeleton:
		return
		
	# Calculate bounding box of all parts
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	
	for part in voxel_skeleton.get_all_parts():
		var part_bounds = part.get_bounds()
		var part_min = part.global_position + part_bounds.position
		var part_max = part.global_position + part_bounds.end
		
		min_pos = min_pos.min(part_min)
		max_pos = max_pos.max(part_max)
	
	# Calculate model size and set appropriate camera distance
	var model_size = max_pos - min_pos
	var max_dimension = max(model_size.x, max(model_size.y, model_size.z))
	
	camera_distance = max_dimension * 2.5  # Good viewing distance
	camera_target = (min_pos + max_pos) * 0.5  # Center the camera on the model
	
	print("Model size: ", model_size, " - Auto-adjusted camera distance: ", camera_distance)
	update_camera_position()

func _on_animation_started(animation_name: String):
	animation_label.text = "Animation: " + animation_name

func _on_animation_finished(animation_name: String):
	pass

func _on_constraint_violated(constraint: VoxelConstraintSystem.VoxelConstraint, part_name: String):
	# Silenced - these fire constantly during normal operation
	pass

func debug_single_obj_file(file_path: String):
	print("=== DEBUG: Analyzing OBJ file: ", file_path, " ===")
	
	var obj_data = VoxelMeshLoader.load_obj_file(file_path)
	if obj_data.is_empty():
		print("ERROR: Failed to load OBJ file")
		return
		
	print("Loaded OBJ data:")
	print("  Vertices (", obj_data.vertices.size(), "): ", obj_data.vertices)
	print("  Faces (", obj_data.faces.size(), "): ", obj_data.faces)
	
	var bounds = VoxelMeshLoader.calculate_bounds(obj_data.vertices)
	print("  Bounds: ", bounds)
	print("  Size: ", bounds.size)
	
	print("\nTesting with fixed 0.1 voxel size:")
	var voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, false)
	if "main" in voxel_parts:
		print("  Produced ", voxel_parts["main"].size(), " voxels")
		print("  Positions: ", voxel_parts["main"])
	else:
		print("  No voxels produced")
	
	print("=== END DEBUG ===")

func debug_tail_with_size_01():
	print("=== TAIL DEBUG WITH 0.1 VOXEL SIZE ===")
	
	if last_imported_file == "":
		print("ERROR: No file has been imported yet. Please import an OBJ file first.")
		return
	
	var file_path = last_imported_file
	print("Using last imported file: ", file_path)
	
	var obj_data = VoxelMeshLoader.load_obj_file(file_path)
	if obj_data.is_empty():
		print("ERROR: Failed to load OBJ file: ", file_path)
		return
	
	print("Tail OBJ loaded:")
	print("  Vertices: ", obj_data.vertices)
	print("  Faces: ", obj_data.faces)
	
	var bounds = VoxelMeshLoader.calculate_bounds(obj_data.vertices)
	print("  Bounds: ", bounds)
	print("  Size: ", bounds.size)
	
	print("\\nTesting with fixed 0.1 voxel size:")
	var voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, false)
	if "main" in voxel_parts:
		print("  Result: ", voxel_parts["main"].size(), " voxels")
		print("  Positions: ", voxel_parts["main"])
	else:
		print("  No voxels produced")
	
	print("=== END TAIL DEBUG ===")

func debug_test_tail():
	print("=== TEST TAIL DEBUG ===")
	
	var file_path = "res://test_tail.obj"
	var obj_data = VoxelMeshLoader.load_obj_file(file_path)
	if obj_data.is_empty():
		print("ERROR: Failed to load test tail OBJ file")
		return
	
	print("Test tail OBJ loaded:")
	print("  Vertices: ", obj_data.vertices.size())
	print("  Faces: ", obj_data.faces.size())
	
	var bounds = VoxelMeshLoader.calculate_bounds(obj_data.vertices)
	print("  Bounds: ", bounds)
	print("  Size: ", bounds.size)
	
	print("\\nTesting with fixed 0.1 voxel size:")
	var voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, false)
	if "main" in voxel_parts:
		print("  Result: ", voxel_parts["main"].size(), " voxels")
		print("  Positions: ", voxel_parts["main"])
	else:
		print("  No voxels produced")
	
	print("=== END TEST TAIL DEBUG ===")


func _unhandled_input(event):
	# Handle camera controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(camera_distance - zoom_speed, 2.0)
			update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(camera_distance + zoom_speed, 100.0)
			update_camera_position()
	
	elif event is InputEventMouseMotion and is_rotating:
		camera_angle_h += event.relative.x * mouse_sensitivity
		camera_angle_v = clamp(camera_angle_v - event.relative.y * mouse_sensitivity, -80.0, 80.0)
		update_camera_position()

func _input(event):
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_on_humanoid_pressed()
			KEY_2:
				_on_quadruped_pressed()
			KEY_3:
				_on_bird_pressed()
			KEY_SPACE:
				_on_idle_pressed()
			KEY_W:
				_on_walk_pressed()
			KEY_R:
				_on_run_pressed()
			KEY_I:
				_on_import_pressed()
			KEY_ESCAPE:
				if is_rotating:
					is_rotating = false
			KEY_T:
				# Debug the tail file - use file dialog to select
				print("Please use the import button to select the tail OBJ file for debugging")
				_on_import_pressed()
			KEY_Q:
				# Quick test with just voxel size 0.1
				debug_tail_with_size_01()
			KEY_E:
				# Test with built-in test tail
				debug_test_tail()

func _on_voxel_skeleton_skeleton_changed():
	print("Skeleton structure changed")

func save_current_skeleton():
	if voxel_skeleton:
		var file_path = "user://skeleton_" + str(current_entity_type) + ".json"
		voxel_skeleton.save_skeleton_to_file(file_path)
		print("Saved skeleton to: ", file_path)

func load_skeleton_from_file(file_path: String):
	if voxel_skeleton.load_skeleton_from_file(file_path):
		animation_system.skeleton = voxel_skeleton
		constraint_system.skeleton = voxel_skeleton
		print("Loaded skeleton from: ", file_path)
	else:
		print("Failed to load skeleton from: ", file_path)
