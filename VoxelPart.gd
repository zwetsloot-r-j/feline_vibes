extends Node3D
class_name VoxelPart

@export var part_name: String = ""
@export var voxel_positions: Array = []
@export var voxel_colors: Array = []
@export var pivot_offset: Vector3 = Vector3.ZERO
@export var part_type: PartType = PartType.BODY

enum PartType {
	HEAD,
	TORSO,
	ARM_LEFT,
	ARM_RIGHT,
	LEG_LEFT,
	LEG_RIGHT,
	BODY,
	TAIL,
	WING_LEFT,
	WING_RIGHT,
	APPENDAGE
}

var original_positions: Array = []
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var parent_part: VoxelPart
var child_parts: Array = []

signal voxels_changed

func _ready():
	call_deferred("create_mesh_instance")
	store_original_positions()

func create_mesh_instance():
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	collision_shape = CollisionShape3D.new()
	add_child(collision_shape)
	
	update_mesh()

func store_original_positions():
	original_positions = voxel_positions.duplicate()

func add_voxel(pos: Vector3i, color: Color = Color.WHITE):
	voxel_positions.append(pos)
	voxel_colors.append(color)
	call_deferred("update_mesh")
	voxels_changed.emit()

func remove_voxel(pos: Vector3i):
	var index = voxel_positions.find(pos)
	if index >= 0:
		voxel_positions.remove_at(index)
		if index < voxel_colors.size():
			voxel_colors.remove_at(index)
		call_deferred("update_mesh")
		voxels_changed.emit()

func set_voxel_positions(positions: Array, colors: Array = []):
	voxel_positions = positions.duplicate()
	voxel_colors = colors.duplicate() if colors.size() > 0 else []
	
	while voxel_colors.size() < voxel_positions.size():
		voxel_colors.append(Color.WHITE)
	
	
	call_deferred("update_mesh")
	voxels_changed.emit()

func update_mesh():
	if not mesh_instance:
		return
		
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	
	var vertex_count = 0
	
	for i in range(voxel_positions.size()):
		var pos = voxel_positions[i]
		var color = voxel_colors[i] if i < voxel_colors.size() else Color.WHITE
		
		var cube_vertices = get_cube_vertices(Vector3(pos))
		var cube_normals = get_cube_normals()
		var cube_indices = get_cube_indices(vertex_count)
		
		vertices.append_array(cube_vertices)
		normals.append_array(cube_normals)
		
		for j in range(24):
			colors.append(color)
		
		indices.append_array(cube_indices)
		vertex_count += 24

	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_instance.mesh = array_mesh
		
		# Create a material that uses vertex colors
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color.WHITE
		mesh_instance.set_surface_override_material(0, material)
		
		create_collision_shape()

func get_cube_vertices(pos: Vector3) -> PackedVector3Array:
	var verts = PackedVector3Array()
	var size = 0.5
	
	var faces = [
		# Front face (positive Z) - counter-clockwise from outside
		[Vector3(-size, -size, size), Vector3(-size, size, size), Vector3(size, size, size), Vector3(size, -size, size)],
		# Back face (negative Z) - counter-clockwise from outside
		[Vector3(size, -size, -size), Vector3(size, size, -size), Vector3(-size, size, -size), Vector3(-size, -size, -size)],
		# Left face (negative X) - counter-clockwise from outside
		[Vector3(-size, -size, -size), Vector3(-size, size, -size), Vector3(-size, size, size), Vector3(-size, -size, size)],
		# Right face (positive X) - counter-clockwise from outside
		[Vector3(size, -size, size), Vector3(size, size, size), Vector3(size, size, -size), Vector3(size, -size, -size)],
		# Top face (positive Y) - counter-clockwise from outside
		[Vector3(-size, size, size), Vector3(-size, size, -size), Vector3(size, size, -size), Vector3(size, size, size)],
		# Bottom face (negative Y) - counter-clockwise from outside
		[Vector3(-size, -size, -size), Vector3(-size, -size, size), Vector3(size, -size, size), Vector3(size, -size, -size)]
	]
	
	for face in faces:
		for vertex in face:
			verts.append(pos + vertex)
	
	return verts

func get_cube_normals() -> PackedVector3Array:
	var normals = PackedVector3Array()
	var face_normals = [
		Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(-1, 0, 0),
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)
	]
	
	for normal in face_normals:
		for i in range(4):
			normals.append(normal)
	
	return normals

func get_cube_indices(vertex_offset: int) -> PackedInt32Array:
	var indices = PackedInt32Array()
	
	for face in range(6):
		var base = vertex_offset + face * 4
		# Standard quad to triangle conversion
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	
	return indices

func create_collision_shape():
	if not collision_shape:
		return
		
	var shape = BoxShape3D.new()
	var bounds = get_bounds()
	shape.size = bounds.size
	collision_shape.shape = shape
	collision_shape.position = bounds.get_center()

func get_bounds() -> AABB:
	if voxel_positions.is_empty():
		return AABB(Vector3.ZERO, Vector3.ONE)
	
	var min_pos = Vector3(voxel_positions[0])
	var max_pos = Vector3(voxel_positions[0])
	
	for pos in voxel_positions:
		var v_pos = Vector3(pos)
		min_pos = min_pos.min(v_pos)
		max_pos = max_pos.max(v_pos)
	
	return AABB(min_pos - Vector3.ONE * 0.5, (max_pos - min_pos) + Vector3.ONE)

func attach_child_part(child: VoxelPart):
	if child in child_parts:
		return
	
	
	# Remove child from its current parent if it has one
	if child.get_parent() and child.get_parent() != self:
		child.get_parent().remove_child(child)
	
	# Update the parent-child relationship
	if child.parent_part and child.parent_part != self:
		child.parent_part.detach_child_part(child)
	
	child_parts.append(child)
	child.parent_part = self
	
	# Only add as child if not already a child
	if child.get_parent() != self:
		add_child(child)

func detach_child_part(child: VoxelPart):
	if child in child_parts:
		child_parts.erase(child)
		child.parent_part = null
		
		# Only remove if we're actually the parent
		if child.get_parent() == self:
			remove_child(child)

func get_part_by_name(name: String) -> VoxelPart:
	if part_name == name:
		return self
	
	for child in child_parts:
		var result = child.get_part_by_name(name)
		if result:
			return result
	
	return null

func reset_to_original_positions():
	set_voxel_positions(original_positions, voxel_colors)