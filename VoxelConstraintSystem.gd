extends Node
class_name VoxelConstraintSystem

@export var skeleton: VoxelSkeleton
@export var enforce_physics: bool = true
@export var ground_contact_required: bool = true

var constraints: Array = []
var gait_patterns: Dictionary = {}
var balance_solver: BalanceSolver

signal constraint_violated(constraint: VoxelConstraint, part_name: String)
signal balance_lost(skeleton: VoxelSkeleton)

func _ready():
	balance_solver = BalanceSolver.new()
	if skeleton:
		setup_default_constraints_for_entity_type(skeleton.entity_type)

func _physics_process(delta):
	if skeleton and enforce_physics:
		apply_constraints(delta)
		check_balance()

func add_constraint(constraint: VoxelConstraint):
	constraints.append(constraint)

func remove_constraint(constraint: VoxelConstraint):
	constraints.erase(constraint)

func apply_constraints(delta: float):
	for constraint in constraints:
		if constraint.enabled:
			constraint.apply_constraint(skeleton, delta)
			
			if not constraint.is_satisfied(skeleton):
				constraint_violated.emit(constraint, constraint.target_part_name)

func check_balance():
	if balance_solver and ground_contact_required:
		if not balance_solver.is_skeleton_balanced(skeleton):
			balance_lost.emit(skeleton)

func setup_default_constraints_for_entity_type(entity_type: VoxelSkeleton.EntityType):
	match entity_type:
		VoxelSkeleton.EntityType.HUMANOID:
			setup_humanoid_constraints()
		VoxelSkeleton.EntityType.QUADRUPED:
			setup_quadruped_constraints()
		VoxelSkeleton.EntityType.BIRD:
			setup_bird_constraints()
		VoxelSkeleton.EntityType.OBJECT:
			setup_object_constraints()

func setup_humanoid_constraints():
	var limb_length_constraint = LimbLengthConstraint.new()
	limb_length_constraint.target_part_name = "arm_left"
	limb_length_constraint.parent_part_name = "torso"
	limb_length_constraint.max_extension = 3.0
	add_constraint(limb_length_constraint)
	
	var ground_contact = GroundContactConstraint.new()
	ground_contact.target_part_name = "leg_left"
	ground_contact.required_contact = true
	add_constraint(ground_contact)
	
	var joint_rotation = JointRotationConstraint.new()
	joint_rotation.target_part_name = "head"
	joint_rotation.min_rotation = Vector3(-45, -90, -30)
	joint_rotation.max_rotation = Vector3(45, 90, 30)
	add_constraint(joint_rotation)

func setup_quadruped_constraints():
	var leg_sync = LegSyncConstraint.new()
	leg_sync.leg_pairs = [["leg_front_left", "leg_back_right"], ["leg_front_right", "leg_back_left"]]
	leg_sync.sync_type = LegSyncConstraint.SyncType.ALTERNATING
	add_constraint(leg_sync)
	
	var body_level = BodyLevelConstraint.new()
	body_level.target_part_name = "body"
	body_level.maintain_level = true
	body_level.max_tilt = 15.0
	add_constraint(body_level)

func setup_bird_constraints():
	var wing_sync = WingSyncConstraint.new()
	wing_sync.left_wing = "wing_left"
	wing_sync.right_wing = "wing_right"
	wing_sync.sync_type = WingSyncConstraint.SyncType.OPPOSITE_PHASE
	add_constraint(wing_sync)
	
	var flight_posture = FlightPostureConstraint.new()
	flight_posture.target_part_name = "body"
	flight_posture.required_angle = Vector3(15, 0, 0)
	add_constraint(flight_posture)

func setup_object_constraints():
	var stability = StabilityConstraint.new()
	stability.target_part_name = "main"
	stability.prevent_overshoot = true
	add_constraint(stability)

func create_gait_pattern(name: String, entity_type: VoxelSkeleton.EntityType) -> GaitPattern:
	var gait = GaitPattern.new()
	gait.name = name
	gait.entity_type = entity_type
	
	match entity_type:
		VoxelSkeleton.EntityType.HUMANOID:
			setup_humanoid_gait(gait, name)
		VoxelSkeleton.EntityType.QUADRUPED:
			setup_quadruped_gait(gait, name)
		VoxelSkeleton.EntityType.BIRD:
			setup_bird_gait(gait, name)
	
	gait_patterns[name] = gait
	return gait

func setup_humanoid_gait(gait: GaitPattern, gait_name: String):
	match gait_name:
		"walk":
			gait.add_step("leg_left", 0.0, 0.5)
			gait.add_step("leg_right", 0.5, 1.0)
			gait.cycle_duration = 1.0
		"run":
			gait.add_step("leg_left", 0.0, 0.3)
			gait.add_step("leg_right", 0.4, 0.7)
			gait.cycle_duration = 0.6

func setup_quadruped_gait(gait: GaitPattern, gait_name: String):
	match gait_name:
		"walk":
			gait.add_step("leg_front_left", 0.0, 0.3)
			gait.add_step("leg_back_right", 0.1, 0.4)
			gait.add_step("leg_front_right", 0.5, 0.8)
			gait.add_step("leg_back_left", 0.6, 0.9)
			gait.cycle_duration = 1.2
		"gallop":
			gait.add_step("leg_front_left", 0.0, 0.2)
			gait.add_step("leg_front_right", 0.1, 0.3)
			gait.add_step("leg_back_left", 0.4, 0.6)
			gait.add_step("leg_back_right", 0.5, 0.7)
			gait.cycle_duration = 0.8

func setup_bird_gait(gait: GaitPattern, gait_name: String):
	match gait_name:
		"fly":
			gait.add_step("wing_left", 0.0, 0.5)
			gait.add_step("wing_right", 0.25, 0.75)
			gait.cycle_duration = 0.5

func apply_gait_pattern(gait_name: String, time: float):
	if not gait_name in gait_patterns:
		return
	
	var gait = gait_patterns[gait_name]
	gait.apply_to_skeleton(skeleton, time)

class VoxelConstraint extends Resource:
	@export var constraint_name: String = ""
	@export var target_part_name: String = ""
	@export var enabled: bool = true
	@export var priority: int = 1
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		pass
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		return true

class LimbLengthConstraint extends VoxelConstraint:
	@export var parent_part_name: String = ""
	@export var max_extension: float = 3.0
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var target_part = skeleton.get_part(target_part_name)
		var parent_part = skeleton.get_part(parent_part_name)
		
		if not target_part or not parent_part:
			return
		
		var distance = target_part.global_position.distance_to(parent_part.global_position)
		if distance > max_extension:
			var direction = (target_part.global_position - parent_part.global_position).normalized()
			target_part.global_position = parent_part.global_position + direction * max_extension
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		var target_part = skeleton.get_part(target_part_name)
		var parent_part = skeleton.get_part(parent_part_name)
		
		if not target_part or not parent_part:
			return false
		
		var distance = target_part.global_position.distance_to(parent_part.global_position)
		return distance <= max_extension

class GroundContactConstraint extends VoxelConstraint:
	@export var required_contact: bool = true
	@export var ground_level: float = 0.0
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return
		
		if required_contact and target_part.global_position.y < ground_level:
			target_part.global_position.y = ground_level
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return false
		
		if required_contact:
			return target_part.global_position.y >= ground_level
		return true

class JointRotationConstraint extends VoxelConstraint:
	@export var min_rotation: Vector3 = Vector3(-180, -180, -180)
	@export var max_rotation: Vector3 = Vector3(180, 180, 180)
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return
		
		var rotation = target_part.rotation_degrees
		rotation.x = clamp(rotation.x, min_rotation.x, max_rotation.x)
		rotation.y = clamp(rotation.y, min_rotation.y, max_rotation.y)
		rotation.z = clamp(rotation.z, min_rotation.z, max_rotation.z)
		target_part.rotation_degrees = rotation
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return false
		
		var rotation = target_part.rotation_degrees
		return (rotation.x >= min_rotation.x and rotation.x <= max_rotation.x and
				rotation.y >= min_rotation.y and rotation.y <= max_rotation.y and
				rotation.z >= min_rotation.z and rotation.z <= max_rotation.z)

class LegSyncConstraint extends VoxelConstraint:
	enum SyncType {
		ALTERNATING,
		SYNCHRONIZED,
		GALLOP_PATTERN
	}
	
	@export var leg_pairs: Array = []
	@export var sync_type: SyncType = SyncType.ALTERNATING
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		match sync_type:
			SyncType.ALTERNATING:
				apply_alternating_pattern(skeleton)
			SyncType.SYNCHRONIZED:
				apply_synchronized_pattern(skeleton)
			SyncType.GALLOP_PATTERN:
				apply_gallop_pattern(skeleton)
	
	func apply_alternating_pattern(skeleton: VoxelSkeleton):
		for pair in leg_pairs:
			if pair.size() >= 2:
				var leg1 = skeleton.get_part(pair[0])
				var leg2 = skeleton.get_part(pair[1])
				
				if leg1 and leg2:
					if leg1.position.y > 0 and leg2.position.y > 0:
						leg2.position.y = 0
	
	func apply_synchronized_pattern(skeleton: VoxelSkeleton):
		pass
	
	func apply_gallop_pattern(skeleton: VoxelSkeleton):
		pass
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		return true

class WingSyncConstraint extends VoxelConstraint:
	enum SyncType {
		OPPOSITE_PHASE,
		SYNCHRONIZED
	}
	
	@export var left_wing: String = ""
	@export var right_wing: String = ""
	@export var sync_type: SyncType = SyncType.OPPOSITE_PHASE
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var left = skeleton.get_part(left_wing)
		var right = skeleton.get_part(right_wing)
		
		if not left or not right:
			return
		
		match sync_type:
			SyncType.OPPOSITE_PHASE:
				right.rotation.z = -left.rotation.z
			SyncType.SYNCHRONIZED:
				right.rotation.z = left.rotation.z
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		return true

class BodyLevelConstraint extends VoxelConstraint:
	@export var maintain_level: bool = true
	@export var max_tilt: float = 15.0
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var target_part = skeleton.get_part(target_part_name)
		if not target_part or not maintain_level:
			return
		
		var rotation = target_part.rotation_degrees
		if abs(rotation.x) > max_tilt:
			rotation.x = sign(rotation.x) * max_tilt
		if abs(rotation.z) > max_tilt:
			rotation.z = sign(rotation.z) * max_tilt
		
		target_part.rotation_degrees = rotation
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return false
		
		var rotation = target_part.rotation_degrees
		return abs(rotation.x) <= max_tilt and abs(rotation.z) <= max_tilt

class FlightPostureConstraint extends VoxelConstraint:
	@export var required_angle: Vector3 = Vector3.ZERO
	@export var tolerance: float = 10.0
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return
		
		var current_rotation = target_part.rotation_degrees
		var target_rotation = required_angle
		
		target_part.rotation_degrees = current_rotation.lerp(target_rotation, delta * 2.0)
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return false
		
		var diff = target_part.rotation_degrees - required_angle
		return diff.length() <= tolerance

class StabilityConstraint extends VoxelConstraint:
	@export var prevent_overshoot: bool = true
	@export var max_velocity: float = 10.0
	
	var previous_position: Vector3
	
	func apply_constraint(skeleton: VoxelSkeleton, delta: float):
		var target_part = skeleton.get_part(target_part_name)
		if not target_part:
			return
		
		if prevent_overshoot:
			var velocity = (target_part.global_position - previous_position) / delta
			if velocity.length() > max_velocity:
				target_part.global_position = previous_position + velocity.normalized() * max_velocity * delta
		
		previous_position = target_part.global_position
	
	func is_satisfied(skeleton: VoxelSkeleton) -> bool:
		return true

class GaitPattern extends Resource:
	@export var name: String = ""
	@export var entity_type: VoxelSkeleton.EntityType
	@export var cycle_duration: float = 1.0
	@export var steps: Array = []
	
	func add_step(part_name: String, start_time: float, end_time: float):
		var step = GaitStep.new()
		step.part_name = part_name
		step.start_time = start_time
		step.end_time = end_time
		steps.append(step)
	
	func apply_to_skeleton(skeleton: VoxelSkeleton, time: float):
		var cycle_time = fmod(time, cycle_duration) / cycle_duration
		
		for step in steps:
			var part = skeleton.get_part(step.part_name)
			if not part:
				continue
			
			if cycle_time >= step.start_time and cycle_time <= step.end_time:
				var step_progress = (cycle_time - step.start_time) / (step.end_time - step.start_time)
				apply_step_to_part(part, step_progress)

	func apply_step_to_part(part: VoxelPart, progress: float):
		var lift_height = sin(progress * PI) * 0.5
		part.position.y = lift_height

class GaitStep extends Resource:
	@export var part_name: String = ""
	@export var start_time: float = 0.0
	@export var end_time: float = 1.0

class BalanceSolver extends RefCounted:
	func is_skeleton_balanced(skeleton: VoxelSkeleton) -> bool:
		if not skeleton or not skeleton.root_part:
			return false
		
		var ground_contact_parts = get_ground_contact_parts(skeleton)
		if ground_contact_parts.is_empty():
			return false
		
		var center_of_mass = calculate_center_of_mass(skeleton)
		var support_polygon = calculate_support_polygon(ground_contact_parts)
		
		return point_in_polygon_2d(Vector2(center_of_mass.x, center_of_mass.z), support_polygon)
	
	func get_ground_contact_parts(skeleton: VoxelSkeleton) -> Array[VoxelPart]:
		var contact_parts: Array[VoxelPart] = []
		var ground_threshold = 0.1
		
		for part in skeleton.get_all_parts():
			if part.global_position.y <= ground_threshold:
				contact_parts.append(part)
		
		return contact_parts
	
	func calculate_center_of_mass(skeleton: VoxelSkeleton) -> Vector3:
		var total_mass = 0.0
		var weighted_position = Vector3.ZERO
		
		for part in skeleton.get_all_parts():
			var mass = part.voxel_positions.size()
			total_mass += mass
			weighted_position += part.global_position * mass
		
		if total_mass > 0:
			return weighted_position / total_mass
		
		return Vector3.ZERO
	
	func calculate_support_polygon(contact_parts: Array[VoxelPart]) -> Array[Vector2]:
		var points: Array[Vector2] = []
		
		for part in contact_parts:
			points.append(Vector2(part.global_position.x, part.global_position.z))
		
		return convex_hull_2d(points)
	
	func point_in_polygon_2d(point: Vector2, polygon: Array[Vector2]) -> bool:
		if polygon.size() < 3:
			return false
		
		var inside = false
		var j = polygon.size() - 1
		
		for i in range(polygon.size()):
			if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
			   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / \
			   (polygon[j].y - polygon[i].y) + polygon[i].x):
				inside = !inside
			j = i
		
		return inside
	
	func convex_hull_2d(points: Array[Vector2]) -> Array[Vector2]:
		if points.size() < 3:
			return points
		
		points.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
		
		var hull: Array[Vector2] = []
		
		for i in range(points.size()):
			while hull.size() >= 2 and cross_product_2d(hull[hull.size()-2], hull[hull.size()-1], points[i]) <= 0:
				hull.pop_back()
			hull.append(points[i])
		
		var t = hull.size() + 1
		for i in range(points.size() - 2, -1, -1):
			while hull.size() >= t and cross_product_2d(hull[hull.size()-2], hull[hull.size()-1], points[i]) <= 0:
				hull.pop_back()
			hull.append(points[i])
		
		hull.pop_back()
		return hull
	
	func cross_product_2d(o: Vector2, a: Vector2, b: Vector2) -> float:
		return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
