shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec3 focus_position = vec3(10000.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
    vec3 offset = world_position - focus_position;
    // Camera is above and south of the hero; fade only foreground canopy.
    float corridor = abs(offset.x);
    float ahead = offset.z;
    float fade = (1.0 - smoothstep(7.0, 14.0, corridor)) * smoothstep(-4.0, 2.0, ahead) * (1.0 - smoothstep(25.0, 40.0, ahead));
    ALPHA = mix(1.0, 0.17, fade);
}
