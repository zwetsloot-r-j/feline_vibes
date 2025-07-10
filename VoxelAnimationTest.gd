extends Node3D

@onready var info_label = $UI/InfoLabel

var voxel_part: VoxelPart
var test_skeleton: VoxelSkeleton

func _ready():
	info_label.text = "Voxel Animation System Test\nRendering: OpenGL3 (GL Compatibility)\nStatus: Ready - Press SPACE to test"
	print("Voxel Animation Test Ready!")
	print("Press SPACE to create a simple voxel part")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			create_test_voxel_part()
		elif event.keycode == KEY_1:
			create_test_skeleton()

func create_test_voxel_part():
	if voxel_part:
		voxel_part.queue_free()
	
	print("Creating test voxel part...")
	call_deferred("_create_voxel_part_deferred")

func _create_voxel_part_deferred():
	voxel_part = VoxelPart.new()
	voxel_part.part_name = "test_part"
	voxel_part.part_type = VoxelPart.PartType.BODY
	
	# Create a simple 2x2x2 cube
	var positions: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)
	]
	
	var colors: Array[Color] = []
	for i in range(positions.size()):
		colors.append(Color.BLUE)
	
	voxel_part.set_voxel_positions(positions, colors)
	add_child(voxel_part)
	
	info_label.text = "Voxel Animation System Test\nRendering: OpenGL3 (GL Compatibility)\nStatus: Test voxel part created!\nPress 1 to create skeleton"
	print("Test voxel part created successfully!")

func create_test_skeleton():
	if test_skeleton:
		test_skeleton.queue_free()
	
	print("Creating test skeleton...")
	call_deferred("_create_skeleton_deferred")

func _create_skeleton_deferred():
	test_skeleton = VoxelSkeleton.new()
	test_skeleton.skeleton_name = "TestSkeleton"
	test_skeleton.entity_type = VoxelSkeleton.EntityType.HUMANOID
	
	# Create a simple template
	var template = EntityTemplate.new()
	template.template_name = "SimpleTest"
	template.entity_type = VoxelSkeleton.EntityType.HUMANOID
	
	# Add a simple torso part
	template.add_part_definition("torso", VoxelPart.PartType.TORSO, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0)], 
		[Color.RED, Color.RED, Color.RED, Color.RED], 
		Vector3.ZERO, true)
	
	# Add a head part
	template.add_part_definition("head", VoxelPart.PartType.HEAD, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0)], 
		[Color.YELLOW, Color.YELLOW])
	
	# Connect head to torso
	template.add_connection("torso", "head", Vector3(0, 2, 0))
	
	if template.validate_template():
		test_skeleton.create_skeleton_from_template(template)
		add_child(test_skeleton)
		
		info_label.text = "Voxel Animation System Test\nRendering: OpenGL3 (GL Compatibility)\nStatus: Test skeleton created!"
		print("Test skeleton created successfully!")
	else:
		print("Failed to create test skeleton - template validation failed")
		info_label.text = "Voxel Animation System Test\nRendering: OpenGL3 (GL Compatibility)\nStatus: Skeleton creation failed!"