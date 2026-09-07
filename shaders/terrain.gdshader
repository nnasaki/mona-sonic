shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.52, 0.24, 0.09, 1.0);
uniform vec4 second_color : source_color = vec4(0.78, 0.43, 0.18, 1.0);
uniform float checker_size = 5.0;
uniform bool checkered = true;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = vec2(world.x + world.z * 0.31, world.y) / checker_size;
    float check = mod(floor(p.x) + floor(p.y), 2.0);
    float noise = sin(world.x * 7.3 + sin(world.y * 5.1)) * sin(world.z * 8.6 + world.y * 4.7);
    ALBEDO = mix(base_color.rgb, second_color.rgb, checkered ? check * 0.74 : 0.25 + noise * 0.1);
    ALBEDO *= 0.96 + noise * 0.045;
    ROUGHNESS = 0.87;
}
