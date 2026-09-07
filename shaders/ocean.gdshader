shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.015, 0.32, 0.46);
uniform vec3 shallow_color : source_color = vec3(0.04, 0.72, 0.76);
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world.x * 0.075 + TIME * 0.65) * 0.65 + sin(world.z * 0.1 + TIME * 0.85) * 0.35;
}
void fragment() {
    float a = sin(world.x * 0.20 + sin(world.z * 0.16 + TIME) * 1.8 + TIME * 1.1);
    float b = sin(world.z * 0.34 + sin(world.x * 0.22) * 1.5 - TIME * 0.8);
    float foam = pow(max(0.0, a * b), 18.0);
    float broad = sin(world.x * 0.016 + world.z * 0.024) * 0.5 + 0.5;
    ALBEDO = mix(deep_color, shallow_color, broad * 0.6 + 0.2) + foam * 0.19;
    NORMAL_MAP = vec3(0.5 + a * 0.13, 0.5 + b * 0.13, 1.0);
    ROUGHNESS = 0.2;
    METALLIC = 0.45;
    SPECULAR = 0.8;
}
