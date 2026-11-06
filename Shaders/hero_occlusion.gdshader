shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled, cull_back;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
void fragment() {
    float surface_depth = texture(scene_depth, SCREEN_UV).r;
    // Godot 4.7 uses reverse Z: a smaller value lies behind opaque geometry.
    if (FRAGCOORD.z >= surface_depth - 0.00005) { discard; }
    float rim = 1.0 - smoothstep(0.15, 0.65, abs(dot(normalize(NORMAL), normalize(VIEW))));
    ALBEDO = vec3(0.25, 0.9, 0.78);
    ALPHA = rim * 0.8;
}
