shader_type spatial;

varying vec3 world_position;

void vertex() {
	world_position = VERTEX;
}

void fragment() {
	// Create checker pattern based on world coordinates
	vec2 checker_coord = world_position.xz * 0.1; // 20 squares across the 200x200 floor (200 * 0.1 = 20)
	vec2 checker = floor(checker_coord);
	
	// Determine if we're on an even or odd square
	float checker_value = mod(checker.x + checker.y, 2.0);
	
	// Two different shades of green
	vec3 light_green = vec3(0.3, 0.9, 0.3);
	vec3 dark_green = vec3(0.1, 0.6, 0.1);
	
	// Mix between the two greens based on checker pattern
	vec3 final_color = mix(dark_green, light_green, checker_value);
	
	ALBEDO = final_color;
}