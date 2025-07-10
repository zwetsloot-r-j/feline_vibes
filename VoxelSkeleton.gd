extends Node3D
class_name VoxelSkeleton

@export var skeleton_name: String = ""
@export var entity_type: EntityType = EntityType.HUMANOID

enum EntityType {
	HUMANOID,
	QUADRUPED,
	BIRD,
	OBJECT
}

var root_part: VoxelPart
var parts: Dictionary = {}
var connections: Dictionary = {}
var animation_player: AnimationPlayer

signal skeleton_changed
signal animation_finished(animation_name: String)

func _ready():
	animation_player = AnimationPlayer.new()
	add_child(animation_player)
	animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName):
	animation_finished.emit(anim_name)

func create_skeleton_from_template(template: EntityTemplate):
	clear_skeleton()
	skeleton_name = template.template_name
	entity_type = template.entity_type
	
	for part_data in template.part_definitions:
		var part = VoxelPart.new()
		part.part_name = part_data.name
		part.part_type = part_data.type
		part.voxel_positions = part_data.positions.duplicate()
		part.voxel_colors = part_data.colors.duplicate()
		part.pivot_offset = part_data.pivot_offset
		
		add_part(part)
		
		if part_data.is_root:
			set_root_part(part)
	
	for connection in template.connections:
		connect_parts(connection.parent_name, connection.child_name, connection.offset)
	
	skeleton_changed.emit()

func add_part(part: VoxelPart):
	if part.part_name in parts:
		push_warning("Part with name '" + part.part_name + "' already exists")
		return
	
	# Remove part from its current parent if it has one
	if part.get_parent():
		part.get_parent().remove_child(part)
	
	parts[part.part_name] = part
	add_child(part)
	skeleton_changed.emit()

func remove_part(part_name: String):
	if part_name in parts:
		var part = parts[part_name]
		
		disconnect_part(part_name)
		
		parts.erase(part_name)
		remove_child(part)
		part.queue_free()
		skeleton_changed.emit()

func connect_parts(parent_name: String, child_name: String, offset: Vector3 = Vector3.ZERO):
	if not parent_name in parts or not child_name in parts:
		push_error("Cannot connect parts: one or both parts not found")
		return
	
	var parent_part = parts[parent_name]
	var child_part = parts[child_name]
	
	if not parent_name in connections:
		connections[parent_name] = []
	
	var connection_data = {
		"child_name": child_name,
		"offset": offset
	}
	
	connections[parent_name].append(connection_data)
	parent_part.attach_child_part(child_part)
	child_part.position = offset
	
	skeleton_changed.emit()

func disconnect_part(part_name: String):
	for parent_name in connections:
		var connection_list = connections[parent_name]
		for i in range(connection_list.size() - 1, -1, -1):
			if connection_list[i].child_name == part_name:
				var parent_part = parts[parent_name]
				var child_part = parts[part_name]
				parent_part.detach_child_part(child_part)
				connection_list.remove_at(i)
				break
	
	if part_name in connections:
		connections.erase(part_name)
	
	skeleton_changed.emit()

func set_root_part(part: VoxelPart):
	if not part in parts.values():
		push_error("Part must be added to skeleton before setting as root")
		return
	
	root_part = part

func get_part(part_name: String) -> VoxelPart:
	return parts.get(part_name, null)

func get_all_parts() -> Array:
	var part_array: Array = []
	for part in parts.values():
		part_array.append(part)
	return part_array

func clear_skeleton():
	# First, completely disconnect all part-to-part relationships
	for part in parts.values():
		# Detach all child parts from this part
		for child in part.child_parts.duplicate():
			part.detach_child_part(child)
		
		# Remove this part from its parent part if it has one
		if part.parent_part:
			part.parent_part.detach_child_part(part)
	
	# Then remove all parts from the skeleton
	for part in parts.values():
		# Remove from skeleton only if we're actually the parent
		if part.get_parent() == self:
			remove_child(part)
		elif part.get_parent():
			# If it has a different parent, remove it from there
			part.get_parent().remove_child(part)
		part.queue_free()
	
	parts.clear()
	connections.clear()
	root_part = null
	skeleton_changed.emit()

func create_animation(animation_name: String, duration: float) -> Animation:
	var animation = Animation.new()
	animation.length = duration
	
	animation_player.add_animation_library("default", AnimationLibrary.new())
	var library = animation_player.get_animation_library("default")
	library.add_animation(animation_name, animation)
	
	return animation

func add_part_keyframe(animation_name: String, part_name: String, time: float, 
					  position: Vector3 = Vector3.INF, rotation: Vector3 = Vector3.INF):
	var library = animation_player.get_animation_library("default")
	if not library or not library.has_animation(animation_name):
		push_error("Animation '" + animation_name + "' not found")
		return
	
	var animation = library.get_animation(animation_name)
	var part = get_part(part_name)
	if not part:
		push_error("Part '" + part_name + "' not found")
		return
	
	var node_path = get_path_to(part)
	
	if position != Vector3.INF:
		var pos_track = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(pos_track, node_path)
		animation.track_insert_key(pos_track, time, position)
	
	if rotation != Vector3.INF:
		var rot_track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rot_track, node_path)
		var quat = Quaternion.from_euler(rotation)
		animation.track_insert_key(rot_track, time, quat)

func play_animation(animation_name: String, blend_time: float = 0.1):
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name, blend_time)
	else:
		push_error("Animation '" + animation_name + "' not found")

func stop_animation():
	animation_player.stop()

func is_animation_playing() -> bool:
	return animation_player.is_playing()

func get_current_animation() -> String:
	if animation_player.is_playing():
		return animation_player.current_animation
	return ""

func adapt_animation_for_entity_type(source_animation: Animation, target_type: EntityType) -> Animation:
	var adapted_animation = Animation.new()
	adapted_animation.length = source_animation.length
	
	for track_idx in range(source_animation.get_track_count()):
		var track_path = source_animation.track_get_path(track_idx)
		var track_type = source_animation.track_get_type(track_idx)
		
		var part_name = str(track_path).get_file()
		var adapted_part_name = map_part_name_for_entity_type(part_name, entity_type, target_type)
		
		if adapted_part_name != "":
			var new_track = adapted_animation.add_track(track_type)
			var new_path = NodePath(adapted_part_name)
			adapted_animation.track_set_path(new_track, new_path)
			
			for key_idx in range(source_animation.track_get_key_count(track_idx)):
				var time = source_animation.track_get_key_time(track_idx, key_idx)
				var value = source_animation.track_get_key_value(track_idx, key_idx)
				
				var adapted_value = adapt_keyframe_value(value, part_name, adapted_part_name, 
														entity_type, target_type)
				adapted_animation.track_insert_key(new_track, time, adapted_value)
	
	return adapted_animation

func map_part_name_for_entity_type(source_part: String, source_type: EntityType, 
								  target_type: EntityType) -> String:
	var mapping = {
		EntityType.HUMANOID: {
			EntityType.QUADRUPED: {
				"arm_left": "leg_front_left",
				"arm_right": "leg_front_right",
				"leg_left": "leg_back_left",
				"leg_right": "leg_back_right"
			},
			EntityType.BIRD: {
				"arm_left": "wing_left",
				"arm_right": "wing_right"
			}
		}
	}
	
	if source_type in mapping and target_type in mapping[source_type]:
		var type_mapping = mapping[source_type][target_type]
		return type_mapping.get(source_part, source_part)
	
	return source_part

func adapt_keyframe_value(value, source_part: String, target_part: String, 
						 source_type: EntityType, target_type: EntityType):
	if source_type == EntityType.HUMANOID and target_type == EntityType.QUADRUPED:
		if source_part in ["arm_left", "arm_right", "leg_left", "leg_right"]:
			if value is Vector3:
				value.y *= 0.7
	
	return value

func save_skeleton_to_file(file_path: String):
	var data = {
		"skeleton_name": skeleton_name,
		"entity_type": entity_type,
		"parts": {},
		"connections": connections.duplicate(),
		"root_part_name": root_part.part_name if root_part else ""
	}
	
	for part_name in parts:
		var part = parts[part_name]
		data.parts[part_name] = {
			"part_name": part.part_name,
			"part_type": part.part_type,
			"voxel_positions": part.voxel_positions,
			"voxel_colors": part.voxel_colors,
			"pivot_offset": part.pivot_offset,
			"position": part.position,
			"rotation": part.rotation
		}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_skeleton_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("Skeleton file not found: " + file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse skeleton file: " + file_path)
		return false
	
	var data = json.data
	clear_skeleton()
	
	skeleton_name = data.skeleton_name
	entity_type = data.entity_type
	
	for part_name in data.parts:
		var part_data = data.parts[part_name]
		var part = VoxelPart.new()
		part.part_name = part_data.part_name
		part.part_type = part_data.part_type
		part.voxel_positions = part_data.voxel_positions
		part.voxel_colors = part_data.voxel_colors
		part.pivot_offset = part_data.pivot_offset
		part.position = Vector3(part_data.position.x, part_data.position.y, part_data.position.z)
		part.rotation = Vector3(part_data.rotation.x, part_data.rotation.y, part_data.rotation.z)
		
		add_part(part)
		
		if part_name == data.root_part_name:
			set_root_part(part)
	
	connections = data.connections.duplicate()
	
	for parent_name in connections:
		for connection in connections[parent_name]:
			var parent_part = parts[parent_name]
			var child_part = parts[connection.child_name]
			parent_part.attach_child_part(child_part)
			child_part.position = connection.offset
	
	skeleton_changed.emit()
	return true