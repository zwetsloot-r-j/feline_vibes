extends Node3D

@export var map_size: Vector3i = Vector3i(64, 16, 64)
@export var voxel_size: float = 1.0
@export var noise_scale: float = 0.1
@export var water_level: int = 4
@export var grass_level: int = 8
@export var generate_on_start: bool = true

enum VoxelType {
	AIR,
	WATER,
	SAND,
	DIRT,
	GRASS
}

var noise: FastNoiseLite
var voxel_data: Array[Array]
var materials: Array[StandardMaterial3D]

func _ready():
	setup_noise()
	create_materials()
	if generate_on_start:
		generate_map()

func setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale

func create_materials():
	materials.clear()
	
	# AIR - transparent (not used)
	var air_mat = StandardMaterial3D.new()
	air_mat.albedo_color = Color.TRANSPARENT
	materials.append(air_mat)
	
	# WATER - Blue
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.2, 0.4, 0.8, 0.8)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.metallic = 0.0
	water_mat.roughness = 0.1
	materials.append(water_mat)
	
	# SAND - Light brown
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.9, 0.8, 0.6, 1.0)
	sand_mat.roughness = 0.8
	materials.append(sand_mat)
	
	# DIRT - Dark brown
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.4, 0.25, 0.1, 1.0)
	dirt_mat.roughness = 0.9
	materials.append(dirt_mat)
	
	# GRASS - Green
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.2, 0.7, 0.2, 1.0)
	grass_mat.roughness = 0.7
	materials.append(grass_mat)

func generate_map():
	print("Generating voxel map...")
	
	# Initialize voxel data array
	voxel_data.clear()
	voxel_data.resize(map_size.x)
	for x in map_size.x:
		voxel_data[x] = []
		voxel_data[x].resize(map_size.y)
		for y in map_size.y:
			voxel_data[x][y] = []
			voxel_data[x][y].resize(map_size.z)
	
	# Generate terrain using noise
	for x in map_size.x:
		for z in map_size.z:
			# Get height from noise (0 to map_size.y)
			var noise_value = noise.get_noise_2d(x, z)
			var height = int((noise_value + 1.0) * 0.5 * map_size.y)
			height = clamp(height, 0, map_size.y - 1)
			
			# Fill voxels based on height and rules
			for y in map_size.y:
				var voxel_type = determine_voxel_type(x, y, z, height)
				voxel_data[x][y][z] = voxel_type
	
	# Generate mesh
	generate_mesh()
	print("Voxel map generation complete!")

func determine_voxel_type(x: int, y: int, z: int, terrain_height: int) -> VoxelType:
	# If we're below water level and above terrain, it's water
	if y <= water_level and y > terrain_height:
		return VoxelType.WATER
	
	# If we're at or below terrain height, determine solid block type
	if y <= terrain_height:
		if terrain_height <= water_level:
			# Underwater or at water level terrain
			if y == terrain_height:
				return VoxelType.SAND  # Sand surface for underwater terrain
			else:
				return VoxelType.DIRT  # Dirt below sand
		else:
			# Above water level terrain - much more grass
			if y == terrain_height:
				# Grass on most above-water surfaces, dirt only on very high peaks
				if terrain_height > grass_level + 4:  # Only highest peaks get dirt
					return VoxelType.DIRT
				else:
					return VoxelType.GRASS  # Grass on almost all above-water surfaces
			else:
				return VoxelType.DIRT  # Dirt below surface
	
	# Above both terrain and water level
	return VoxelType.AIR

func generate_mesh():
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Create collision body
	var static_body = StaticBody3D.new()
	static_body.name = "VoxelCollision"
	add_child(static_body)
	
	# Create mesh for each voxel type
	for voxel_type in range(VoxelType.WATER, VoxelType.GRASS + 1):
		if voxel_type == VoxelType.AIR:
			continue
		
		var mesh_instance = create_mesh_for_type(voxel_type)
		if mesh_instance:
			add_child(mesh_instance)
			
			# Add collision for solid voxels (not water)
			if voxel_type != VoxelType.WATER:
				var collision_shape = create_collision_for_type(voxel_type)
				if collision_shape:
					static_body.add_child(collision_shape)

func create_mesh_for_type(voxel_type: VoxelType) -> MeshInstance3D:
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	
	var vertex_count = 0
	
	# Iterate through all voxels
	for x in map_size.x:
		for y in map_size.y:
			for z in map_size.z:
				if voxel_data[x][y][z] != voxel_type:
					continue
				
				# Check each face of the voxel
				var faces_to_render = get_visible_faces(x, y, z, voxel_type)
				
				for face in faces_to_render:
					add_face_to_mesh(face, x, y, z, vertices, normals, uvs, indices, vertex_count)
					vertex_count += 4
	
	if vertices.size() == 0:
		return null
	
	# Create mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = materials[voxel_type]
	mesh_instance.name = "VoxelMesh_" + VoxelType.keys()[voxel_type]
	
	return mesh_instance

func get_visible_faces(x: int, y: int, z: int, voxel_type: VoxelType) -> Array[int]:
	var visible_faces: Array[int] = []
	
	# Check all 6 directions
	var directions = [
		Vector3i(0, 1, 0),   # Top
		Vector3i(0, -1, 0),  # Bottom
		Vector3i(1, 0, 0),   # Right (East)
		Vector3i(-1, 0, 0),  # Left (West)
		Vector3i(0, 0, -1),  # Front (North)
		Vector3i(0, 0, 1)    # Back (South)
	]
	
	for i in range(directions.size()):
		var neighbor_pos = Vector3i(x, y, z) + directions[i]
		
		# Check if neighbor is outside bounds (render face)
		if (neighbor_pos.x < 0 or neighbor_pos.x >= map_size.x or
			neighbor_pos.y < 0 or neighbor_pos.y >= map_size.y or
			neighbor_pos.z < 0 or neighbor_pos.z >= map_size.z):
			visible_faces.append(i)
			continue
		
		var neighbor_type = voxel_data[neighbor_pos.x][neighbor_pos.y][neighbor_pos.z]
		
		# Render face if neighbor is air or transparent
		if neighbor_type == VoxelType.AIR or (voxel_type != VoxelType.WATER and neighbor_type == VoxelType.WATER):
			visible_faces.append(i)
	
	return visible_faces

func add_face_to_mesh(face: int, x: int, y: int, z: int, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, start_index: int):
	var pos = Vector3(x, y, z) * voxel_size
	var half_size = voxel_size * 0.5
	
	var face_vertices: PackedVector3Array
	var face_normal: Vector3
	
	match face:
		0: # Top
			face_vertices = PackedVector3Array([
				pos + Vector3(-half_size, half_size, -half_size),
				pos + Vector3(half_size, half_size, -half_size),
				pos + Vector3(half_size, half_size, half_size),
				pos + Vector3(-half_size, half_size, half_size)
			])
			face_normal = Vector3.UP
		1: # Bottom
			face_vertices = PackedVector3Array([
				pos + Vector3(-half_size, -half_size, half_size),
				pos + Vector3(half_size, -half_size, half_size),
				pos + Vector3(half_size, -half_size, -half_size),
				pos + Vector3(-half_size, -half_size, -half_size)
			])
			face_normal = Vector3.DOWN
		2: # Right
			face_vertices = PackedVector3Array([
				pos + Vector3(half_size, -half_size, -half_size),
				pos + Vector3(half_size, -half_size, half_size),
				pos + Vector3(half_size, half_size, half_size),
				pos + Vector3(half_size, half_size, -half_size)
			])
			face_normal = Vector3.RIGHT
		3: # Left
			face_vertices = PackedVector3Array([
				pos + Vector3(-half_size, -half_size, half_size),
				pos + Vector3(-half_size, -half_size, -half_size),
				pos + Vector3(-half_size, half_size, -half_size),
				pos + Vector3(-half_size, half_size, half_size)
			])
			face_normal = Vector3.LEFT
		4: # Front (North) - negative Z
			face_vertices = PackedVector3Array([
				pos + Vector3(half_size, -half_size, -half_size),
				pos + Vector3(-half_size, -half_size, -half_size),
				pos + Vector3(-half_size, half_size, -half_size),
				pos + Vector3(half_size, half_size, -half_size)
			])
			face_normal = Vector3.FORWARD
		5: # Back (South) - positive Z
			face_vertices = PackedVector3Array([
				pos + Vector3(half_size, -half_size, half_size),
				pos + Vector3(-half_size, -half_size, half_size),
				pos + Vector3(-half_size, half_size, half_size),
				pos + Vector3(half_size, half_size, half_size)
			])
			face_normal = Vector3.BACK
	
	# Add vertices
	for vertex in face_vertices:
		vertices.append(vertex)
		normals.append(face_normal)
	
	# Add UVs (simple quad mapping)
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	
	# Add indices for two triangles
	indices.append(start_index)
	indices.append(start_index + 1)
	indices.append(start_index + 2)
	
	indices.append(start_index)
	indices.append(start_index + 2)
	indices.append(start_index + 3)

func create_collision_for_type(voxel_type: VoxelType) -> CollisionShape3D:
	var collision_vertices: PackedVector3Array = []
	var collision_indices: PackedInt32Array = []
	var vertex_count = 0
	
	# Iterate through all voxels of this type
	for x in map_size.x:
		for y in map_size.y:
			for z in map_size.z:
				if voxel_data[x][y][z] != voxel_type:
					continue
				
				# Check each face of the voxel for collision
				var faces_to_collide = get_visible_faces(x, y, z, voxel_type)
				
				for face in faces_to_collide:
					add_collision_face(face, x, y, z, collision_vertices, collision_indices, vertex_count)
					vertex_count += 4
	
	if collision_vertices.size() == 0:
		return null
	
	# Create trimesh collision shape
	var collision_shape = CollisionShape3D.new()
	var trimesh_shape = ConcavePolygonShape3D.new()
	
	# Convert indices to triangle vertices
	var triangle_vertices: PackedVector3Array = []
	for i in range(0, collision_indices.size(), 3):
		triangle_vertices.append(collision_vertices[collision_indices[i]])
		triangle_vertices.append(collision_vertices[collision_indices[i + 1]])
		triangle_vertices.append(collision_vertices[collision_indices[i + 2]])
	
	trimesh_shape.set_faces(triangle_vertices)
	collision_shape.shape = trimesh_shape
	collision_shape.name = "Collision_" + VoxelType.keys()[voxel_type]
	
	return collision_shape

func add_collision_face(face: int, x: int, y: int, z: int, vertices: PackedVector3Array, indices: PackedInt32Array, start_index: int):
	var pos = Vector3(x, y, z) * voxel_size
	var half_size = voxel_size * 0.5
	
	var face_vertices: PackedVector3Array
	
	match face:
		0: # Top
			face_vertices = PackedVector3Array([
				pos + Vector3(-half_size, half_size, -half_size),
				pos + Vector3(half_size, half_size, -half_size),
				pos + Vector3(half_size, half_size, half_size),
				pos + Vector3(-half_size, half_size, half_size)
			])
		1: # Bottom
			face_vertices = PackedVector3Array([
				pos + Vector3(-half_size, -half_size, half_size),
				pos + Vector3(half_size, -half_size, half_size),
				pos + Vector3(half_size, -half_size, -half_size),
				pos + Vector3(-half_size, -half_size, -half_size)
			])
		2: # Right
			face_vertices = PackedVector3Array([
				pos + Vector3(half_size, -half_size, -half_size),
				pos + Vector3(half_size, -half_size, half_size),
				pos + Vector3(half_size, half_size, half_size),
				pos + Vector3(half_size, half_size, -half_size)
			])
		3: # Left
			face_vertices = PackedVector3Array([
				pos + Vector3(-half_size, -half_size, half_size),
				pos + Vector3(-half_size, -half_size, -half_size),
				pos + Vector3(-half_size, half_size, -half_size),
				pos + Vector3(-half_size, half_size, half_size)
			])
		4: # Front (North) - negative Z
			face_vertices = PackedVector3Array([
				pos + Vector3(half_size, -half_size, -half_size),
				pos + Vector3(-half_size, -half_size, -half_size),
				pos + Vector3(-half_size, half_size, -half_size),
				pos + Vector3(half_size, half_size, -half_size)
			])
		5: # Back (South) - positive Z
			face_vertices = PackedVector3Array([
				pos + Vector3(half_size, -half_size, half_size),
				pos + Vector3(-half_size, -half_size, half_size),
				pos + Vector3(-half_size, half_size, half_size),
				pos + Vector3(half_size, half_size, half_size)
			])
	
	# Add vertices
	for vertex in face_vertices:
		vertices.append(vertex)
	
	# Add indices for two triangles (same winding as visual mesh)
	indices.append(start_index)
	indices.append(start_index + 1)
	indices.append(start_index + 2)
	
	indices.append(start_index)
	indices.append(start_index + 2)
	indices.append(start_index + 3)

func regenerate_map():
	setup_noise()
	generate_map()