extends Node3D
class_name VoxelAnimationSystem

@export var skeleton: VoxelSkeleton
@export var auto_play_animation: String = ""
@export var animation_speed: float = 1.0

var animation_library: Dictionary = {}
var current_animation: String = ""
var animation_time: float = 0.0
var is_playing: bool = false
var loop_current: bool = true

signal animation_started(animation_name: String)
signal animation_finished(animation_name: String)
signal animation_looped(animation_name: String)

func _ready():
	if skeleton:
		skeleton.animation_finished.connect(_on_skeleton_animation_finished)
	
	if auto_play_animation != "":
		play_animation(auto_play_animation)

func _process(delta):
	if is_playing and current_animation != "":
		update_animation(delta)

func _on_skeleton_animation_finished(anim_name: String):
	animation_finished.emit(anim_name)
	
	if loop_current:
		animation_looped.emit(anim_name)
		restart_current_animation()
	else:
		stop_animation()

func create_animation(animation_name: String, duration: float) -> VoxelAnimation:
	var animation = VoxelAnimation.new()
	animation.name = animation_name
	animation.duration = duration
	animation_library[animation_name] = animation
	return animation

func load_animation_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("Animation file not found: " + file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse animation file: " + file_path)
		return false
	
	var data = json.data
	var animation = VoxelAnimation.new()
	animation.name = data.name
	animation.duration = data.duration
	animation.loop = data.get("loop", true)
	
	for keyframe_data in data.keyframes:
		var keyframe = VoxelKeyframe.new()
		keyframe.time = keyframe_data.time
		keyframe.part_name = keyframe_data.part_name
		keyframe.position = Vector3(keyframe_data.position.x, keyframe_data.position.y, keyframe_data.position.z)
		keyframe.rotation = Vector3(keyframe_data.rotation.x, keyframe_data.rotation.y, keyframe_data.rotation.z)
		keyframe.scale = Vector3(keyframe_data.scale.x, keyframe_data.scale.y, keyframe_data.scale.z) if "scale" in keyframe_data else Vector3.ONE
		keyframe.interpolation = keyframe_data.get("interpolation", VoxelKeyframe.InterpolationType.LINEAR)
		
		animation.add_keyframe(keyframe)
	
	animation_library[animation.name] = animation
	return true

func save_animation_to_file(animation_name: String, file_path: String) -> bool:
	if not animation_name in animation_library:
		push_error("Animation not found: " + animation_name)
		return false
	
	var animation = animation_library[animation_name]
	var data = {
		"name": animation.name,
		"duration": animation.duration,
		"loop": animation.loop,
		"keyframes": []
	}
	
	for keyframe in animation.keyframes:
		var keyframe_data = {
			"time": keyframe.time,
			"part_name": keyframe.part_name,
			"position": {"x": keyframe.position.x, "y": keyframe.position.y, "z": keyframe.position.z},
			"rotation": {"x": keyframe.rotation.x, "y": keyframe.rotation.y, "z": keyframe.rotation.z},
			"scale": {"x": keyframe.scale.x, "y": keyframe.scale.y, "z": keyframe.scale.z},
			"interpolation": keyframe.interpolation
		}
		data.keyframes.append(keyframe_data)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func play_animation(animation_name: String, loop: bool = true, blend_time: float = 0.1):
	if not animation_name in animation_library:
		push_error("Animation not found: " + animation_name)
		return
	
	if current_animation == animation_name and is_playing:
		return
	
	current_animation = animation_name
	animation_time = 0.0
	is_playing = true
	loop_current = loop
	
	animation_started.emit(animation_name)

func stop_animation():
	is_playing = false
	current_animation = ""
	animation_time = 0.0

func pause_animation():
	is_playing = false

func resume_animation():
	if current_animation != "":
		is_playing = true

func restart_current_animation():
	if current_animation != "":
		animation_time = 0.0

func update_animation(delta: float):
	if not skeleton or current_animation == "":
		return
	
	var animation = animation_library[current_animation]
	animation_time += delta * animation_speed
	
	if animation_time >= animation.duration:
		if loop_current:
			animation_time = fmod(animation_time, animation.duration)
			animation_looped.emit(current_animation)
		else:
			animation_time = animation.duration
			animation_finished.emit(current_animation)
			stop_animation()
			return
	
	apply_animation_at_time(animation, animation_time)

func apply_animation_at_time(animation: VoxelAnimation, time: float):
	var part_transforms = {}
	
	for part_name in skeleton.parts:
		var part = skeleton.get_part(part_name)
		if not part:
			continue
		
		var keyframes = animation.get_keyframes_for_part(part_name)
		if keyframes.is_empty():
			continue
		
		var transform_data = interpolate_keyframes(keyframes, time)
		part.position = transform_data.position
		part.rotation = transform_data.rotation
		part.scale = transform_data.scale

func interpolate_keyframes(keyframes: Array, time: float) -> Dictionary:
	if keyframes.is_empty():
		return {"position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE}
	
	if keyframes.size() == 1:
		var kf = keyframes[0]
		return {"position": kf.position, "rotation": kf.rotation, "scale": kf.scale}
	
	keyframes.sort_custom(func(a, b): return a.time < b.time)
	
	var prev_keyframe = keyframes[0]
	var next_keyframe = keyframes[-1]
	
	for i in range(keyframes.size() - 1):
		if time >= keyframes[i].time and time <= keyframes[i + 1].time:
			prev_keyframe = keyframes[i]
			next_keyframe = keyframes[i + 1]
			break
	
	if prev_keyframe == next_keyframe:
		return {"position": prev_keyframe.position, "rotation": prev_keyframe.rotation, "scale": prev_keyframe.scale}
	
	var t = (time - prev_keyframe.time) / (next_keyframe.time - prev_keyframe.time)
	
	var position = Vector3.ZERO
	var rotation = Vector3.ZERO
	var scale = Vector3.ONE
	
	match next_keyframe.interpolation:
		VoxelKeyframe.InterpolationType.LINEAR:
			position = prev_keyframe.position.lerp(next_keyframe.position, t)
			rotation = prev_keyframe.rotation.lerp(next_keyframe.rotation, t)
			scale = prev_keyframe.scale.lerp(next_keyframe.scale, t)
		
		VoxelKeyframe.InterpolationType.CUBIC:
			position = prev_keyframe.position.cubic_interpolate(next_keyframe.position, Vector3.ZERO, Vector3.ZERO, t)
			rotation = prev_keyframe.rotation.cubic_interpolate(next_keyframe.rotation, Vector3.ZERO, Vector3.ZERO, t)
			scale = prev_keyframe.scale.cubic_interpolate(next_keyframe.scale, Vector3.ZERO, Vector3.ZERO, t)
		
		VoxelKeyframe.InterpolationType.STEP:
			if t < 1.0:
				position = prev_keyframe.position
				rotation = prev_keyframe.rotation
				scale = prev_keyframe.scale
			else:
				position = next_keyframe.position
				rotation = next_keyframe.rotation
				scale = next_keyframe.scale
	
	return {"position": position, "rotation": rotation, "scale": scale}

func adapt_animation_for_entity_type(source_animation_name: String, target_entity_type: VoxelSkeleton.EntityType) -> String:
	if not source_animation_name in animation_library:
		push_error("Source animation not found: " + source_animation_name)
		return ""
	
	var source_animation = animation_library[source_animation_name]
	var adapted_name = source_animation_name + "_adapted_" + str(target_entity_type)
	
	if adapted_name in animation_library:
		return adapted_name
	
	var adapted_animation = VoxelAnimation.new()
	adapted_animation.name = adapted_name
	adapted_animation.duration = source_animation.duration
	adapted_animation.loop = source_animation.loop
	
	for keyframe in source_animation.keyframes:
		var adapted_part_name = map_part_name_for_entity_type(keyframe.part_name, 
														   skeleton.entity_type, target_entity_type)
		
		if adapted_part_name != "":
			var adapted_keyframe = VoxelKeyframe.new()
			adapted_keyframe.time = keyframe.time
			adapted_keyframe.part_name = adapted_part_name
			adapted_keyframe.position = adapt_transform_for_entity_type(keyframe.position, 
																	   keyframe.part_name, 
																	   skeleton.entity_type, 
																	   target_entity_type)
			adapted_keyframe.rotation = keyframe.rotation
			adapted_keyframe.scale = keyframe.scale
			adapted_keyframe.interpolation = keyframe.interpolation
			
			adapted_animation.add_keyframe(adapted_keyframe)
	
	animation_library[adapted_name] = adapted_animation
	return adapted_name

func map_part_name_for_entity_type(source_part: String, source_type: VoxelSkeleton.EntityType, 
								  target_type: VoxelSkeleton.EntityType) -> String:
	var mapping = {
		VoxelSkeleton.EntityType.HUMANOID: {
			VoxelSkeleton.EntityType.QUADRUPED: {
				"arm_left": "leg_front_left",
				"arm_right": "leg_front_right",
				"leg_left": "leg_back_left",
				"leg_right": "leg_back_right",
				"torso": "body"
			},
			VoxelSkeleton.EntityType.BIRD: {
				"arm_left": "wing_left",
				"arm_right": "wing_right",
				"torso": "body"
			}
		},
		VoxelSkeleton.EntityType.QUADRUPED: {
			VoxelSkeleton.EntityType.HUMANOID: {
				"leg_front_left": "arm_left",
				"leg_front_right": "arm_right",
				"leg_back_left": "leg_left",
				"leg_back_right": "leg_right",
				"body": "torso"
			}
		}
	}
	
	if source_type in mapping and target_type in mapping[source_type]:
		var type_mapping = mapping[source_type][target_type]
		return type_mapping.get(source_part, source_part)
	
	return source_part

func adapt_transform_for_entity_type(transform: Vector3, part_name: String, 
									source_type: VoxelSkeleton.EntityType, 
									target_type: VoxelSkeleton.EntityType) -> Vector3:
	if source_type == VoxelSkeleton.EntityType.HUMANOID and target_type == VoxelSkeleton.EntityType.QUADRUPED:
		if part_name in ["arm_left", "arm_right", "leg_left", "leg_right"]:
			transform.y *= 0.7
		elif part_name == "head":
			transform.z += 1.0
	
	elif source_type == VoxelSkeleton.EntityType.HUMANOID and target_type == VoxelSkeleton.EntityType.BIRD:
		if part_name in ["arm_left", "arm_right"]:
			transform.y *= 1.2
			transform.x *= 1.5
	
	return transform

func create_default_animations_for_entity_type(entity_type: VoxelSkeleton.EntityType):
	match entity_type:
		VoxelSkeleton.EntityType.HUMANOID:
			create_humanoid_walk_animation()
			create_humanoid_idle_animation()
		VoxelSkeleton.EntityType.QUADRUPED:
			create_quadruped_walk_animation()
			create_quadruped_idle_animation()
		VoxelSkeleton.EntityType.BIRD:
			create_bird_fly_animation()
			create_bird_idle_animation()
		VoxelSkeleton.EntityType.OBJECT:
			create_object_rotate_animation()

func create_humanoid_walk_animation():
	var walk_anim = create_animation("walk", 1.0)
	
	walk_anim.add_keyframe_data("leg_left", 0.0, Vector3(0, 0.5, 0), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_left", 0.5, Vector3(0, 0, 0.5), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_left", 1.0, Vector3(0, 0.5, 0), Vector3.ZERO)
	
	walk_anim.add_keyframe_data("leg_right", 0.0, Vector3(0, 0, -0.5), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_right", 0.5, Vector3(0, 0.5, 0), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_right", 1.0, Vector3(0, 0, -0.5), Vector3.ZERO)

func create_humanoid_idle_animation():
	var idle_anim = create_animation("idle", 2.0)
	idle_anim.add_keyframe_data("torso", 0.0, Vector3.ZERO, Vector3.ZERO)
	idle_anim.add_keyframe_data("torso", 1.0, Vector3(0, 0.1, 0), Vector3.ZERO)
	idle_anim.add_keyframe_data("torso", 2.0, Vector3.ZERO, Vector3.ZERO)

func create_quadruped_walk_animation():
	var walk_anim = create_animation("walk", 1.2)
	
	walk_anim.add_keyframe_data("leg_front_left", 0.0, Vector3(0, 0.3, 0), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_front_left", 0.6, Vector3(0, 0, 0), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_front_left", 1.2, Vector3(0, 0.3, 0), Vector3.ZERO)
	
	walk_anim.add_keyframe_data("leg_back_right", 0.0, Vector3(0, 0.3, 0), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_back_right", 0.6, Vector3(0, 0, 0), Vector3.ZERO)
	walk_anim.add_keyframe_data("leg_back_right", 1.2, Vector3(0, 0.3, 0), Vector3.ZERO)

func create_quadruped_idle_animation():
	var idle_anim = create_animation("idle", 3.0)
	idle_anim.add_keyframe_data("head", 0.0, Vector3.ZERO, Vector3.ZERO)
	idle_anim.add_keyframe_data("head", 1.5, Vector3(0, 0.2, 0), Vector3(0, 0.1, 0))
	idle_anim.add_keyframe_data("head", 3.0, Vector3.ZERO, Vector3.ZERO)

func create_bird_fly_animation():
	var fly_anim = create_animation("fly", 0.5)
	
	fly_anim.add_keyframe_data("wing_left", 0.0, Vector3.ZERO, Vector3(0, 0, 0.5))
	fly_anim.add_keyframe_data("wing_left", 0.25, Vector3.ZERO, Vector3(0, 0, -0.5))
	fly_anim.add_keyframe_data("wing_left", 0.5, Vector3.ZERO, Vector3(0, 0, 0.5))
	
	fly_anim.add_keyframe_data("wing_right", 0.0, Vector3.ZERO, Vector3(0, 0, -0.5))
	fly_anim.add_keyframe_data("wing_right", 0.25, Vector3.ZERO, Vector3(0, 0, 0.5))
	fly_anim.add_keyframe_data("wing_right", 0.5, Vector3.ZERO, Vector3(0, 0, -0.5))

func create_bird_idle_animation():
	var idle_anim = create_animation("idle", 1.5)
	idle_anim.add_keyframe_data("head", 0.0, Vector3.ZERO, Vector3.ZERO)
	idle_anim.add_keyframe_data("head", 0.75, Vector3(0, 0, 0.1), Vector3(0, 0.2, 0))
	idle_anim.add_keyframe_data("head", 1.5, Vector3.ZERO, Vector3.ZERO)

func create_object_rotate_animation():
	var rotate_anim = create_animation("rotate", 2.0)
	rotate_anim.add_keyframe_data("main", 0.0, Vector3.ZERO, Vector3.ZERO)
	rotate_anim.add_keyframe_data("main", 2.0, Vector3.ZERO, Vector3(0, TAU, 0))

class VoxelAnimation extends Resource:
	@export var name: String = ""
	@export var duration: float = 1.0
	@export var loop: bool = true
	@export var keyframes: Array = []
	
	func add_keyframe(keyframe: VoxelKeyframe):
		keyframes.append(keyframe)
	
	func add_keyframe_data(part_name: String, time: float, position: Vector3, 
						  rotation: Vector3, scale: Vector3 = Vector3.ONE, 
						  interpolation: VoxelKeyframe.InterpolationType = VoxelKeyframe.InterpolationType.LINEAR):
		var keyframe = VoxelKeyframe.new()
		keyframe.time = time
		keyframe.part_name = part_name
		keyframe.position = position
		keyframe.rotation = rotation
		keyframe.scale = scale
		keyframe.interpolation = interpolation
		add_keyframe(keyframe)
	
	func get_keyframes_for_part(part_name: String) -> Array:
		var result: Array = []
		for keyframe in keyframes:
			if keyframe.part_name == part_name:
				result.append(keyframe)
		return result
	
	func remove_keyframes_for_part(part_name: String):
		keyframes = keyframes.filter(func(kf): return kf.part_name != part_name)

class VoxelKeyframe extends Resource:
	enum InterpolationType {
		LINEAR,
		CUBIC,
		STEP
	}
	
	@export var time: float = 0.0
	@export var part_name: String = ""
	@export var position: Vector3 = Vector3.ZERO
	@export var rotation: Vector3 = Vector3.ZERO
	@export var scale: Vector3 = Vector3.ONE
	@export var interpolation: InterpolationType = InterpolationType.LINEAR