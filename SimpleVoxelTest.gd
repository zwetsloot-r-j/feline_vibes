extends Node3D

@onready var info_label = $UI/InfoLabel

var mesh_instance: MeshInstance3D

func _ready():
	info_label.text = "Simple Voxel Test\nRendering: OpenGL3 (GL Compatibility)\nStatus: Ready - Press SPACE to test"
	print("Simple Voxel Test Ready!")
	print("Press SPACE to create a simple voxel cube")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			create_simple_voxel_cube()

func create_simple_voxel_cube():
	if mesh_instance:
		mesh_instance.queue_free()
	
	print("Creating simple voxel cube...")
	
	# Create mesh instance directly in scene
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Create a simple box mesh
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	
	# Simple cube vertices
	var cube_positions = [
		Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)
	]
	
	# Add vertices for each face
	var faces = [
		[0, 1, 2, 3], # front
		[5, 4, 7, 6], # back
		[4, 0, 3, 7], # left
		[1, 5, 6, 2], # right
		[3, 2, 6, 7], # top
		[4, 5, 1, 0]  # bottom
	]
	
	var face_normals = [
		Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0),
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)
	]
	
	for i in range(faces.size()):
		var face = faces[i]
		var normal = face_normals[i]
		
		# Add 4 vertices for this face
		for j in range(4):
			vertices.append(cube_positions[face[j]])
			normals.append(normal)
			colors.append(Color.BLUE)
		
		# Add indices for 2 triangles
		var base = i * 4
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	
	# Create mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Create a simple material
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.flags_unshaded = true
	mesh_instance.material_override = material
	
	info_label.text = "Simple Voxel Test\nRendering: OpenGL3 (GL Compatibility)\nStatus: Simple voxel cube created!"
	print("Simple voxel cube created successfully!")