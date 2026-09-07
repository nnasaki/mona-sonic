shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.z += sin(VERTEX.y * 0.24 + TIME * 3.0 + VERTEX.x) * 0.28;
}
void fragment() {
    float streak = sin(UV.x * 135.0 + sin(UV.x * 32.0) * 2.0 + UV.y * 5.0 - TIME * 4.0);
    float flow = sin(UV.y * 95.0 + UV.x * 12.0 - TIME * 13.0);
    ALBEDO = mix(vec3(0.11, 0.69, 0.8), vec3(0.91, 0.99, 1.0), 0.65 + streak * 0.18 + flow * 0.1);
    EMISSION = vec3(0.10, 0.2, 0.23);
    ROUGHNESS = 0.22;
    ALPHA = 0.88;
}
