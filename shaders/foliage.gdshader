shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float wind = sin(TIME * 1.7 + world.x * 0.11 + world.z * 0.14);
    VERTEX.x += wind * COLOR.a * 0.42;
    VERTEX.z += cos(TIME * 1.3 + world.x * 0.09) * COLOR.a * 0.2;
}
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.76;
    BACKLIGHT = COLOR.rgb * 0.3;
}
