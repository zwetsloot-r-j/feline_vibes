extends Node3D

@export var map_size: Vector3i = Vector3i(64, 16, 64)
@export var voxel_size: float = 1.0
@export var noise_scale: float = 0.1
@export var water_level: int = 4
@export var grass_level: int = 8
@export var generate_on_start: bool = true
@export var render_distance: float = 32.0  # Distance from player to render voxels
@export var player: Node3D  # Reference to player for distance calculations
@export var chunk_size: int = 16  # Size of chunks for efficient rendering
@export var max_chunks_per_frame: int = 1  # Limit chunks generated per frame

enum VoxelType {
	AIR,
	WATER,
	SAND,
	DIRT,
	GRASS
}

var noise: FastNoiseLite
var voxel_data: Dictionary = {}  # Change to Dictionary for sparse storage
var materials: Array[StandardMaterial3D]
var last_player_position: Vector3 = Vector3.ZERO
var update_timer: float = 0.0
var update_interval: float = 1.0  # Update mesh every 1 second (less frequent)
var active_chunks: Dictionary = {}  # Track which chunks are currently rendered
var chunk_nodes: Dictionary = {}  # Store chunk mesh nodes
var generated_chunks: Dictionary = {}  # Track which chunks have voxel data generated

# Chunk generation queue for frame-limited processing
var chunk_generation_queue: Array[Vector3i] = []
var initial_generation_complete: bool = false

signal initial_map_generation_complete

# Performance tracking
var performance_stats: Dictionary = {
	"chunk_data_generation_time": 0.0,
	"mesh_generation_time": 0.0,
	"collision_generation_time": 0.0,
	"total_chunks_generated": 0,
	"total_voxels_processed": 0,
	"total_faces_generated": 0
}

func _ready():
	setup_noise()
	create_materials()
	if generate_on_start:
		generate_map()
	
	# Try to find player if not set
	if not player:
		player = get_parent().get_node_or_null("Player")

func _process(delta):
	# Process chunk generation queue (limited per frame)
	process_chunk_generation_queue()
	
	if not player:
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		
		# Check if player has moved significantly
		var current_position = player.global_position
		var distance_moved = current_position.distance_to(last_player_position)
		
		if distance_moved > chunk_size * voxel_size * 0.5:  # Update if moved half a chunk
			last_player_position = current_position
			update_rendered_chunks()

func process_chunk_generation_queue():
	var chunks_processed = 0
	
	while chunk_generation_queue.size() > 0 and chunks_processed < max_chunks_per_frame:
		var chunk_coord = chunk_generation_queue.pop_front()
		
		# Skip if chunk is already generated or no longer needed
		if chunk_coord in active_chunks:
			continue
		
		# Check if chunk is still within render distance
		var needed_chunks = get_chunks_in_range()
		if chunk_coord in needed_chunks:
			generate_chunk_immediate(chunk_coord)
			chunks_processed += 1
		
	if chunk_generation_queue.size() > 0:
		print("Chunk queue remaining: ", chunk_generation_queue.size(), " chunks")
	elif not initial_generation_complete and generate_on_start:
		# Check if we have enough active chunks around the player before declaring complete
		check_initial_generation_complete()

func check_initial_generation_complete():
	if not player:
		return
	
	# Check if we have enough chunks with collision around the player
	var player_chunk = get_chunk_coord(player.global_position)
	var required_chunks_radius = 2  # Need at least 2 chunks radius around player
	var chunks_with_collision = 0
	var total_required_chunks = 0
	
	# Check chunks in a radius around the player
	for x in range(player_chunk.x - required_chunks_radius, player_chunk.x + required_chunks_radius + 1):
		for z in range(player_chunk.z - required_chunks_radius, player_chunk.z + required_chunks_radius + 1):
			# Only check chunks at or below player level (collision important for landing)
			for y in range(player_chunk.y - 1, player_chunk.y + 2):
				var chunk_coord = Vector3i(x, y, z)
				total_required_chunks += 1
				
				# Check if this chunk is active (has collision)
				if chunk_coord in active_chunks:
					chunks_with_collision += 1
	
	print("DEBUG: Initial generation check - chunks with collision: ", chunks_with_collision, "/", total_required_chunks)
	
	# Require at least 80% of nearby chunks to be active with collision
	var completion_threshold = int(total_required_chunks * 0.8)
	if chunks_with_collision >= completion_threshold:
		initial_generation_complete = true
		print("=== INITIAL MAP GENERATION COMPLETE ===")
		print("Active chunks around player: ", chunks_with_collision, "/", total_required_chunks)
		initial_map_generation_complete.emit()

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
	
	# WATER - Blue (voxel style with simple lighting)
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.3, 0.5, 0.9, 0.7)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.metallic = 0.0
	water_mat.roughness = 1.0
	water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX  # Sharp shadows
	water_mat.flags_use_point_size = false
	water_mat.flags_world_triplanar = false
	materials.append(water_mat)
	
	# SAND - Light brown (voxel style with simple lighting)
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.95, 0.85, 0.7, 1.0)
	sand_mat.metallic = 0.0
	sand_mat.roughness = 1.0
	sand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX  # Sharp shadows
	sand_mat.flags_use_point_size = false
	materials.append(sand_mat)
	
	# DIRT - Dark brown (voxel style with simple lighting)
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.45, 0.3, 0.15, 1.0)
	dirt_mat.metallic = 0.0
	dirt_mat.roughness = 1.0
	dirt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX  # Sharp shadows
	dirt_mat.flags_use_point_size = false
	materials.append(dirt_mat)
	
	# GRASS - Green (voxel style with simple lighting)
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.3, 0.8, 0.3, 1.0)
	grass_mat.metallic = 0.0
	grass_mat.roughness = 1.0
	grass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX  # Sharp shadows
	grass_mat.flags_use_point_size = false
	materials.append(grass_mat)

func generate_map():
	print("Setting up voxel generation system...")
	
	# Clear any existing data
	voxel_data.clear()
	generated_chunks.clear()
	
	# Generate initial chunks around player
	if player:
		last_player_position = player.global_position
		update_rendered_chunks()
	else:
		# Generate a small area around origin if no player
		generate_chunk_data(Vector3i(0, 0, 0))
		generate_mesh()
	print("Voxel generation system ready!")

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

func generate_chunk_data(chunk_coord: Vector3i):
	# Skip if already generated
	if chunk_coord in generated_chunks:
		return
	
	var start_ticks = Time.get_ticks_msec()
	print("Generating voxel data for chunk: ", chunk_coord)
	
	# Calculate chunk boundaries
	var chunk_start = Vector3i(
		chunk_coord.x * chunk_size,
		chunk_coord.y * chunk_size,
		chunk_coord.z * chunk_size
	)
	var chunk_end = Vector3i(
		min(chunk_start.x + chunk_size, map_size.x),
		min(chunk_start.y + chunk_size, map_size.y),
		min(chunk_start.z + chunk_size, map_size.z)
	)
	
	# Generate voxel data for this chunk only
	for x in range(chunk_start.x, chunk_end.x):
		for z in range(chunk_start.z, chunk_end.z):
			# Get height from noise (0 to map_size.y)
			var noise_value = noise.get_noise_2d(x, z)
			var height = int((noise_value + 1.0) * 0.5 * map_size.y)
			height = clamp(height, 0, map_size.y - 1)
			
			# Fill voxels based on height and rules
			for y in range(chunk_start.y, chunk_end.y):
				var voxel_type = determine_voxel_type(x, y, z, height)
				set_voxel(x, y, z, voxel_type)
	
	# Mark chunk as generated
	generated_chunks[chunk_coord] = true
	
	# Performance tracking
	var end_ticks = Time.get_ticks_msec()
	var generation_time = end_ticks - start_ticks
	performance_stats["chunk_data_generation_time"] += generation_time
	performance_stats["total_voxels_processed"] += chunk_size * chunk_size * chunk_size
	
	print("Chunk data generation took: ", generation_time, "ms")

func set_voxel(x: int, y: int, z: int, voxel_type: VoxelType):
	# Create nested structure as needed
	if not voxel_data.has(x):
		voxel_data[x] = {}
	if not voxel_data[x].has(y):
		voxel_data[x][y] = {}
	voxel_data[x][y][z] = voxel_type

func get_voxel(x: int, y: int, z: int) -> VoxelType:
	# Return AIR if voxel data doesn't exist (chunk not generated)
	if not voxel_data.has(x):
		return VoxelType.AIR
	if not voxel_data[x].has(y):
		return VoxelType.AIR
	if not voxel_data[x][y].has(z):
		return VoxelType.AIR
	return voxel_data[x][y][z]

func is_voxel_in_render_distance(x: int, y: int, z: int) -> bool:
	if not player:
		return true  # Render all if no player reference
	
	var voxel_world_pos = Vector3(x, y, z) * voxel_size
	var player_pos = player.global_position
	var distance_squared = voxel_world_pos.distance_squared_to(player_pos)
	var render_distance_squared = render_distance * render_distance
	
	return distance_squared <= render_distance_squared

func get_chunk_coord(world_pos: Vector3) -> Vector3i:
	# Convert world position to chunk coordinates
	return Vector3i(
		int(world_pos.x / (chunk_size * voxel_size)),
		int(world_pos.y / (chunk_size * voxel_size)),
		int(world_pos.z / (chunk_size * voxel_size))
	)

func get_chunks_in_range() -> Array[Vector3i]:
	if not player:
		return []
	
	var chunks: Array[Vector3i] = []
	var player_chunk = get_chunk_coord(player.global_position)
	var base_chunk_distance = int(render_distance / (chunk_size * voxel_size)) + 1
	
	# Asymmetric rendering based on camera view direction
	# Camera looks toward negative Z (north) and downward, so we want:
	# - More chunks north (-Z) and up (+Y) toward horizon
	# - Fewer chunks south (+Z) and down (-Y) away from camera view
	var x_range = base_chunk_distance
	var y_up_range = int(base_chunk_distance * 1.5)    # 50% more chunks upward (horizon)
	var y_down_range = int(base_chunk_distance * 0.7)  # 30% fewer chunks downward (ground)
	var z_north_range = int(base_chunk_distance * 1.4)  # 40% more chunks north (-Z direction)
	var z_south_range = int(base_chunk_distance * 0.6)  # 40% fewer chunks south (+Z direction)
	
	for x in range(player_chunk.x - x_range, player_chunk.x + x_range + 1):
		for y in range(player_chunk.y - y_down_range, player_chunk.y + y_up_range + 1):
			for z in range(player_chunk.z - z_north_range, player_chunk.z + z_south_range + 1):
				var chunk_coord = Vector3i(x, y, z)
				var chunk_world_pos = Vector3(x * chunk_size * voxel_size, y * chunk_size * voxel_size, z * chunk_size * voxel_size)
				
				# Use asymmetric distance check based on direction
				var offset_from_player = chunk_world_pos - player.global_position
				var distance_limit = render_distance
				
				# Increase distance limit for north/upward chunks (toward horizon)
				if offset_from_player.z < 0 or offset_from_player.y > 0:
					distance_limit *= 1.3  # 30% more distance for north/horizon chunks
				# Decrease distance limit for south/downward chunks (away from camera)
				elif offset_from_player.z > 0 or offset_from_player.y < -5:
					distance_limit *= 0.7  # 30% less distance for south/underground chunks
				
				if chunk_world_pos.distance_to(player.global_position) <= distance_limit + chunk_size * voxel_size:
					chunks.append(chunk_coord)
	
	return chunks

func update_rendered_chunks():
	print("Updating rendered chunks around player position: ", last_player_position)
	
	var needed_chunks = get_chunks_in_range()
	var current_chunks = active_chunks.keys()
	
	# Remove chunks that are no longer needed
	for chunk_coord in current_chunks:
		if chunk_coord not in needed_chunks:
			remove_chunk(chunk_coord)
	
	# Queue new chunks that are needed (instead of generating immediately)
	var chunks_to_add = []
	for chunk_coord in needed_chunks:
		if chunk_coord not in active_chunks and chunk_coord not in chunk_generation_queue:
			chunks_to_add.append(chunk_coord)
	
	# Sort chunks by distance to player (closest first)
	if player:
		chunks_to_add.sort_custom(func(a, b): 
			var pos_a = Vector3(a.x * chunk_size * voxel_size, a.y * chunk_size * voxel_size, a.z * chunk_size * voxel_size)
			var pos_b = Vector3(b.x * chunk_size * voxel_size, b.y * chunk_size * voxel_size, b.z * chunk_size * voxel_size)
			return pos_a.distance_squared_to(player.global_position) < pos_b.distance_squared_to(player.global_position)
		)
	
	# Add to queue
	for chunk_coord in chunks_to_add:
		chunk_generation_queue.append(chunk_coord)
	
	print("Active chunks: ", active_chunks.size(), ", Queued chunks: ", chunk_generation_queue.size())

func generate_chunk(chunk_coord: Vector3i):
	# Add to queue instead of generating immediately
	if chunk_coord not in active_chunks and chunk_coord not in chunk_generation_queue:
		chunk_generation_queue.append(chunk_coord)

func generate_chunk_immediate(chunk_coord: Vector3i):
	var total_start_time = Time.get_ticks_msec()
	print("=== Starting chunk generation for: ", chunk_coord, " ===")
	
	# Generate voxel data for this chunk if not already done
	generate_chunk_data(chunk_coord)
	
	# Also generate neighboring chunks for proper face culling
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			for z_offset in range(-1, 2):
				var neighbor_chunk = chunk_coord + Vector3i(x_offset, y_offset, z_offset)
				generate_chunk_data(neighbor_chunk)
	
	# Create a node to hold this chunk's meshes
	var chunk_node = Node3D.new()
	chunk_node.name = "Chunk_" + str(chunk_coord.x) + "_" + str(chunk_coord.y) + "_" + str(chunk_coord.z)
	add_child(chunk_node)
	
	# Create collision body for this chunk
	var static_body = StaticBody3D.new()
	static_body.name = "ChunkCollision"
	chunk_node.add_child(static_body)
	
	# Generate mesh for each voxel type in this chunk
	for voxel_type in range(VoxelType.WATER, VoxelType.GRASS + 1):
		if voxel_type == VoxelType.AIR:
			continue
		
		var mesh_instance = create_chunk_mesh_for_type(chunk_coord, voxel_type)
		if mesh_instance:
			chunk_node.add_child(mesh_instance)
			
			# Add collision for solid voxels (not water)
			if voxel_type != VoxelType.WATER:
				var collision_shape = create_chunk_collision_for_type(chunk_coord, voxel_type)
				if collision_shape:
					static_body.add_child(collision_shape)
	
	# Store references
	active_chunks[chunk_coord] = true
	chunk_nodes[chunk_coord] = chunk_node
	
	# Performance tracking
	var total_end_time = Time.get_ticks_msec()
	var total_time = total_end_time - total_start_time
	performance_stats["total_chunks_generated"] += 1
	
	print("=== Total chunk generation took: ", total_time, "ms ===")
	print_performance_summary()

func remove_chunk(chunk_coord: Vector3i):
	if chunk_coord in chunk_nodes:
		chunk_nodes[chunk_coord].queue_free()
		chunk_nodes.erase(chunk_coord)
	
	active_chunks.erase(chunk_coord)

func create_chunk_mesh_for_type(chunk_coord: Vector3i, voxel_type: VoxelType) -> MeshInstance3D:
	var mesh_start_time = Time.get_ticks_msec()
	
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var indices: PackedInt32Array = []
	
	var vertex_count = 0
	var faces_generated = 0
	
	# Calculate chunk boundaries
	var chunk_start = Vector3i(
		chunk_coord.x * chunk_size,
		chunk_coord.y * chunk_size,
		chunk_coord.z * chunk_size
	)
	var chunk_end = Vector3i(
		min(chunk_start.x + chunk_size, map_size.x),
		min(chunk_start.y + chunk_size, map_size.y),
		min(chunk_start.z + chunk_size, map_size.z)
	)
	
	# Only iterate through voxels in this chunk
	for x in range(chunk_start.x, chunk_end.x):
		for y in range(chunk_start.y, chunk_end.y):
			for z in range(chunk_start.z, chunk_end.z):
				if x >= map_size.x or y >= map_size.y or z >= map_size.z:
					continue
				if get_voxel(x, y, z) != voxel_type:
					continue
				
				# Check each face of the voxel
				var faces_to_render = get_visible_faces(x, y, z, voxel_type)
				
				for face in faces_to_render:
					add_face_to_mesh(face, x, y, z, vertices, normals, indices, vertex_count)
					vertex_count += 4
					faces_generated += 1
	
	if vertices.size() == 0:
		return null
	
	# Create mesh (no UVs for voxel style)
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = materials[voxel_type]
	mesh_instance.name = "ChunkMesh_" + VoxelType.keys()[voxel_type]
	
	# Performance tracking
	var mesh_end_time = Time.get_ticks_msec()
	var mesh_time = mesh_end_time - mesh_start_time
	performance_stats["mesh_generation_time"] += mesh_time
	performance_stats["total_faces_generated"] += faces_generated
	
	print("  Mesh for ", VoxelType.keys()[voxel_type], " took: ", mesh_time, "ms (", faces_generated, " faces)")
	
	return mesh_instance

func create_chunk_collision_for_type(chunk_coord: Vector3i, voxel_type: VoxelType) -> CollisionShape3D:
	var collision_start_time = Time.get_ticks_msec()
	
	var collision_vertices: PackedVector3Array = []
	var collision_indices: PackedInt32Array = []
	var vertex_count = 0
	
	# Calculate chunk boundaries
	var chunk_start = Vector3i(
		chunk_coord.x * chunk_size,
		chunk_coord.y * chunk_size,
		chunk_coord.z * chunk_size
	)
	var chunk_end = Vector3i(
		min(chunk_start.x + chunk_size, map_size.x),
		min(chunk_start.y + chunk_size, map_size.y),
		min(chunk_start.z + chunk_size, map_size.z)
	)
	
	# Only iterate through voxels in this chunk
	for x in range(chunk_start.x, chunk_end.x):
		for y in range(chunk_start.y, chunk_end.y):
			for z in range(chunk_start.z, chunk_end.z):
				if x >= map_size.x or y >= map_size.y or z >= map_size.z:
					continue
				if get_voxel(x, y, z) != voxel_type:
					continue
				
				# Check each face of the voxel for collision
				var faces_to_collide = get_collision_faces(x, y, z, voxel_type)
				
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
	collision_shape.name = "ChunkCollision_" + VoxelType.keys()[voxel_type]
	
	# Performance tracking
	var collision_end_time = Time.get_ticks_msec()
	var collision_time = collision_end_time - collision_start_time
	performance_stats["collision_generation_time"] += collision_time
	
	print("  Collision for ", VoxelType.keys()[voxel_type], " took: ", collision_time, "ms (", triangle_vertices.size()/3, " triangles)")
	
	return collision_shape

func print_performance_summary():
	print("=== PERFORMANCE SUMMARY ===")
	print("Total chunks generated: ", performance_stats["total_chunks_generated"])
	print("Total voxels processed: ", performance_stats["total_voxels_processed"])
	print("Total faces generated: ", performance_stats["total_faces_generated"])
	print("Time breakdown:")
	print("  Data generation: ", performance_stats["chunk_data_generation_time"], "ms")
	print("  Mesh generation: ", performance_stats["mesh_generation_time"], "ms") 
	print("  Collision generation: ", performance_stats["collision_generation_time"], "ms")
	var total_time = performance_stats["chunk_data_generation_time"] + performance_stats["mesh_generation_time"] + performance_stats["collision_generation_time"]
	print("  Total: ", total_time, "ms")
	
	if performance_stats["total_chunks_generated"] > 0:
		print("Average per chunk: ", total_time / performance_stats["total_chunks_generated"], "ms")
	if performance_stats["total_faces_generated"] > 0:
		print("Average per face: ", performance_stats["mesh_generation_time"] / performance_stats["total_faces_generated"], "ms")
	print("==========================")

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
	var indices: PackedInt32Array = []
	
	var vertex_count = 0
	
	# Iterate through all voxels
	for x in map_size.x:
		for y in map_size.y:
			for z in map_size.z:
				if get_voxel(x, y, z) != voxel_type:
					continue
				
				# Only render voxels within distance of player
				if not is_voxel_in_render_distance(x, y, z):
					continue
				
				# Check each face of the voxel
				var faces_to_render = get_visible_faces(x, y, z, voxel_type)
				
				for face in faces_to_render:
					add_face_to_mesh(face, x, y, z, vertices, normals, indices, vertex_count)
					vertex_count += 4
	
	if vertices.size() == 0:
		return null
	
	# Create mesh (no UVs for voxel style)
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
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
		
		var neighbor_type = get_voxel(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z)
		
		# Render face if neighbor is air or transparent
		if neighbor_type == VoxelType.AIR or (voxel_type != VoxelType.WATER and neighbor_type == VoxelType.WATER):
			visible_faces.append(i)
	
	return visible_faces

func get_collision_faces(x: int, y: int, z: int, voxel_type: VoxelType) -> Array[int]:
	var collision_faces: Array[int] = []
	
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
		
		# Always create collision at world boundaries
		if (neighbor_pos.x < 0 or neighbor_pos.x >= map_size.x or
			neighbor_pos.y < 0 or neighbor_pos.y >= map_size.y or
			neighbor_pos.z < 0 or neighbor_pos.z >= map_size.z):
			collision_faces.append(i)
			continue
		
		var neighbor_type = get_voxel(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z)
		
		# Create collision face if neighbor is air or water (walkable/non-solid)
		if neighbor_type == VoxelType.AIR or neighbor_type == VoxelType.WATER:
			collision_faces.append(i)
	
	return collision_faces

func add_face_to_mesh(face: int, x: int, y: int, z: int, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, start_index: int):
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
				if get_voxel(x, y, z) != voxel_type:
					continue
				
				# Only create collision for voxels within distance of player
				if not is_voxel_in_render_distance(x, y, z):
					continue
				
				# Check each face of the voxel for collision
				var faces_to_collide = get_collision_faces(x, y, z, voxel_type)
				
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