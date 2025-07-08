extends Node3D

@onready var voxel_generator = $VoxelGenerator

func _ready():
	print("Voxel World Controller ready!")
	print("Press 'R' to regenerate the world")
	print("Press 'P' to print performance stats")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			print("Regenerating voxel world...")
			voxel_generator.regenerate_map()
		elif event.keycode == KEY_P:
			print("Printing performance stats...")
			voxel_generator.print_performance_summary()