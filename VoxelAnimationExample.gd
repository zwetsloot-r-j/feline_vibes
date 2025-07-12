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
	print("")
	print("=== ASSETS FOLDER USAGE ===")
	print("For textures and materials: Place MTL and PNG files in: assets/models/")
	print("The system will automatically find companion files there.")
	print("==========================")

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
	
	# Simply load the OBJ file - companion files should be in assets/models/
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

func load_obj_file_with_companion_search(temp_file_path: String):
	print("Loading OBJ file from temporary location with companion search: ", temp_file_path)
	
	# First, copy the temporary OBJ file to the project permanently
	var obj_filename = temp_file_path.get_file()
	var project_obj_path = "res://" + obj_filename
	
	if not FileAccess.file_exists(project_obj_path):
		var source_file = FileAccess.open(temp_file_path, FileAccess.READ)
		var target_file = FileAccess.open(project_obj_path, FileAccess.WRITE)
		if source_file and target_file:
			target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
			source_file.close()
			target_file.close()
			print("Copied OBJ to project: ", project_obj_path)
	
	# Now prompt user for the original directory to find companion files
	show_companion_file_dialog(project_obj_path)

func show_companion_file_dialog(obj_path: String):
	# Clean up any previous companion files to avoid confusion
	clear_previous_companion_files(obj_path)
	
	# Create a dialog to ask user for the original directory
	var dialog = AcceptDialog.new()
	dialog.title = "Companion Files"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "To load textures and materials, please select the original folder containing the MTL and PNG files for this OBJ file.\n\nIMPORTANT: Select files from the ORIGINAL folder, not from temporary copies!"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	
	var folder_btn = Button.new()
	folder_btn.text = "Select Original Folder"
	vbox.add_child(folder_btn)
	
	var file_btn = Button.new()
	file_btn.text = "Select MTL/PNG File in Folder"
	vbox.add_child(file_btn)
	
	var manual_btn = Button.new()
	manual_btn.text = "Enter Path Manually"
	vbox.add_child(manual_btn)
	
	var skip_btn = Button.new()
	skip_btn.text = "Skip (Use Default Colors)"
	vbox.add_child(skip_btn)
	
	dialog.add_child(vbox)
	add_child(dialog)
	
	folder_btn.pressed.connect(func(): 
		dialog.queue_free()
		show_folder_selection_for_companions(obj_path)
	)
	
	file_btn.pressed.connect(func(): 
		dialog.queue_free()
		show_file_selection_for_companions(obj_path)
	)
	
	manual_btn.pressed.connect(func(): 
		dialog.queue_free()
		show_manual_path_input(obj_path)
	)
	
	skip_btn.pressed.connect(func(): 
		dialog.queue_free()
		load_obj_file(obj_path)
	)
	
	dialog.popup_centered()

func show_folder_selection_for_companions(obj_path: String):
	# Create a file dialog to select the original folder
	var folder_dialog = FileDialog.new()
	folder_dialog.title = "Select Original Folder Containing MTL/PNG Files"
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	
	# Make sure the dialog can show directories
	folder_dialog.show_hidden_files = false
	
	add_child(folder_dialog)
	
	# Connect both signals for better compatibility
	folder_dialog.dir_selected.connect(func(dir: String):
		print("Selected directory: ", dir)
		folder_dialog.queue_free()
		load_obj_with_companion_folder(obj_path, dir)
	)
	
	# Also handle cancel
	folder_dialog.canceled.connect(func():
		print("Folder selection canceled")
		folder_dialog.queue_free()
		load_obj_file(obj_path)  # Load without companion files
	)
	
	folder_dialog.popup_centered(Vector2i(800, 600))

func show_file_selection_for_companions(obj_path: String):
	# Alternative approach: select any companion file in the directory
	var file_dialog = FileDialog.new()
	file_dialog.title = "Select Any MTL or PNG File in the Original Folder"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	
	# Add filters for common companion file types
	file_dialog.add_filter("*.mtl", "Material Files")
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.add_filter("*.jpg", "JPEG Images")
	file_dialog.add_filter("*.jpeg", "JPEG Images")
	file_dialog.add_filter("*", "All Files")
	
	add_child(file_dialog)
	
	file_dialog.file_selected.connect(func(file_path: String):
		print("=== FILE SELECTION DEBUG ===")
		print("Selected companion file: ", file_path)
		print("Raw file path: ", file_path)
		var companion_dir = file_path.get_base_dir()
		print("Companion directory: ", companion_dir)
		print("Directory starts with /run/user/: ", companion_dir.begins_with("/run/user/"))
		print("Directory starts with /tmp/: ", companion_dir.begins_with("/tmp/"))
		print("Directory starts with res://: ", companion_dir.begins_with("res://"))
		
		# Check if the selected file is in a temporary directory
		# Be more specific about what constitutes a temporary directory
		if companion_dir.begins_with("/run/user/") or companion_dir.begins_with("/tmp/"):
			print("WARNING: Selected file is in temporary directory: ", companion_dir)
			print("Please select the MTL/PNG file from the ORIGINAL folder, not the temporary copy.")
			
			# Show error dialog
			var error_dialog = AcceptDialog.new()
			error_dialog.title = "Wrong Directory"
			error_dialog.dialog_text = "Please select the MTL or PNG file from the ORIGINAL folder where you created/exported your model, not from the temporary copy.\n\nThe file you selected appears to be in a temporary location:\n" + companion_dir + "\n\nTry navigating to your original project folder (like /home/user/Documents/my_project/) and selecting the file from there."
			add_child(error_dialog)
			error_dialog.popup_centered()
			error_dialog.confirmed.connect(func():
				error_dialog.queue_free()
				# Show the file dialog again
				show_file_selection_for_companions(obj_path)
			)
			file_dialog.queue_free()
			return
		
		# If it's in the project directory (res://), that might be okay if it's a fresh copy
		if companion_dir.begins_with("res://"):
			print("INFO: File is in project directory - this may be okay if it's a fresh copy")
			# Let it proceed but warn the user
		
		print("Proceeding with companion directory: ", companion_dir)
		file_dialog.queue_free()
		load_obj_with_companion_folder(obj_path, companion_dir)
	)
	
	file_dialog.canceled.connect(func():
		print("File selection canceled")
		file_dialog.queue_free()
		load_obj_file(obj_path)  # Load without companion files
	)
	
	file_dialog.popup_centered(Vector2i(800, 600))

func show_manual_path_input(obj_path: String):
	# Create a custom dialog for manual path input
	var dialog = Window.new()
	dialog.title = "Enter Original Folder Path"
	dialog.size = Vector2i(600, 200)
	dialog.unresizable = false
	dialog.popup_window = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Add some padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var label = Label.new()
	label.text = "Enter the full path to the folder containing your MTL and PNG files:"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = "/home/" + OS.get_environment("USER") + "/Documents/"
	line_edit.placeholder_text = "e.g. /home/user/Documents/my_project/"
	vbox.add_child(line_edit)
	
	var hint_label = Label.new()
	hint_label.text = "Tip: This should be the folder where you created/exported your OBJ, MTL, and PNG files."
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(hint_label)
	
	# Add buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_END
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	button_container.add_child(cancel_btn)
	
	var load_btn = Button.new()
	load_btn.text = "Load Companions"
	button_container.add_child(load_btn)
	
	vbox.add_child(button_container)
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	
	# Function to handle path processing
	var process_path = func():
		var folder_path = line_edit.text.strip_edges()
		print("Manual path entered: ", folder_path)
		dialog.queue_free()
		
		if DirAccess.dir_exists_absolute(folder_path):
			load_obj_with_companion_folder(obj_path, folder_path)
		else:
			print("ERROR: Directory does not exist: ", folder_path)
			var error_dialog = AcceptDialog.new()
			error_dialog.title = "Directory Not Found"
			error_dialog.dialog_text = "The directory does not exist:\n" + folder_path + "\n\nPlease check the path and try again."
			add_child(error_dialog)
			error_dialog.popup_centered()
			error_dialog.confirmed.connect(func():
				error_dialog.queue_free()
				show_manual_path_input(obj_path)  # Try again
			)
	
	# Connect signals
	load_btn.pressed.connect(process_path)
	line_edit.text_submitted.connect(func(_text): process_path.call())
	
	cancel_btn.pressed.connect(func():
		dialog.queue_free()
		load_obj_file(obj_path)  # Load without companion files
	)
	
	dialog.close_requested.connect(func():
		dialog.queue_free()
		load_obj_file(obj_path)  # Load without companion files
	)
	
	dialog.popup_centered()
	line_edit.grab_focus()

func load_obj_with_companion_folder(obj_path: String, companion_dir: String):
	print("=== COMPANION FILE LOADING ===")
	print("Loading OBJ with companion files from: ", companion_dir)
	print("OBJ path: ", obj_path)
	
	var obj_filename = obj_path.get_file().get_basename()
	print("OBJ filename (no extension): ", obj_filename)
	
	# List all files in the companion directory for debugging
	print("Files in companion directory:")
	var dir = DirAccess.open(companion_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			print("  - ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Look for MTL file
	var mtl_path = companion_dir + "/" + obj_filename + ".mtl"
	print("Looking for MTL at: ", mtl_path)
	if FileAccess.file_exists(mtl_path):
		print("Found MTL file!")
		var target_mtl = "res://" + obj_filename + ".mtl"
		if not FileAccess.file_exists(target_mtl):
			VoxelMeshLoader.copy_file_to_project(mtl_path, target_mtl)
			print("Copied MTL file: ", target_mtl)
		else:
			print("MTL file already exists in project")
	else:
		print("MTL file not found")
	
	# Look for common texture files
	print("Looking for texture files...")
	var texture_extensions = [".png", ".jpg", ".jpeg", ".bmp", ".tga"]
	for ext in texture_extensions:
		var texture_path = companion_dir + "/" + obj_filename + ext
		print("  Checking: ", texture_path)
		if FileAccess.file_exists(texture_path):
			print("  Found texture: ", texture_path)
			var target_texture = "res://" + obj_filename + ext
			if not FileAccess.file_exists(target_texture):
				VoxelMeshLoader.copy_file_to_project(texture_path, target_texture)
				print("  Copied texture file: ", target_texture)
			else:
				print("  Texture already exists in project")
		else:
			print("  Not found: ", texture_path)
	
	# Also look for ANY PNG/JPG files in the directory that might be textures
	print("Looking for any texture files in directory...")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var lower_name = file_name.to_lower()
			if lower_name.ends_with(".png") or lower_name.ends_with(".jpg") or lower_name.ends_with(".jpeg"):
				print("  Found potential texture: ", file_name)
				var source_path = companion_dir + "/" + file_name
				var target_path = "res://" + file_name
				if not FileAccess.file_exists(target_path):
					VoxelMeshLoader.copy_file_to_project(source_path, target_path)
					print("  Copied potential texture: ", target_path)
				else:
					print("  Potential texture already exists in project")
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Load MTL file if exists and copy any referenced textures
	var project_mtl_path = "res://" + obj_filename + ".mtl"
	print("Checking for project MTL: ", project_mtl_path)
	if FileAccess.file_exists(project_mtl_path):
		print("Loading MTL to find referenced textures...")
		var materials = VoxelMeshLoader.load_mtl_file(project_mtl_path)
		print("Found materials: ", materials.keys())
		for material_name in materials:
			var material = materials[material_name]
			var texture_file = material.get("texture_path", "")
			if texture_file != "":
				print("Material ", material_name, " references texture: ", texture_file)
				var source_texture = companion_dir + "/" + texture_file
				var target_texture = "res://" + texture_file
				print("  Source: ", source_texture)
				print("  Target: ", target_texture)
				if FileAccess.file_exists(source_texture):
					if not FileAccess.file_exists(target_texture):
						VoxelMeshLoader.copy_file_to_project(source_texture, target_texture)
						print("  Copied referenced texture: ", target_texture)
					else:
						print("  Referenced texture already exists in project")
				else:
					print("  Referenced texture not found at source")
	else:
		print("No MTL file found in project")
	
	print("=== LOADING OBJ WITH MATERIALS ===")
	# Now load the OBJ file normally
	load_obj_file(obj_path)

func clear_previous_companion_files(obj_path: String):
	# Remove any previously copied companion files to avoid confusion
	var obj_filename = obj_path.get_file().get_basename()
	
	var files_to_remove = [
		"res://" + obj_filename + ".mtl",
		"res://" + obj_filename + ".png",
		"res://" + obj_filename + ".jpg",
		"res://" + obj_filename + ".jpeg",
		"res://" + obj_filename + ".bmp",
		"res://" + obj_filename + ".tga"
	]
	
	var dir = DirAccess.open("res://")
	if dir:
		for file_path in files_to_remove:
			var filename = file_path.get_file()
			if FileAccess.file_exists(file_path):
				var result = dir.remove(filename)
				if result == OK:
					print("Removed previous companion file: ", file_path)
				else:
					print("Failed to remove file: ", file_path)

func load_multiple_obj_files(file_paths: PackedStringArray):
	print("POSITION_DEBUG: Loading multiple OBJ files...")
	print("POSITION_DEBUG: Files to load: ", file_paths)
	
	var template = EntityTemplate.new()
	template.template_name = "BatchImported"
	template.entity_type = current_entity_type
	
	# Use fixed 0.1 voxel size for batch imports
	var part_positions = {}
	
	for file_path in file_paths:
		var filename = file_path.get_file().get_basename()
		var part_name = map_filename_to_part_name(filename)
		
		print("POSITION_DEBUG: Processing file: ", filename, " -> part: ", part_name)
		
		var obj_data = VoxelMeshLoader.load_obj_file(file_path)
		if obj_data.is_empty():
			print("POSITION_DEBUG: ERROR: Failed to load ", file_path)
			continue
			
		print("POSITION_DEBUG:   OBJ vertices: ", obj_data.vertices.size(), " faces: ", obj_data.faces.size())
		if obj_data.vertices.size() > 0:
			print("POSITION_DEBUG:     First few vertices: ", obj_data.vertices.slice(0, min(4, obj_data.vertices.size())))
			var bounds = VoxelMeshLoader.calculate_bounds(obj_data.vertices)
			print("POSITION_DEBUG:     STAGE 1 (OBJ) - Mesh bounds: ", bounds)
			print("POSITION_DEBUG:     STAGE 1 (OBJ) - Mesh center: ", bounds.get_center())
			print("POSITION_DEBUG:     STAGE 1 (OBJ) - Mesh min: ", bounds.position)
			print("POSITION_DEBUG:     STAGE 1 (OBJ) - Mesh max: ", bounds.end)
		
		var voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, false)
		if "main" in voxel_parts:
			var voxel_data = voxel_parts["main"]
			var part_type = guess_part_type_from_name(part_name)
			
			var voxel_positions: Array = []
			var colors: Array = []
			
			# Handle both old and new voxel data formats
			if voxel_data is Array:
				# Old format: just positions
				voxel_positions = voxel_data
				for i in range(voxel_positions.size()):
					colors.append(get_color_for_part_type(part_type))
			else:
				# New format: dictionary with positions and colors
				voxel_positions = voxel_data.get("positions", [])
				colors = voxel_data.get("colors", [])
				
				# Fill in missing colors with default
				while colors.size() < voxel_positions.size():
					colors.append(get_color_for_part_type(part_type))
			
			if voxel_positions.size() > 0:
				# Calculate bounds of voxel positions for position debugging
				var voxel_bounds = calculate_voxel_bounds(voxel_positions)
				print("POSITION_DEBUG:     STAGE 2 (VOXELS) - Voxel bounds: ", voxel_bounds)
				print("POSITION_DEBUG:     STAGE 2 (VOXELS) - Voxel center: ", voxel_bounds.get_center())
				print("POSITION_DEBUG:     STAGE 2 (VOXELS) - Voxel min: ", voxel_bounds.position)
				print("POSITION_DEBUG:     STAGE 2 (VOXELS) - Voxel max: ", voxel_bounds.end)
				
				# Compare Stage 1 vs Stage 2
				if obj_data.vertices.size() > 0:
					var mesh_bounds = VoxelMeshLoader.calculate_bounds(obj_data.vertices)
					var center_difference = voxel_bounds.get_center() - mesh_bounds.get_center()
					print("POSITION_DEBUG:     CENTER SHIFT (OBJ->Voxel): ", center_difference)
					print("POSITION_DEBUG:     CENTER SHIFT MAGNITUDE: ", center_difference.length())
				
				template.add_part_definition(part_name, part_type, voxel_positions, colors, 
											Vector3.ZERO, part_name == "torso" or part_name == "body")
				
				print("POSITION_DEBUG:   Added part '", part_name, "' with ", voxel_positions.size(), " voxels")
				print("POSITION_DEBUG:     Sample voxel positions (grid coords): ", voxel_positions.slice(0, min(3, voxel_positions.size())))
			else:
				print("  WARNING: No voxels generated for ", part_name)
		else:
			print("  WARNING: No main part found for ", part_name)
	
	# Auto-generate connections based on entity type
	auto_connect_parts(template)
	
	if template.validate_template():
		print("POSITION_DEBUG: Creating skeleton from template with ", template.part_definitions.size(), " parts")
		
		# Debug part positions before skeleton creation
		for part_def in template.part_definitions:
			print("POSITION_DEBUG:   Part '", part_def.name, "': ", part_def.positions.size(), " voxels, pivot: ", part_def.pivot_offset)
		
		voxel_skeleton.create_skeleton_from_template(template)
		animation_system.skeleton = voxel_skeleton
		constraint_system.skeleton = voxel_skeleton
		
		# Debug actual part positions after skeleton creation
		print("POSITION_DEBUG: Skeleton created - checking part positions:")
		for part_name in voxel_skeleton.parts.keys():
			var part = voxel_skeleton.parts[part_name]
			var part_bounds = part.get_bounds()
			var part_world_center = part.global_position + part_bounds.get_center()
			
			print("POSITION_DEBUG:   STAGE 3 (CONNECTED) - Part '", part_name, "':")
			print("POSITION_DEBUG:     Local position: ", part.position)
			print("POSITION_DEBUG:     Global position: ", part.global_position)
			print("POSITION_DEBUG:     Part bounds: ", part_bounds)
			print("POSITION_DEBUG:     Part world center: ", part_world_center)
			
			# Try to find the original voxel data for comparison
			for part_def in template.part_definitions:
				if part_def.name == part_name:
					var original_voxel_bounds = calculate_voxel_bounds(part_def.positions)
					var original_center = original_voxel_bounds.get_center()
					var final_center_shift = part_world_center - original_center
					print("POSITION_DEBUG:     CENTER SHIFT (Voxel->Connected): ", final_center_shift)
					print("POSITION_DEBUG:     FINAL CENTER SHIFT MAGNITUDE: ", final_center_shift.length())
					break
		
		animation_system.create_default_animations_for_entity_type(current_entity_type)
		constraint_system.setup_default_constraints_for_entity_type(current_entity_type)
		
		print("POSITION_DEBUG: ===============================")
		print("POSITION_DEBUG: POSITION ANALYSIS SUMMARY")
		print("POSITION_DEBUG: ===============================")
		print("POSITION_DEBUG: Successfully imported ", template.part_definitions.size(), " parts from multiple OBJ files")
		
		# Final summary of all part positions
		for part_name in voxel_skeleton.parts.keys():
			var part = voxel_skeleton.parts[part_name]
			var part_bounds = part.get_bounds()
			var part_world_center = part.global_position + part_bounds.get_center()
			print("POSITION_DEBUG: FINAL POSITION - '", part_name, "': ", part_world_center)
		
		print("POSITION_DEBUG: ===============================")
		
		# Auto-adjust camera distance based on model size
		auto_adjust_camera_for_model()
		
		# animation_system.play_animation("idle", true)  # Disabled to test positioning
	else:
		print("POSITION_DEBUG: Template validation failed")
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
	
	print("POSITION_DEBUG: Using OBJ-based positioning instead of hardcoded offsets")
	
	# Instead of hardcoded offsets, use the original mesh positions
	# Each part should maintain its position relative to the root part
	var root_bounds = calculate_voxel_bounds(root_part.positions)
	var root_center = root_bounds.get_center()
	
	print("POSITION_DEBUG: Root part center: ", root_center)
	
	for part_def in template.part_definitions:
		if part_def == root_part:
			continue
			
		# Calculate offset based on original mesh position relative to root
		var part_bounds = calculate_voxel_bounds(part_def.positions)
		var part_center = part_bounds.get_center()
		var relative_offset = part_center - root_center
		
		print("POSITION_DEBUG: Part '", part_def.name, "' center: ", part_center, " offset: ", relative_offset)
		
		template.add_connection(root_part.name, part_def.name, relative_offset)

func calculate_voxel_bounds(voxel_positions: Array) -> AABB:
	if voxel_positions.is_empty():
		return AABB()
	
	var min_pos = Vector3(voxel_positions[0]) * 0.1  # Convert first to world units
	var max_pos = Vector3(voxel_positions[0]) * 0.1  # Convert first to world units
	
	for pos in voxel_positions:
		var v_pos = Vector3(pos) * 0.1  # Convert to world units
		min_pos = min_pos.min(v_pos)
		max_pos = max_pos.max(v_pos)
	
	return AABB(min_pos, max_pos - min_pos)

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
