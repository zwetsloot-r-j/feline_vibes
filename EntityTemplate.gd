extends Resource
class_name EntityTemplate

@export var template_name: String = ""
@export var entity_type: VoxelSkeleton.EntityType = VoxelSkeleton.EntityType.HUMANOID
@export var part_definitions: Array = []
@export var connections: Array = []
@export var default_animations: Array = []
@export var movement_constraints: MovementConstraints

func _init():
	movement_constraints = MovementConstraints.new()

func add_part_definition(name: String, type: VoxelPart.PartType, positions: Array, 
						colors: Array = [], pivot_offset: Vector3 = Vector3.ZERO, 
						is_root: bool = false) -> PartDefinition:
	var part_def = PartDefinition.new()
	part_def.name = name
	part_def.type = type
	part_def.positions = positions
	part_def.colors = colors if colors.size() > 0 else []
	part_def.pivot_offset = pivot_offset
	part_def.is_root = is_root
	
	part_definitions.append(part_def)
	return part_def

func add_connection(parent_name: String, child_name: String, offset: Vector3 = Vector3.ZERO):
	var connection = PartConnection.new()
	connection.parent_name = parent_name
	connection.child_name = child_name
	connection.offset = offset
	
	connections.append(connection)

static func create_humanoid_template() -> EntityTemplate:
	var template = EntityTemplate.new()
	template.template_name = "Humanoid"
	template.entity_type = VoxelSkeleton.EntityType.HUMANOID
	
	template.add_part_definition("head", VoxelPart.PartType.HEAD, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0)], 
		[Color.BEIGE, Color.BEIGE, Color.BEIGE, Color.BEIGE])
	
	template.add_part_definition("torso", VoxelPart.PartType.TORSO, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
		 Vector3i(0, 2, 0), Vector3i(1, 2, 0)], 
		[Color.BLUE, Color.BLUE, Color.BLUE, Color.BLUE, Color.BLUE, Color.BLUE], 
		Vector3.ZERO, true)
	
	template.add_part_definition("arm_left", VoxelPart.PartType.ARM_LEFT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0)], 
		[Color.BEIGE, Color.BEIGE, Color.BEIGE])
	
	template.add_part_definition("arm_right", VoxelPart.PartType.ARM_RIGHT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0)], 
		[Color.BEIGE, Color.BEIGE, Color.BEIGE])
	
	template.add_part_definition("leg_left", VoxelPart.PartType.LEG_LEFT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0)], 
		[Color.BROWN, Color.BROWN, Color.BROWN])
	
	template.add_part_definition("leg_right", VoxelPart.PartType.LEG_RIGHT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0)], 
		[Color.BROWN, Color.BROWN, Color.BROWN])
	
	template.add_connection("torso", "head", Vector3(0.5, 3, 0))
	template.add_connection("torso", "arm_left", Vector3(-1, 2, 0))
	template.add_connection("torso", "arm_right", Vector3(2, 2, 0))
	template.add_connection("torso", "leg_left", Vector3(0, -1, 0))
	template.add_connection("torso", "leg_right", Vector3(1, -1, 0))
	
	template.default_animations = ["idle", "walk", "run", "jump"]
	
	return template

static func create_quadruped_template() -> EntityTemplate:
	var template = EntityTemplate.new()
	template.template_name = "Quadruped"
	template.entity_type = VoxelSkeleton.EntityType.QUADRUPED
	
	template.add_part_definition("head", VoxelPart.PartType.HEAD, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)], 
		[Color.BROWN, Color.BROWN, Color.BROWN, Color.BROWN])
	
	template.add_part_definition("body", VoxelPart.PartType.BODY, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0),
		 Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(3, 1, 0)], 
		[Color.BROWN, Color.BROWN, Color.BROWN, Color.BROWN, 
		 Color.BROWN, Color.BROWN, Color.BROWN, Color.BROWN], 
		Vector3.ZERO, true)
	
	template.add_part_definition("leg_front_left", VoxelPart.PartType.LEG_LEFT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0)], [Color.DARK_GRAY, Color.DARK_GRAY])
	
	template.add_part_definition("leg_front_right", VoxelPart.PartType.LEG_RIGHT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0)], [Color.DARK_GRAY, Color.DARK_GRAY])
	
	template.add_part_definition("leg_back_left", VoxelPart.PartType.LEG_LEFT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0)], [Color.DARK_GRAY, Color.DARK_GRAY])
	
	template.add_part_definition("leg_back_right", VoxelPart.PartType.LEG_RIGHT, 
		[Vector3i(0, 0, 0), Vector3i(0, 1, 0)], [Color.DARK_GRAY, Color.DARK_GRAY])
	
	template.add_part_definition("tail", VoxelPart.PartType.TAIL, 
		[Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2)], 
		[Color.BROWN, Color.BROWN, Color.BROWN])
	
	template.add_connection("body", "head", Vector3(4, 0, 0.5))
	template.add_connection("body", "leg_front_left", Vector3(0.5, -1, 0))
	template.add_connection("body", "leg_front_right", Vector3(0.5, -1, 1))
	template.add_connection("body", "leg_back_left", Vector3(2.5, -1, 0))
	template.add_connection("body", "leg_back_right", Vector3(2.5, -1, 1))
	template.add_connection("body", "tail", Vector3(-1, 0.5, 0.5))
	
	template.default_animations = ["idle", "walk", "run", "gallop"]
	
	return template

static func create_bird_template() -> EntityTemplate:
	var template = EntityTemplate.new()
	template.template_name = "Bird"
	template.entity_type = VoxelSkeleton.EntityType.BIRD
	
	template.add_part_definition("head", VoxelPart.PartType.HEAD, 
		[Vector3i(0, 0, 0)], [Color.YELLOW])
	
	template.add_part_definition("body", VoxelPart.PartType.BODY, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0)], 
		[Color.RED, Color.RED, Color.RED, Color.RED], Vector3.ZERO, true)
	
	template.add_part_definition("wing_left", VoxelPart.PartType.WING_LEFT, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)], 
		[Color.RED, Color.RED, Color.RED])
	
	template.add_part_definition("wing_right", VoxelPart.PartType.WING_RIGHT, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)], 
		[Color.RED, Color.RED, Color.RED])
	
	template.add_part_definition("leg_left", VoxelPart.PartType.LEG_LEFT, 
		[Vector3i(0, 0, 0)], [Color.ORANGE])
	
	template.add_part_definition("leg_right", VoxelPart.PartType.LEG_RIGHT, 
		[Vector3i(0, 0, 0)], [Color.ORANGE])
	
	template.add_part_definition("tail", VoxelPart.PartType.TAIL, 
		[Vector3i(0, 0, 0), Vector3i(0, 0, 1)], [Color.RED, Color.RED])
	
	template.add_connection("body", "head", Vector3(0.5, 2, 0))
	template.add_connection("body", "wing_left", Vector3(-1, 1, 0))
	template.add_connection("body", "wing_right", Vector3(2, 1, 0))
	template.add_connection("body", "leg_left", Vector3(0, -1, 0))
	template.add_connection("body", "leg_right", Vector3(1, -1, 0))
	template.add_connection("body", "tail", Vector3(0.5, 0, -1))
	
	template.default_animations = ["idle", "fly", "glide", "land"]
	
	return template

static func create_object_template() -> EntityTemplate:
	var template = EntityTemplate.new()
	template.template_name = "Object"
	template.entity_type = VoxelSkeleton.EntityType.OBJECT
	
	template.add_part_definition("main", VoxelPart.PartType.BODY, 
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
		 Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)], 
		[], Vector3.ZERO, true)
	
	template.default_animations = ["rotate", "bounce", "scale"]
	
	return template

func get_part_definition(part_name: String) -> PartDefinition:
	for part_def in part_definitions:
		if part_def.name == part_name:
			return part_def
	return null

func get_root_part_definition() -> PartDefinition:
	for part_def in part_definitions:
		if part_def.is_root:
			return part_def
	return null

func validate_template() -> bool:
	if part_definitions.is_empty():
		push_error("Template has no part definitions")
		return false
	
	var root_parts = 0
	for part_def in part_definitions:
		if part_def.is_root:
			root_parts += 1
	
	if root_parts != 1:
		push_error("Template must have exactly one root part, found: " + str(root_parts))
		return false
	
	for connection in connections:
		var parent_found = false
		var child_found = false
		
		for part_def in part_definitions:
			if part_def.name == connection.parent_name:
				parent_found = true
			if part_def.name == connection.child_name:
				child_found = true
		
		if not parent_found or not child_found:
			push_error("Connection references non-existent parts: " + 
					  connection.parent_name + " -> " + connection.child_name)
			return false
	
	return true

class PartDefinition extends Resource:
	@export var name: String = ""
	@export var type: VoxelPart.PartType = VoxelPart.PartType.BODY
	@export var positions: Array = []
	@export var colors: Array = []
	@export var pivot_offset: Vector3 = Vector3.ZERO
	@export var is_root: bool = false

class PartConnection extends Resource:
	@export var parent_name: String = ""
	@export var child_name: String = ""
	@export var offset: Vector3 = Vector3.ZERO

class MovementConstraints extends Resource:
	@export var max_limb_extension: float = 3.0
	@export var joint_rotation_limits: Dictionary = {}
	@export var balance_requirements: bool = true
	@export var ground_contact_points: Array = []
