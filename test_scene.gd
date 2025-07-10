extends Control

# Simple test script for the Hello World scene
func _ready():
	print("Hello World scene loaded!")
	test_volume_sampling_stairs()

func test_volume_sampling_stairs():
	print("=== Testing Volume Sampling with Stairs.obj ===")
	
	var file_path = "res://stairs.obj"
	var obj_data = VoxelMeshLoader.load_obj_file(file_path)
	
	if obj_data.is_empty():
		print("ERROR: Failed to load stairs.obj file")
		return
	
	print("Stairs OBJ loaded:")
	print("  Vertices: ", obj_data.vertices.size())
	print("  Faces: ", obj_data.faces.size())
	
	# Test the new volume sampling voxelization
	var voxel_parts = VoxelMeshLoader.convert_obj_to_voxels(obj_data, false)
	if "main" in voxel_parts:
		print("\\nGenerated voxels: ", voxel_parts["main"])
		print("Voxel count: ", voxel_parts["main"].size())
		print("Expected: 3 voxels for staircase")
		
		if voxel_parts["main"].size() == 3:
			print("SUCCESS: Correctly extracted 3 voxels!")
		else:
			print("Still needs improvement...")
	
	print("=== Volume Sampling Test Complete ===")