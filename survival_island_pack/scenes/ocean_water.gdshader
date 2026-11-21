shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.11, 0.38, 0.46, 0.86);
uniform vec4 deep_color : source_color = vec4(0.03, 0.13, 0.22, 0.94);
uniform float wave_speed = 0.55;
uniform float wave_height = 0.14;
uniform float wave_scale = 0.12;

varying float v_wave;

void vertex() {
    float t = TIME * wave_speed;
    float w = sin(VERTEX.x * wave_scale + t) * cos(VERTEX.z * wave_scale * 0.85 - t * 0.8);
    w += 0.45 * sin((VERTEX.x + VERTEX.z) * wave_scale * 1.9 - t * 1.3);
    VERTEX.y += w * wave_height;
    v_wave = w;
}

void fragment() {
    float mix_f = clamp(v_wave * 0.35 + 0.5, 0.0, 1.0);
    vec3 col = mix(deep_color.rgb, shallow_color.rgb, mix_f);
    // Subtle crest foam
    float foam = smoothstep(0.82, 1.15, v_wave);
    ALBEDO = mix(col, vec3(0.75, 0.86, 0.90), foam * 0.28);
    ROUGHNESS = 0.22;
    METALLIC = 0.08;
    ALPHA = mix(deep_color.a, shallow_color.a, mix_f);
}
