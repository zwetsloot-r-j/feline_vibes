extends Node3D

@onready var voxel_generator = $VoxelGenerator

func _ready():
	print("Voxel World Controller ready!")
	print("Press 'R' to regenerate the world")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			print("Regenerating voxel world...")
			voxel_generator.regenerate_map()