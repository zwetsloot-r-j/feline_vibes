extends RefCounted
class_name VoxelMeshLoader

static func load_obj_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("OBJ file not found: " + file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var vertices: Array = []
	var texture_coords: Array = []
	var faces: Array = []
	var groups: Dictionary = {}
	var current_group = "default"
	var current_material = ""
	var mtllib_file = ""
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("v "):
			var parts = line.split(" ")
			if parts.size() >= 4:
				var vertex = Vector3(
					parts[1].to_float(),
					parts[2].to_float(),
					parts[3].to_float()
				)
				vertices.append(vertex)
		
		elif line.begins_with("vt "):
			var parts = line.split(" ")
			if parts.size() >= 3:
				var uv = Vector2(
					parts[1].to_float(),
					parts[2].to_float()
				)
				texture_coords.append(uv)
		
		elif line.begins_with("mtllib "):
			var parts = line.split(" ")
			if parts.size() >= 2:
				mtllib_file = parts[1]
		
		elif line.begins_with("usemtl "):
			var parts = line.split(" ")
			if parts.size() >= 2:
				current_material = parts[1]
		
		elif line.begins_with("f "):
			var parts = line.split(" ")
			var face_indices: Array = []
			var face_uvs: Array = []
			
			for i in range(1, parts.size()):
				var vertex_data = parts[i].split("/")
				var vertex_index = vertex_data[0].to_int() - 1
				if vertex_index >= 0 and vertex_index < vertices.size():
					face_indices.append(vertex_index)
					
					# Handle texture coordinates if present
					if vertex_data.size() > 1 and vertex_data[1] != "":
						var uv_index = vertex_data[1].to_int() - 1
						if uv_index >= 0 and uv_index < texture_coords.size():
							face_uvs.append(texture_coords[uv_index])
						else:
							face_uvs.append(Vector2.ZERO)
					else:
						face_uvs.append(Vector2.ZERO)
			
			if face_indices.size() >= 3:
				var face_data = {
					"vertices": face_indices,
					"uvs": face_uvs,
					"material": current_material
				}
				faces.append(face_data)
				
				if not current_group in groups:
					groups[current_group] = []
				groups[current_group].append(faces.size() - 1)
		
		elif line.begins_with("g ") or line.begins_with("o "):
			var parts = line.split(" ")
			if parts.size() >= 2:
				current_group = parts[1]
	
	file.close()
	
	# Load material data if available
	var materials = {}
	
	# Look for companion files in assets/models folder
	var obj_filename = file_path.get_file().get_basename()
	materials = load_companion_files_from_assets(obj_filename, mtllib_file)
	
	return {
		"vertices": vertices,
		"texture_coords": texture_coords,
		"faces": faces,
		"groups": groups,
		"materials": materials,
		"mtllib": mtllib_file,
		"obj_path": file_path
	}

static func convert_obj_to_voxels(obj_data: Dictionary, auto_group_parts: bool = true, preserve_position: bool = true) -> Dictionary:
	if obj_data.is_empty():
		return {}
	
	var vertices = obj_data.vertices
	var faces = obj_data.faces
	var groups = obj_data.groups
	var materials = obj_data.get("materials", {})
	
	# Choose offset strategy based on preserve_position flag
	var offset = Vector3.ZERO
	if not preserve_position:
		# Legacy behavior: move to origin
		var bounds = calculate_bounds(vertices)
		offset = -bounds.position
	
	
	var all_voxels = voxelize_mesh_with_faces_colored(vertices, faces, offset, materials, obj_data.get("obj_path", ""))
	
	var result = {}
	
	if auto_group_parts and groups.size() > 1:
		for group_name in groups:
			var group_face_indices = groups[group_name]
			var group_voxels = voxelize_mesh_with_faces_by_indices_colored(vertices, faces, group_face_indices, offset, materials, obj_data.get("obj_path", ""))
			var part_name = sanitize_part_name(group_name)
			result[part_name] = group_voxels
	else:
		result["main"] = all_voxels
	
	return result

static func calculate_bounds(vertices: Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	
	var min_pos = vertices[0]
	var max_pos = vertices[0]
	
	for vertex in vertices:
		min_pos = min_pos.min(vertex)
		max_pos = max_pos.max(vertex)
	
	return AABB(min_pos, max_pos - min_pos)

static func load_companion_files_from_assets(obj_filename: String, mtllib_file: String) -> Dictionary:
	var assets_dir = "res://assets/models/"
	var materials = {}
	
	# First, try to find MTL file
	var mtl_candidates = []
	if mtllib_file != "":
		mtl_candidates.append(mtllib_file)
	mtl_candidates.append(obj_filename + ".mtl")
	
	for mtl_candidate in mtl_candidates:
		var mtl_path = assets_dir + mtl_candidate
		if FileAccess.file_exists(mtl_path):
			materials = load_mtl_file(mtl_path)
			break
	
	
	return materials

static func load_mtl_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var materials = {}
	var current_material = ""
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("newmtl "):
			var parts = line.split(" ")
			if parts.size() >= 2:
				current_material = parts[1]
				materials[current_material] = {
					"diffuse_color": Color.WHITE,
					"texture_path": ""
				}
		
		elif line.begins_with("Kd ") and current_material != "":
			var parts = line.split(" ")
			if parts.size() >= 4:
				var color = Color(
					parts[1].to_float(),
					parts[2].to_float(),
					parts[3].to_float()
				)
				materials[current_material]["diffuse_color"] = color
		
		elif line.begins_with("map_Kd ") and current_material != "":
			var parts = line.split(" ")
			if parts.size() >= 2:
				materials[current_material]["texture_path"] = parts[1]
	
	file.close()
	return materials

static func load_texture_from_path(base_path: String, texture_filename: String) -> Image:
	var image = Image.new()
	var error = OK
	
	# Try to load from assets/models directory
	var assets_texture_path = "res://assets/models/" + texture_filename
	if FileAccess.file_exists(assets_texture_path):
		error = image.load(assets_texture_path)
		if error == OK:
			return image
	
	# Try with .png extension in assets directory
	if not texture_filename.ends_with(".png"):
		var assets_png_path = "res://assets/models/" + texture_filename + ".png"
		if FileAccess.file_exists(assets_png_path):
			error = image.load(assets_png_path)
			if error == OK:
				return image
	
	# Fallback: look for any PNG/JPG in assets directory that might match
	var dir = DirAccess.open("res://assets/models/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var lower_name = file_name.to_lower()
			var lower_search = texture_filename.to_lower()
			if (lower_name.ends_with(".png") or lower_name.ends_with(".jpg")) and lower_search in lower_name:
				var fallback_path = "res://assets/models/" + file_name
				error = image.load(fallback_path)
				if error == OK:
					dir.list_dir_end()
					return image
			file_name = dir.get_next()
		dir.list_dir_end()
	
	return null

static func copy_companion_files_to_project(obj_path: String, mtllib_file: String, materials: Dictionary):
	var obj_dir = obj_path.get_base_dir()
	var obj_filename = obj_path.get_file().get_basename()
	
	print("DEBUG: Copying companion files from: ", obj_dir)
	print("DEBUG: OBJ filename: ", obj_filename)
	print("DEBUG: MTL file: ", mtllib_file)
	
	# Copy MTL file if it exists
	if mtllib_file != "":
		var source_mtl = obj_dir + "/" + mtllib_file
		var target_mtl = "res://" + mtllib_file
		
		print("DEBUG: Checking MTL source: ", source_mtl)
		print("DEBUG: Checking MTL target: ", target_mtl)
		
		if FileAccess.file_exists(source_mtl):
			print("DEBUG: Source MTL exists")
			if not FileAccess.file_exists(target_mtl):
				print("DEBUG: Target MTL doesn't exist, copying...")
				copy_file_to_project(source_mtl, target_mtl)
				print("Copied MTL file: " + target_mtl)
			else:
				print("DEBUG: Target MTL already exists")
		else:
			print("DEBUG: Source MTL doesn't exist")
	
	# Copy texture files referenced in materials
	for material_name in materials:
		var material = materials[material_name]
		var texture_path = material.get("texture_path", "")
		if texture_path != "":
			var source_texture = obj_dir + "/" + texture_path
			var target_texture = "res://" + texture_path
			
			print("DEBUG: Checking texture source: ", source_texture)
			
			if FileAccess.file_exists(source_texture) and not FileAccess.file_exists(target_texture):
				copy_file_to_project(source_texture, target_texture)
				print("Copied texture file: " + target_texture)
	
	# Also try to copy common companion files based on OBJ filename
	var common_extensions = [".png", ".jpg", ".jpeg", ".bmp", ".tga"]
	for ext in common_extensions:
		var source_texture = obj_dir + "/" + obj_filename + ext
		var target_texture = "res://" + obj_filename + ext
		
		print("DEBUG: Checking companion texture: ", source_texture)
		
		if FileAccess.file_exists(source_texture):
			print("DEBUG: Found companion texture: ", source_texture)
			if not FileAccess.file_exists(target_texture):
				copy_file_to_project(source_texture, target_texture)
				print("Copied companion texture: " + target_texture)
			else:
				print("DEBUG: Target texture already exists")

static func auto_detect_companion_files(obj_path: String):
	var obj_dir = obj_path.get_base_dir()
	var obj_filename = obj_path.get_file().get_basename()
	
	print("DEBUG: Auto-detecting companion files for: ", obj_filename)
	
	# Try to find and copy MTL file with same name as OBJ
	var mtl_filename = obj_filename + ".mtl"
	var source_mtl = obj_dir + "/" + mtl_filename
	var target_mtl = "res://" + mtl_filename
	
	if FileAccess.file_exists(source_mtl):
		print("DEBUG: Found auto-detected MTL: ", source_mtl)
		if not FileAccess.file_exists(target_mtl):
			copy_file_to_project(source_mtl, target_mtl)
			print("Copied auto-detected MTL: " + target_mtl)
		
		# Now load the MTL file and copy its textures
		var materials = load_mtl_file(source_mtl)
		if materials.size() > 0:
			copy_companion_files_to_project(obj_path, mtl_filename, materials)
	
	# Try to find and copy texture files with same name as OBJ
	var common_extensions = [".png", ".jpg", ".jpeg", ".bmp", ".tga"]
	for ext in common_extensions:
		var source_texture = obj_dir + "/" + obj_filename + ext
		var target_texture = "res://" + obj_filename + ext
		
		if FileAccess.file_exists(source_texture):
			print("DEBUG: Found auto-detected texture: ", source_texture)
			if not FileAccess.file_exists(target_texture):
				copy_file_to_project(source_texture, target_texture)
				print("Copied auto-detected texture: " + target_texture)

static func copy_file_to_project(source_path: String, target_path: String):
	var source_file = FileAccess.open(source_path, FileAccess.READ)
	if not source_file:
		print("Failed to open source file: " + source_path)
		return
	
	var target_file = FileAccess.open(target_path, FileAccess.WRITE)
	if not target_file:
		print("Failed to create target file: " + target_path)
		source_file.close()
		return
	
	var buffer = source_file.get_buffer(source_file.get_length())
	target_file.store_buffer(buffer)
	
	source_file.close()
	target_file.close()
	
	print("Successfully copied: " + source_path + " -> " + target_path)

static func sample_texture_color(image: Image, uv: Vector2) -> Color:
	if not image:
		return Color.WHITE
	
	var width = image.get_width()
	var height = image.get_height()
	
	# Handle UV wrapping
	var u = fmod(uv.x, 1.0)
	var v = fmod(uv.y, 1.0)
	if u < 0: u += 1.0
	if v < 0: v += 1.0
	
	# Convert to pixel coordinates
	var x = int(u * width) % width
	var y = int((1.0 - v) * height) % height  # Flip V coordinate
	
	return image.get_pixel(x, y)

static func detect_box_shapes(vertices: Array, faces: Array, offset: Vector3) -> Array:
	var boxes: Array = []
	
	print("  Detecting box shapes from ", faces.size(), " faces")
	
	if vertices.size() == 0 or faces.size() == 0:
		return boxes
	
	# Step 1: Process faces using original coordinates (don't apply offset yet)
	var face_data = []
	for face_indices in faces:
		if face_indices.size() < 3:
			continue
		
		var face_vertices = []
		for idx in face_indices:
			if idx < vertices.size():
				face_vertices.append(vertices[idx])  # Use original coordinates
		
		if face_vertices.size() >= 3:
			var normal = calculate_face_normal(face_vertices)
			var center = calculate_face_center(face_vertices)
			var bounds = calculate_face_bounds(face_vertices)
			
			face_data.append({
				"vertices": face_vertices,
				"normal": normal,
				"center": center,
				"bounds": bounds,
				"indices": face_indices
			})
	
	print("    Processed ", face_data.size(), " valid faces")
	
	# Step 2: Group faces by their axis-aligned normals
	var face_groups = group_faces_by_normal(face_data)
	
	# Step 3: Reconstruct boxes by finding opposite face pairs
	boxes = reconstruct_boxes_from_faces(face_groups)
	
	# Step 4: Remove duplicate boxes
	boxes = remove_duplicate_boxes(boxes)
	
	print("  Detected ", boxes.size(), " box shapes")
	return boxes

static func calculate_face_normal(face_vertices: Array) -> Vector3:
	if face_vertices.size() < 3:
		return Vector3.ZERO
	
	var v1 = face_vertices[1] - face_vertices[0]
	var v2 = face_vertices[2] - face_vertices[0]
	var normal = v1.cross(v2).normalized()
	
	# Snap to axis-aligned directions for box detection
	var abs_normal = Vector3(abs(normal.x), abs(normal.y), abs(normal.z))
	var max_component = max(abs_normal.x, max(abs_normal.y, abs_normal.z))
	
	if abs_normal.x == max_component:
		return Vector3(sign(normal.x), 0, 0)
	elif abs_normal.y == max_component:
		return Vector3(0, sign(normal.y), 0)
	else:
		return Vector3(0, 0, sign(normal.z))

static func calculate_face_center(face_vertices: Array) -> Vector3:
	var center = Vector3.ZERO
	for vertex in face_vertices:
		center += vertex
	return center / face_vertices.size()

static func calculate_face_bounds(face_vertices: Array) -> AABB:
	if face_vertices.size() == 0:
		return AABB()
	
	var min_pos = face_vertices[0]
	var max_pos = face_vertices[0]
	
	for vertex in face_vertices:
		min_pos = min_pos.min(vertex)
		max_pos = max_pos.max(vertex)
	
	return AABB(min_pos, max_pos - min_pos)

static func group_faces_by_normal(face_data: Array) -> Dictionary:
	var face_groups = {}
	
	for face in face_data:
		var normal_key = str(face.normal)
		if not normal_key in face_groups:
			face_groups[normal_key] = []
		face_groups[normal_key].append(face)
	
	print("    Grouped faces by normal: ", face_groups.keys())
	return face_groups

static func reconstruct_boxes_from_faces(face_groups: Dictionary) -> Array:
	var boxes = []
	
	# Alternative approach: Create boxes from connected face regions
	# This works better for complex shapes like staircases
	boxes = create_boxes_from_connected_regions(face_groups)
	
	if boxes.size() == 0:
		# Fallback: use the old opposite face pair method
		boxes = create_boxes_from_opposite_pairs(face_groups)
	
	return boxes

static func create_boxes_from_connected_regions(face_groups: Dictionary) -> Array:
	var boxes = []
	var all_faces = []
	
	# Collect all faces
	for faces in face_groups.values():
		all_faces.append_array(faces)
	
	print("    Analyzing ", all_faces.size(), " faces for volume sampling")
	
	# Try volume sampling approach for better segmentation of complex shapes
	boxes = create_boxes_from_volume_sampling(all_faces)
	
	return boxes

static func create_boxes_from_volume_sampling(all_faces: Array) -> Array:
	var boxes = []
	
	# Get all unique vertices to determine bounds
	var all_vertices = []
	for face in all_faces:
		for vertex in face.vertices:
			if not vertex in all_vertices:
				all_vertices.append(vertex)
	
	if all_vertices.size() == 0:
		return boxes
	
	# Calculate mesh bounds
	var min_pos = all_vertices[0]
	var max_pos = all_vertices[0]
	for vertex in all_vertices:
		min_pos = min_pos.min(vertex)
		max_pos = max_pos.max(vertex)
	
	print("    Mesh bounds: ", min_pos, " to ", max_pos)
	
	# Sample 3D grid at 0.1 voxel intervals
	var voxel_size = 0.1
	var occupied_voxels = []
	
	var min_voxel = Vector3i(
		int(floor(min_pos.x / voxel_size)),
		int(floor(min_pos.y / voxel_size)),
		int(floor(min_pos.z / voxel_size))
	)
	
	var max_voxel = Vector3i(
		int(ceil(max_pos.x / voxel_size)),
		int(ceil(max_pos.y / voxel_size)),
		int(ceil(max_pos.z / voxel_size))
	)
	
	print("    Sampling voxel grid from ", min_voxel, " to ", max_voxel)
	
	# Test each voxel position to see if it's inside the mesh
	for x in range(min_voxel.x, max_voxel.x + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for z in range(min_voxel.z, max_voxel.z + 1):
				var voxel_coord = Vector3i(x, y, z)
				var voxel_center = Vector3(
					x * voxel_size + voxel_size * 0.5,
					y * voxel_size + voxel_size * 0.5,
					z * voxel_size + voxel_size * 0.5
				)
				
				if is_point_inside_mesh(voxel_center, all_faces):
					occupied_voxels.append(voxel_coord)
	
	print("    Found ", occupied_voxels.size(), " occupied voxels")
	
	if occupied_voxels.size() > 0:
		# Group connected voxels into components to represent logical voxel units
		var components = find_connected_voxel_components(occupied_voxels)
		print("    Grouped into ", components.size(), " connected components")
		
		# Create one box per connected component
		for component in components:
			if component.size() == 1:
				# Single voxel component - create individual box
				var box = create_box_from_single_voxel(component[0], voxel_size)
				if box != null and box.size != Vector3.ZERO:
					boxes.append(box)
			else:
				# Multi-voxel component - create bounding box
				var box = create_box_from_voxel_coords(component, voxel_size)
				if box != null and box.size != Vector3.ZERO:
					boxes.append(box)
	else:
		# Fallback: treat each occupied voxel as an individual box
		for voxel_coord in occupied_voxels:
			var box = create_box_from_single_voxel(voxel_coord, voxel_size)
			if box != null and box.size != Vector3.ZERO:
				boxes.append(box)
	
	print("    Created ", boxes.size(), " individual voxel boxes")
	
	return boxes

static func create_box_from_single_voxel(voxel_coord: Vector3i, voxel_size: float) -> Dictionary:
	# Create a box for a single voxel at the given coordinate
	var min_pos = Vector3(
		voxel_coord.x * voxel_size,
		voxel_coord.y * voxel_size,
		voxel_coord.z * voxel_size
	)
	
	var max_pos = Vector3(
		(voxel_coord.x + 1) * voxel_size,
		(voxel_coord.y + 1) * voxel_size,
		(voxel_coord.z + 1) * voxel_size
	)
	
	return {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"size": max_pos - min_pos
	}

static func is_point_inside_mesh(point: Vector3, faces: Array) -> bool:
	# Normal-based approach for voxel detection
	# For voxel-based models where only outside surfaces are rendered,
	# face normals point outward from solid material
	
	var voxel_threshold = 0.05  # Half voxel size for 0.1 voxels
	var inside_evidence = 0
	var total_evidence = 0
	
	for face in faces:
		if face.vertices.size() < 3:
			continue
		
		var face_center = calculate_face_center(face.vertices)
		var normal = face.normal
		var distance_to_face = point.distance_to(face_center)
		
		# Only consider faces that are reasonably close to the test point
		if distance_to_face <= voxel_threshold * 2:
			total_evidence += 1
			
			# Vector from face center to test point
			var to_point = point - face_center
			
			# Project point onto face normal to get signed distance
			var signed_distance = to_point.dot(normal)
			
			# If signed distance is negative, point is on the inward side of the face
			# (opposite to normal direction), which indicates inside solid material
			if signed_distance <= 0:
				inside_evidence += 1
				print("    Point ", point, " is INSIDE face at ", face_center, " with normal ", normal, " (signed_dist: ", signed_distance, ")")
			else:
				print("    Point ", point, " is OUTSIDE face at ", face_center, " with normal ", normal, " (signed_dist: ", signed_distance, ")")
	
	# Decision logic: if majority of nearby faces indicate inside, consider point inside
	if total_evidence > 0:
		var inside_ratio = float(inside_evidence) / float(total_evidence)
		print("    Point ", point, " evidence: ", inside_evidence, "/", total_evidence, " = ", inside_ratio)
		return inside_ratio >= 0.5
	
	# If no faces are close enough, point is outside
	return false

static func point_is_within_face_bounds(point: Vector3, face: Dictionary) -> bool:
	# Project point onto face plane and check if it's within face bounds
	var face_center = calculate_face_center(face.vertices)
	var normal = face.normal
	
	# Project point onto face plane
	var to_point = point - face_center
	var projected_offset = to_point - normal * to_point.dot(normal)
	var projected_point = face_center + projected_offset
	
	# Check if projected point is within face bounds
	var bounds = face.bounds
	return (projected_point.x >= bounds.position.x and 
			projected_point.x <= bounds.position.x + bounds.size.x and
			projected_point.y >= bounds.position.y and 
			projected_point.y <= bounds.position.y + bounds.size.y and
			projected_point.z >= bounds.position.z and 
			projected_point.z <= bounds.position.z + bounds.size.z)

static func point_to_line_distance(point: Vector3, line_start: Vector3, line_end: Vector3) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	
	if line_vec.length() == 0:
		return point.distance_to(line_start)
	
	var t = point_vec.dot(line_vec) / line_vec.dot(line_vec)
	t = clamp(t, 0.0, 1.0)
	
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

static func voxelize_face_with_normal(face_vertices: Array) -> Array:
	# Generate voxels from a single triangle face using normal-based approach
	# Assumes the triangle is half of a perfect rectangle on a 0.1-unit voxel grid
	# Supports multiple voxels per face when edges span multiple voxel units
	# Returns array of Vector3i voxel positions with 0.1 unit dimensions
	
	var voxels = []
	var voxel_size = 0.1
	
	if face_vertices.size() < 3:
		return voxels
	
	# Calculate face properties
	var face_normal = calculate_face_normal(face_vertices)
	
	# Snap vertices to voxel grid to find the intended rectangle
	var snapped_vertices = []
	for vertex in face_vertices:
		var snapped = Vector3(
			round(vertex.x / voxel_size) * voxel_size,
			round(vertex.y / voxel_size) * voxel_size,
			round(vertex.z / voxel_size) * voxel_size
		)
		snapped_vertices.append(snapped)
	
	# Calculate the bounding rectangle from snapped vertices
	var min_pos = snapped_vertices[0]
	var max_pos = snapped_vertices[0]
	
	for vertex in snapped_vertices:
		min_pos = min_pos.min(vertex)
		max_pos = max_pos.max(vertex)
	
	# Convert to voxel grid coordinates
	var min_voxel = Vector3i(
		int(round(min_pos.x / voxel_size)),
		int(round(min_pos.y / voxel_size)),
		int(round(min_pos.z / voxel_size))
	)
	
	var max_voxel = Vector3i(
		int(round(max_pos.x / voxel_size)),
		int(round(max_pos.y / voxel_size)),
		int(round(max_pos.z / voxel_size))
	)
	
	
	# Generate voxels for the area covered by the face
	# The face vertices define the boundaries, so a face from 0.0 to 0.1 covers exactly 1 voxel
	
	# Calculate the number of voxels in each dimension
	var x_count = max(1, max_voxel.x - min_voxel.x)
	var y_count = max(1, max_voxel.y - min_voxel.y)
	var z_count = max(1, max_voxel.z - min_voxel.z)
	
	# Generate voxels for all positions in the rectangle
	for x in range(x_count):
		for y in range(y_count):
			for z in range(z_count):
				var base_voxel_position = Vector3i(min_voxel.x + x, min_voxel.y + y, min_voxel.z + z)
				
				
				# Adjust position based on face normal to place voxel on the solid side
				# For outward-facing normals, the solid voxel is in the opposite direction
				var voxel_position = base_voxel_position
				
				if face_normal.x > 0:
					voxel_position.x -= 1  # Solid voxel is to the left of +X face
				elif face_normal.x < 0:
					# For -X face, solid voxel is to the right, but base_position is already correct
					pass
				
				if face_normal.y > 0:
					voxel_position.y -= 1  # Solid voxel is below +Y face
				elif face_normal.y < 0:
					# For -Y face, solid voxel is above, but base_position is already correct
					pass
				
				if face_normal.z > 0:
					voxel_position.z -= 1  # Solid voxel is behind +Z face
				elif face_normal.z < 0:
					# For -Z face, solid voxel is in front, but base_position is already correct
					pass
				
				
				voxels.append(voxel_position)
	return voxels

static func is_voxel_near_triangle_face(voxel_center: Vector3, face_vertices: Array, face_normal: Vector3, voxel_size: float) -> bool:
	# Check if a voxel center is close enough to a triangle face to be considered part of it
	
	# First check: distance to face plane
	var face_center = calculate_face_center(face_vertices)
	var to_voxel = voxel_center - face_center
	var distance_to_plane = abs(to_voxel.dot(face_normal))
	
	# Voxel should be within half a voxel size of the face plane (with small tolerance for floating point)
	var plane_threshold = voxel_size * 0.51  # Slightly more than half to account for floating point precision
	if distance_to_plane > plane_threshold:
		return false
	
	# Second check: project voxel onto face plane and check if it's within triangle bounds
	var projected_point = voxel_center - face_normal * to_voxel.dot(face_normal)
	
	# Check if projected point is within the triangle or close to its edges
	var min_distance_to_triangle = INF
	
	# Distance to triangle vertices
	for vertex in face_vertices:
		var distance = projected_point.distance_to(vertex)
		min_distance_to_triangle = min(min_distance_to_triangle, distance)
	
	# Distance to triangle edges
	for i in range(face_vertices.size()):
		var v1 = face_vertices[i]
		var v2 = face_vertices[(i + 1) % face_vertices.size()]
		var edge_distance = point_to_line_distance(projected_point, v1, v2)
		min_distance_to_triangle = min(min_distance_to_triangle, edge_distance)
	
	# Voxel is considered part of the face if it's close to the triangle geometry
	var threshold = voxel_size * 0.7
	return min_distance_to_triangle <= threshold

static func find_connected_voxel_components(occupied_voxels: Array) -> Array:
	var components = []
	var processed = {}
	
	for voxel in occupied_voxels:
		var voxel_key = str(voxel)
		if voxel_key in processed:
			continue
		
		# Find all voxels connected to this one
		var component = find_connected_voxels(voxel, occupied_voxels, processed)
		if component.size() > 0:
			components.append(component)
	
	print("    Found ", components.size(), " connected components")
	return components

static func find_connected_voxels(start_voxel: Vector3i, all_voxels: Array, processed: Dictionary) -> Array:
	var connected = [start_voxel]
	var to_process = [start_voxel]
	var voxel_set = {}
	
	# Create a set for faster lookup
	for voxel in all_voxels:
		voxel_set[str(voxel)] = voxel
	
	processed[str(start_voxel)] = true
	
	while to_process.size() > 0:
		var current = to_process.pop_back()
		
		# Check all 6 adjacent voxel positions (face neighbors only)
		var neighbors = [
			current + Vector3i(1, 0, 0),
			current + Vector3i(-1, 0, 0),
			current + Vector3i(0, 1, 0),
			current + Vector3i(0, -1, 0),
			current + Vector3i(0, 0, 1),
			current + Vector3i(0, 0, -1)
		]
		
		for neighbor in neighbors:
			var neighbor_key = str(neighbor)
			if neighbor_key in voxel_set and not neighbor_key in processed:
				connected.append(neighbor)
				to_process.append(neighbor)
				processed[neighbor_key] = true
	
	return connected

static func create_box_from_voxel_coords(voxel_coords: Array, voxel_size: float) -> Dictionary:
	if voxel_coords.size() == 0:
		return {}
	
	# Calculate bounds of the voxel coordinates
	var min_coord = voxel_coords[0]
	var max_coord = voxel_coords[0]
	
	for coord in voxel_coords:
		if coord.x < min_coord.x: min_coord.x = coord.x
		if coord.y < min_coord.y: min_coord.y = coord.y
		if coord.z < min_coord.z: min_coord.z = coord.z
		if coord.x > max_coord.x: max_coord.x = coord.x
		if coord.y > max_coord.y: max_coord.y = coord.y
		if coord.z > max_coord.z: max_coord.z = coord.z
	
	# Convert voxel coordinates to world coordinates
	var min_pos = Vector3(
		min_coord.x * voxel_size,
		min_coord.y * voxel_size,
		min_coord.z * voxel_size
	)
	
	var max_pos = Vector3(
		(max_coord.x + 1) * voxel_size,
		(max_coord.y + 1) * voxel_size,
		(max_coord.z + 1) * voxel_size
	)
	
	return {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"size": max_pos - min_pos
	}

static func find_connected_clusters(start_cluster_key: String, voxel_clusters: Dictionary, processed_clusters: Dictionary) -> Array:
	var connected = [start_cluster_key]
	var to_process = [start_cluster_key]
	
	while to_process.size() > 0:
		var current_key = to_process.pop_back()
		var current_coord = str_to_vector3i(current_key)
		
		# Check all adjacent voxel coordinates
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx == 0 and dy == 0 and dz == 0:
						continue
					
					var adjacent_coord = current_coord + Vector3i(dx, dy, dz)
					var adjacent_key = str(adjacent_coord)
					
					if adjacent_key in voxel_clusters and not adjacent_key in connected and not adjacent_key in processed_clusters:
						connected.append(adjacent_key)
						to_process.append(adjacent_key)
	
	return connected

static func str_to_vector3i(s: String) -> Vector3i:
	# Parse string like "(1, 2, 3)" back to Vector3i
	var clean = s.replace("(", "").replace(")", "").replace(" ", "")
	var parts = clean.split(",")
	if parts.size() >= 3:
		return Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
	return Vector3i.ZERO

static func create_box_from_vertices(vertices: Array) -> Dictionary:
	if vertices.size() == 0:
		return {}
	
	# Calculate bounding box
	var min_pos = vertices[0]
	var max_pos = vertices[0]
	
	for vertex in vertices:
		min_pos = min_pos.min(vertex)
		max_pos = max_pos.max(vertex)
	
	# Ensure minimum volume
	var epsilon = 0.001
	if abs(max_pos.x - min_pos.x) < epsilon:
		max_pos.x += epsilon
		min_pos.x -= epsilon
	if abs(max_pos.y - min_pos.y) < epsilon:
		max_pos.y += epsilon
		min_pos.y -= epsilon
	if abs(max_pos.z - min_pos.z) < epsilon:
		max_pos.z += epsilon
		min_pos.z -= epsilon
	
	return {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"size": max_pos - min_pos
	}

static func find_connected_faces(start_face: Dictionary, all_faces: Array, processed_faces: Dictionary) -> Array:
	var connected = [start_face]
	var face_vertices = {}
	
	# Get all vertices from the starting face
	for vertex in start_face.vertices:
		var vertex_key = str(vertex)
		if not vertex_key in face_vertices:
			face_vertices[vertex_key] = []
		face_vertices[vertex_key].append(start_face)
	
	# Find faces that share vertices with our current set
	var changed = true
	while changed:
		changed = false
		for face in all_faces:
			var face_key = str(face.indices)
			if face_key in processed_faces or face in connected:
				continue
			
			# Check if this face shares vertices with our connected set
			var shares_vertices = false
			for vertex in face.vertices:
				var vertex_key = str(vertex)
				if vertex_key in face_vertices:
					shares_vertices = true
					break
			
			if shares_vertices:
				connected.append(face)
				changed = true
				
				# Add this face's vertices to our set
				for vertex in face.vertices:
					var vertex_key = str(vertex)
					if not vertex_key in face_vertices:
						face_vertices[vertex_key] = []
					face_vertices[vertex_key].append(face)
	
	return connected

static func create_box_from_face_group(faces: Array) -> Dictionary:
	var all_vertices = []
	
	# Collect all vertices from all faces
	for face in faces:
		for vertex in face.vertices:
			if not vertex in all_vertices:
				all_vertices.append(vertex)
	
	if all_vertices.size() == 0:
		return {}
	
	# Calculate bounding box
	var min_pos = all_vertices[0]
	var max_pos = all_vertices[0]
	
	for vertex in all_vertices:
		min_pos = min_pos.min(vertex)
		max_pos = max_pos.max(vertex)
	
	# Ensure minimum volume
	var epsilon = 0.001
	if abs(max_pos.x - min_pos.x) < epsilon:
		max_pos.x += epsilon
		min_pos.x -= epsilon
	if abs(max_pos.y - min_pos.y) < epsilon:
		max_pos.y += epsilon
		min_pos.y -= epsilon
	if abs(max_pos.z - min_pos.z) < epsilon:
		max_pos.z += epsilon
		min_pos.z -= epsilon
	
	return {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"size": max_pos - min_pos
	}

static func create_boxes_from_opposite_pairs(face_groups: Dictionary) -> Array:
	var boxes = []
	
	# Look for opposite face pairs to form boxes
	var normal_pairs = [
		[Vector3(1, 0, 0), Vector3(-1, 0, 0)],   # X-axis
		[Vector3(0, 1, 0), Vector3(0, -1, 0)],   # Y-axis
		[Vector3(0, 0, 1), Vector3(0, 0, -1)]    # Z-axis
	]
	
	var used_faces = {}
	
	for pair in normal_pairs:
		var pos_normal = pair[0]
		var neg_normal = pair[1]
		var pos_key = str(pos_normal)
		var neg_key = str(neg_normal)
		
		if pos_key in face_groups and neg_key in face_groups:
			var pos_faces = face_groups[pos_key]
			var neg_faces = face_groups[neg_key]
			
			# Try to match pairs of opposing faces
			for pos_face in pos_faces:
				var pos_face_key = str(pos_face.indices)
				if pos_face_key in used_faces:
					continue
				
				for neg_face in neg_faces:
					var neg_face_key = str(neg_face.indices)
					if neg_face_key in used_faces:
						continue
					
					# Check if faces are aligned and could be opposite faces of a box
					if faces_could_be_opposite(pos_face, neg_face):
						var box = create_box_from_opposite_faces(pos_face, neg_face)
						if box != null and box.size != Vector3.ZERO:
							boxes.append(box)
							used_faces[pos_face_key] = true
							used_faces[neg_face_key] = true
							print("    Created box from opposite faces: ", box)
							break
	
	# If no opposite pairs found, create boxes from individual face groups
	if boxes.size() == 0:
		print("    No opposite face pairs found, creating boxes from face bounds")
		for normal_key in face_groups:
			var faces = face_groups[normal_key]
			for face in faces:
				var face_key = str(face.indices)
				if face_key in used_faces:
					continue
				
				var box = create_box_from_single_face(face)
				if box != null:
					boxes.append(box)
					used_faces[face_key] = true
					print("    Created box from single face: ", box)
	
	return boxes

static func faces_could_be_opposite(face1: Dictionary, face2: Dictionary) -> bool:
	# Check if two faces could be opposite faces of the same box
	var bounds1 = face1.bounds
	var bounds2 = face2.bounds
	
	# For opposite faces, their bounding boxes should overlap in 2 dimensions
	# and be separated in the third dimension (normal direction)
	var normal1 = face1.normal
	
	# Check overlap in the two dimensions perpendicular to the normal
	if abs(normal1.x) == 1:  # X-normal faces
		return (bounds1.position.y < bounds2.position.y + bounds2.size.y and
				bounds1.position.y + bounds1.size.y > bounds2.position.y and
				bounds1.position.z < bounds2.position.z + bounds2.size.z and
				bounds1.position.z + bounds1.size.z > bounds2.position.z)
	elif abs(normal1.y) == 1:  # Y-normal faces
		return (bounds1.position.x < bounds2.position.x + bounds2.size.x and
				bounds1.position.x + bounds1.size.x > bounds2.position.x and
				bounds1.position.z < bounds2.position.z + bounds2.size.z and
				bounds1.position.z + bounds1.size.z > bounds2.position.z)
	else:  # Z-normal faces
		return (bounds1.position.x < bounds2.position.x + bounds2.size.x and
				bounds1.position.x + bounds1.size.x > bounds2.position.x and
				bounds1.position.y < bounds2.position.y + bounds2.size.y and
				bounds1.position.y + bounds1.size.y > bounds2.position.y)

static func create_box_from_opposite_faces(face1: Dictionary, face2: Dictionary) -> Dictionary:
	var bounds1 = face1.bounds
	var bounds2 = face2.bounds
	
	# Create a box that encompasses both faces
	var min_pos = bounds1.position.min(bounds2.position)
	var max_pos = (bounds1.position + bounds1.size).max(bounds2.position + bounds2.size)
	
	if max_pos.x == min_pos.x or max_pos.y == min_pos.y:
		return {
			"min_pos": Vector3.ZERO,
			"max_pos": Vector3.ZERO,
			"size": Vector3.ZERO,
		}
	
	# Ensure minimum volume
	var epsilon = 0.001
	if abs(max_pos.x - min_pos.x) < epsilon:
		max_pos.x += epsilon
		min_pos.x -= epsilon
	if abs(max_pos.y - min_pos.y) < epsilon:
		max_pos.y += epsilon
		min_pos.y -= epsilon
	if abs(max_pos.z - min_pos.z) < epsilon:
		max_pos.z += epsilon
		min_pos.z -= epsilon
	
	return {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"size": max_pos - min_pos
	}

static func create_box_from_single_face(face: Dictionary) -> Dictionary:
	var bounds = face.bounds
	var min_pos = bounds.position
	var max_pos = bounds.position + bounds.size
	
	# Ensure minimum volume in all dimensions
	var epsilon = 0.001
	if abs(max_pos.x - min_pos.x) < epsilon:
		max_pos.x += epsilon
		min_pos.x -= epsilon
	if abs(max_pos.y - min_pos.y) < epsilon:
		max_pos.y += epsilon
		min_pos.y -= epsilon
	if abs(max_pos.z - min_pos.z) < epsilon:
		max_pos.z += epsilon
		min_pos.z -= epsilon
	
	return {
		"min_pos": min_pos,
		"max_pos": max_pos,
		"size": max_pos - min_pos
	}

static func remove_duplicate_boxes(boxes: Array) -> Array:
	var unique_boxes = []
	var box_tolerance = 0.001
	
	for box in boxes:
		var is_duplicate = false
		
		for existing_box in unique_boxes:
			if boxes_are_similar(box, existing_box, box_tolerance):
				is_duplicate = true
				break
		
		if not is_duplicate:
			unique_boxes.append(box)
	
	print("    Removed duplicates: ", boxes.size(), " -> ", unique_boxes.size(), " boxes")
	return unique_boxes

static func boxes_are_similar(box1: Dictionary, box2: Dictionary, tolerance: float) -> bool:
	var min_diff = (box1.min_pos - box2.min_pos).length()
	var max_diff = (box1.max_pos - box2.max_pos).length()
	
	return min_diff < tolerance and max_diff < tolerance

static func divide_box_into_voxels(box: Dictionary) -> Array:
	var voxels: Array = []
	var voxel_size = 0.1
	
	var min_pos = box.min_pos
	var max_pos = box.max_pos
	
	# Calculate voxel grid bounds
	var min_voxel = Vector3i(
		int(floor(min_pos.x / voxel_size)),
		int(floor(min_pos.y / voxel_size)),
		int(floor(min_pos.z / voxel_size))
	)
	
	var max_voxel = Vector3i(
		int(ceil(max_pos.x / voxel_size)),
		int(ceil(max_pos.y / voxel_size)),
		int(ceil(max_pos.z / voxel_size))
	)
	
	print("    Dividing box ", box.min_pos, " to ", box.max_pos, " into voxels")
	print("    Voxel grid: ", min_voxel, " to ", max_voxel)
	
	# Generate all voxels within the box
	for x in range(min_voxel.x, max_voxel.x):
		for y in range(min_voxel.y, max_voxel.y):
			for z in range(min_voxel.z, max_voxel.z):
				var voxel_pos = Vector3i(x, y, z)
				
				# Check if this voxel overlaps with the box
				var voxel_min = Vector3(x * voxel_size, y * voxel_size, z * voxel_size)
				var voxel_max = voxel_min + Vector3(voxel_size, voxel_size, voxel_size)
				
				if boxes_overlap(voxel_min, voxel_max, min_pos, max_pos):
					voxels.append(voxel_pos)
	
	print("    Generated ", voxels.size(), " voxels from box")
	return voxels

static func boxes_overlap(min1: Vector3, max1: Vector3, min2: Vector3, max2: Vector3) -> bool:
	return (min1.x < max2.x and max1.x > min2.x and
			min1.y < max2.y and max1.y > min2.y and
			min1.z < max2.z and max1.z > min2.z)

static func voxelize_mesh_with_faces(vertices: Array, faces: Array, offset: Vector3) -> Array:
	var voxel_positions: Array = []
	var voxel_set = {}
	
	print("  Voxelizing mesh with ", vertices.size(), " vertices, ", faces.size(), " faces using face-based approach")
	
	# Process each face individually using our new face-to-voxel function
	for face_data in faces:
		var face_indices = []
		
		# Handle both old and new face formats
		if face_data is Array:
			# Old format: just vertex indices
			face_indices = face_data
		else:
			# New format: dictionary with vertices, uvs, material
			face_indices = face_data.get("vertices", [])
		
		if face_indices.size() < 3:
			continue
		
		# Get face vertices and apply offset
		var face_vertices = []
		for idx in face_indices:
			if idx < vertices.size():
				face_vertices.append(vertices[idx] + offset)
		
		if face_vertices.size() >= 3:
			# Generate voxels for this face
			var face_voxels = voxelize_face_with_normal(face_vertices)
			
			# Add to overall set, removing duplicates
			for voxel_pos in face_voxels:
				var key = str(voxel_pos)
				if not key in voxel_set:
					voxel_set[key] = true
					voxel_positions.append(voxel_pos)
	
	print("  Generated ", voxel_positions.size(), " unique voxels from ", faces.size(), " faces")
	return voxel_positions

static func voxelize_mesh_with_faces_by_indices(vertices: Array, faces: Array, face_indices: Array, offset: Vector3) -> Array:
	var voxel_positions: Array = []
	var voxel_set = {}
	
	print("  Voxelizing mesh group with ", face_indices.size(), " faces using face-based approach")
	
	# Process each specified face
	for face_index in face_indices:
		if face_index < faces.size():
			var face_data = faces[face_index]
			var face_vertex_indices = []
			
			# Handle both old and new face formats
			if face_data is Array:
				# Old format: just vertex indices
				face_vertex_indices = face_data
			else:
				# New format: dictionary with vertices, uvs, material
				face_vertex_indices = face_data.get("vertices", [])
			
			if face_vertex_indices.size() < 3:
				continue
			
			# Get face vertices and apply offset
			var face_vertices = []
			for idx in face_vertex_indices:
				if idx < vertices.size():
					face_vertices.append(vertices[idx] + offset)
			
			if face_vertices.size() >= 3:
				# Generate voxels for this face
				var face_voxels = voxelize_face_with_normal(face_vertices)
				
				# Add to overall set, removing duplicates
				for voxel_pos in face_voxels:
					var key = str(voxel_pos)
					if not key in voxel_set:
						voxel_set[key] = true
						voxel_positions.append(voxel_pos)
	
	print("  Generated ", voxel_positions.size(), " unique voxels from ", face_indices.size(), " faces")
	return voxel_positions

static func voxelize_mesh_with_faces_colored(vertices: Array, faces: Array, offset: Vector3, materials: Dictionary, obj_path: String) -> Dictionary:
	# First, get voxel positions using existing method (without colors)
	var voxel_positions = voxelize_mesh_with_faces(vertices, faces, offset)
	
	# Calculate one color per voxel
	var voxel_colors = calculate_voxel_colors(voxel_positions, vertices, faces, offset, materials, obj_path)
	return {"positions": voxel_positions, "colors": voxel_colors}

static func calculate_voxel_colors(voxel_positions: Array, vertices: Array, faces: Array, offset: Vector3, materials: Dictionary, obj_path: String) -> Array:
	var voxel_colors = []
	var texture_cache = {}
	
	# For each voxel, find the best matching face and sample its color
	for voxel_pos in voxel_positions:
		var voxel_world_pos = Vector3(voxel_pos) * 0.1 + Vector3(0.05, 0.05, 0.05)  # Convert to world space at voxel center
		var best_color = Color.GRAY  # Default fallback color
		var closest_distance = INF
		
		# Find the closest face to this voxel
		for face_data in faces:
			var face_vertices = []
			var face_uvs = []
			var face_material = ""
			
			# Handle both old and new face formats
			if face_data is Array:
				# Old format: just vertex indices
				for idx in face_data:
					if idx < vertices.size():
						face_vertices.append(vertices[idx] + offset)
				face_uvs = []
				face_material = ""
			else:
				# New format: dictionary with vertices, uvs, material
				for idx in face_data.vertices:
					if idx < vertices.size():
						face_vertices.append(vertices[idx] + offset)
				face_uvs = face_data.get("uvs", [])
				face_material = face_data.get("material", "")
			
			if face_vertices.size() >= 3:
				# Calculate distance from voxel center to face
				var face_center = calculate_face_center(face_vertices)
				var distance = voxel_world_pos.distance_to(face_center)
				
				# If this is the closest face so far, use its color
				if distance < closest_distance:
					closest_distance = distance
					best_color = calculate_face_color(face_vertices, face_uvs, face_material, materials, texture_cache, obj_path)
		
		voxel_colors.append(best_color)
		
	return voxel_colors

static func voxelize_mesh_with_faces_by_indices_colored(vertices: Array, faces: Array, face_indices: Array, offset: Vector3, materials: Dictionary, obj_path: String) -> Dictionary:
	# First, get voxel positions using existing method (without colors)
	var voxel_positions = voxelize_mesh_with_faces_by_indices(vertices, faces, face_indices, offset)
	
	# Filter faces to only include the specified indices for color calculation
	var filtered_faces = []
	for face_index in face_indices:
		if face_index < faces.size():
			filtered_faces.append(faces[face_index])
	
	# Calculate one color per voxel
	var voxel_colors = calculate_voxel_colors(voxel_positions, vertices, filtered_faces, offset, materials, obj_path)
	return {"positions": voxel_positions, "colors": voxel_colors}

static func calculate_face_color(face_vertices: Array, face_uvs: Array, material_name: String, materials: Dictionary, texture_cache: Dictionary, obj_path: String) -> Color:
	# Return color for a face based on material and texture
	var default_color = Color.WHITE
	
	# If no material, return default
	if material_name == "" or not material_name in materials:
		return default_color
	
	var material = materials[material_name]
	var base_color = material.get("diffuse_color", default_color)
	
	# If no texture, return base color
	var texture_path = material.get("texture_path", "")
	
	if texture_path == "" or face_uvs.size() == 0:
		return base_color
	
	# Load texture if not in cache
	if not texture_path in texture_cache:
		texture_cache[texture_path] = load_texture_from_path(obj_path, texture_path)
	
	var texture = texture_cache[texture_path]
	if not texture:
		return base_color
	
	# Sample texture at face center UV
	var center_uv = Vector2.ZERO
	for uv in face_uvs:
		center_uv += uv
	center_uv /= face_uvs.size()
	
	var texture_color = sample_texture_color(texture, center_uv)
	
	# Combine base color with texture color
	var final_color = Color(
		base_color.r * texture_color.r,
		base_color.g * texture_color.g,
		base_color.b * texture_color.b,
		base_color.a * texture_color.a
	)
	
	return final_color

# Legacy function - kept for compatibility but now uses new face-based approach
static func voxelize_mesh(vertices: Array, faces: Array, offset: Vector3) -> Array:
	return voxelize_mesh_with_faces(vertices, faces, offset)

# Old triangle-based voxelization functions (replaced by box-based approach)
# static func voxelize_triangle(triangle: Array, voxel_size: float) -> Array:
# static func voxel_intersects_triangle(voxel_pos: Vector3i, triangle: Array) -> bool:

static func point_in_triangle_3d(point: Vector3, triangle: Array) -> bool:
	var v0 = triangle[2] - triangle[0]
	var v1 = triangle[1] - triangle[0]
	var v2 = point - triangle[0]
	
	var dot00 = v0.dot(v0)
	var dot01 = v0.dot(v1)
	var dot02 = v0.dot(v2)
	var dot11 = v1.dot(v1)
	var dot12 = v1.dot(v2)
	
	var inv_denom = 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u = (dot11 * dot02 - dot01 * dot12) * inv_denom
	var v = (dot00 * dot12 - dot01 * dot02) * inv_denom
	
	return (u >= 0) and (v >= 0) and (u + v <= 1)

static func sanitize_part_name(name: String) -> String:
	var sanitized = name.to_lower()
	sanitized = sanitized.replace(" ", "_")
	sanitized = sanitized.replace("-", "_")
	
	var valid_chars = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var result = ""
	
	for char in sanitized:
		if char in valid_chars:
			result += char
	
	if result.is_empty():
		result = "part"
	
	return result

static func create_entity_template_from_obj(file_path: String, template_name: String, 
										   entity_type: VoxelSkeleton.EntityType) -> EntityTemplate:
	var obj_data = load_obj_file(file_path)
	if obj_data.is_empty():
		return null
	
	var voxel_parts = convert_obj_to_voxels(obj_data, true, true)
	
	var template = EntityTemplate.new()
	template.template_name = template_name
	template.entity_type = entity_type
	
	var part_names = voxel_parts.keys()
	var root_part_name = find_likely_root_part(part_names, entity_type)
	
	for part_name in part_names:
		var voxel_data = voxel_parts[part_name]
		var part_type = guess_part_type(part_name, entity_type)
		var is_root = (part_name == root_part_name)
		
		var voxel_positions: Array = []
		var colors: Array = []
		
		# Handle both old and new voxel data formats
		if voxel_data is Array:
			# Old format: just positions
			voxel_positions = voxel_data
			for i in range(voxel_positions.size()):
				colors.append(get_default_color_for_part_type(part_type))
		else:
			# New format: dictionary with positions and colors
			voxel_positions = voxel_data.get("positions", [])
			colors = voxel_data.get("colors", [])
			
			# Fill in missing colors with default
			while colors.size() < voxel_positions.size():
				colors.append(get_default_color_for_part_type(part_type))
		
		template.add_part_definition(part_name, part_type, voxel_positions, colors, 
									Vector3.ZERO, is_root)
	
	auto_generate_connections(template, entity_type)
	
	return template

static func find_likely_root_part(part_names: Array, entity_type: VoxelSkeleton.EntityType) -> String:
	var root_keywords = ["torso", "body", "chest", "main", "center", "core"]
	
	for keyword in root_keywords:
		for part_name in part_names:
			if keyword in part_name.to_lower():
				return part_name
	
	if part_names.size() > 0:
		return part_names[0]
	
	return ""

static func guess_part_type(part_name: String, entity_type: VoxelSkeleton.EntityType) -> VoxelPart.PartType:
	var name_lower = part_name.to_lower()
	
	if "head" in name_lower or "skull" in name_lower:
		return VoxelPart.PartType.HEAD
	elif "torso" in name_lower or "chest" in name_lower or "body" in name_lower:
		return VoxelPart.PartType.TORSO
	elif "arm" in name_lower and ("left" in name_lower or "l_" in name_lower):
		return VoxelPart.PartType.ARM_LEFT
	elif "arm" in name_lower and ("right" in name_lower or "r_" in name_lower):
		return VoxelPart.PartType.ARM_RIGHT
	elif "leg" in name_lower and ("left" in name_lower or "l_" in name_lower):
		return VoxelPart.PartType.LEG_LEFT
	elif "leg" in name_lower and ("right" in name_lower or "r_" in name_lower):
		return VoxelPart.PartType.LEG_RIGHT
	elif "wing" in name_lower and ("left" in name_lower or "l_" in name_lower):
		return VoxelPart.PartType.WING_LEFT
	elif "wing" in name_lower and ("right" in name_lower or "r_" in name_lower):
		return VoxelPart.PartType.WING_RIGHT
	elif "tail" in name_lower:
		return VoxelPart.PartType.TAIL
	else:
		return VoxelPart.PartType.BODY

static func get_default_color_for_part_type(part_type: VoxelPart.PartType) -> Color:
	match part_type:
		VoxelPart.PartType.HEAD:
			return Color.BEIGE
		VoxelPart.PartType.TORSO:
			return Color.BLUE
		VoxelPart.PartType.ARM_LEFT, VoxelPart.PartType.ARM_RIGHT:
			return Color.BEIGE
		VoxelPart.PartType.LEG_LEFT, VoxelPart.PartType.LEG_RIGHT:
			return Color.BROWN
		VoxelPart.PartType.WING_LEFT, VoxelPart.PartType.WING_RIGHT:
			return Color.GRAY
		VoxelPart.PartType.TAIL:
			return Color.BROWN
		_:
			return Color.WHITE

static func auto_generate_connections(template: EntityTemplate, entity_type: VoxelSkeleton.EntityType):
	var root_part = template.get_root_part_definition()
	if not root_part:
		return
	
	match entity_type:
		VoxelSkeleton.EntityType.HUMANOID:
			auto_connect_humanoid_parts(template, root_part)
		VoxelSkeleton.EntityType.QUADRUPED:
			auto_connect_quadruped_parts(template, root_part)
		VoxelSkeleton.EntityType.BIRD:
			auto_connect_bird_parts(template, root_part)
		VoxelSkeleton.EntityType.OBJECT:
			pass

static func auto_connect_humanoid_parts(template: EntityTemplate, root_part: EntityTemplate.PartDefinition):
	var root_bounds = calculate_part_bounds(root_part.positions)
	
	for part_def in template.part_definitions:
		if part_def == root_part:
			continue
		
		var offset = Vector3.ZERO
		
		match part_def.type:
			VoxelPart.PartType.HEAD:
				offset = Vector3(root_bounds.size.x * 0.5, root_bounds.size.y, 0)
			VoxelPart.PartType.ARM_LEFT:
				offset = Vector3(-1, root_bounds.size.y * 0.7, 0)
			VoxelPart.PartType.ARM_RIGHT:
				offset = Vector3(root_bounds.size.x + 1, root_bounds.size.y * 0.7, 0)
			VoxelPart.PartType.LEG_LEFT:
				offset = Vector3(root_bounds.size.x * 0.3, -1, 0)
			VoxelPart.PartType.LEG_RIGHT:
				offset = Vector3(root_bounds.size.x * 0.7, -1, 0)
		
		template.add_connection(root_part.name, part_def.name, offset)

static func auto_connect_quadruped_parts(template: EntityTemplate, root_part: EntityTemplate.PartDefinition):
	var root_bounds = calculate_part_bounds(root_part.positions)
	
	for part_def in template.part_definitions:
		if part_def == root_part:
			continue
		
		var offset = Vector3.ZERO
		
		if "head" in part_def.name.to_lower():
			offset = Vector3(root_bounds.size.x, 0, root_bounds.size.z * 0.5)
		elif "front" in part_def.name.to_lower() and "left" in part_def.name.to_lower():
			offset = Vector3(root_bounds.size.x * 0.2, -1, 0)
		elif "front" in part_def.name.to_lower() and "right" in part_def.name.to_lower():
			offset = Vector3(root_bounds.size.x * 0.2, -1, root_bounds.size.z)
		elif "back" in part_def.name.to_lower() and "left" in part_def.name.to_lower():
			offset = Vector3(root_bounds.size.x * 0.8, -1, 0)
		elif "back" in part_def.name.to_lower() and "right" in part_def.name.to_lower():
			offset = Vector3(root_bounds.size.x * 0.8, -1, root_bounds.size.z)
		elif "tail" in part_def.name.to_lower():
			offset = Vector3(-1, root_bounds.size.y * 0.5, root_bounds.size.z * 0.5)
		
		template.add_connection(root_part.name, part_def.name, offset)

static func auto_connect_bird_parts(template: EntityTemplate, root_part: EntityTemplate.PartDefinition):
	var root_bounds = calculate_part_bounds(root_part.positions)
	
	for part_def in template.part_definitions:
		if part_def == root_part:
			continue
		
		var offset = Vector3.ZERO
		
		match part_def.type:
			VoxelPart.PartType.HEAD:
				offset = Vector3(root_bounds.size.x * 0.5, root_bounds.size.y, 0)
			VoxelPart.PartType.WING_LEFT:
				offset = Vector3(-1, root_bounds.size.y * 0.5, 0)
			VoxelPart.PartType.WING_RIGHT:
				offset = Vector3(root_bounds.size.x + 1, root_bounds.size.y * 0.5, 0)
			VoxelPart.PartType.LEG_LEFT:
				offset = Vector3(root_bounds.size.x * 0.3, -1, 0)
			VoxelPart.PartType.LEG_RIGHT:
				offset = Vector3(root_bounds.size.x * 0.7, -1, 0)
			VoxelPart.PartType.TAIL:
				offset = Vector3(root_bounds.size.x * 0.5, 0, -1)
		
		template.add_connection(root_part.name, part_def.name, offset)

static func calculate_part_bounds(positions: Array) -> AABB:
	if positions.is_empty():
		return AABB()
	
	var min_pos = Vector3(positions[0])
	var max_pos = Vector3(positions[0])
	
	for pos in positions:
		var v_pos = Vector3(pos)
		min_pos = min_pos.min(v_pos)
		max_pos = max_pos.max(v_pos)
	
	return AABB(min_pos, max_pos - min_pos + Vector3.ONE)
