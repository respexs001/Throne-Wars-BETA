shader_type canvas_item;
// menu_fog.gdshader — живой фон главного меню.
//   • Многослойный туман (3 синусоидальных шума, плывут с разной скоростью).
//   • Медленная «аврора» — золотые полосы по диагонали.
//   • Мерцающие искры — точечные вспышки по псевдослучайной сетке.
// Все параметры вынесены в uniform — можно подкрутить в редакторе.

uniform vec4 base_color : source_color = vec4(0.025, 0.035, 0.045, 1.0);
uniform vec4 fog_color : source_color = vec4(0.10, 0.15, 0.18, 1.0);
uniform vec4 aurora_color : source_color = vec4(0.55, 0.17, 0.13, 1.0);
uniform vec4 spark_color : source_color = vec4(0.7, 0.4, 0.3, 1.0);
uniform float speed = 0.15;
uniform float fog_scale = 2.5;
uniform float aurora_intensity = 0.55;
uniform float spark_intensity = 0.9;
uniform float vignette_strength = 0.75;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise2(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    vec2 aspect_uv = uv * vec2(1.777, 1.0);   // ~16:9
    float t = TIME * speed;

    // --- многослойный туман ---
    float fog = 0.0;
    fog += fbm(aspect_uv * fog_scale + vec2(t * 0.5, t * 0.3));
    fog += 0.6 * fbm(aspect_uv * fog_scale * 1.7 + vec2(-t * 0.4, t * 0.5));
    fog += 0.4 * fbm(aspect_uv * fog_scale * 3.1 + vec2(t * 0.8, -t * 0.6));
    fog = fog / 2.0;

    vec3 col = mix(base_color.rgb, fog_color.rgb, smoothstep(0.35, 0.8, fog));

    // --- аврора: диагональные золотые полосы ---
    float aurora_x = uv.x + uv.y * 0.6 + t * 0.35;
    float aurora = sin(aurora_x * 6.28) * 0.5 + 0.5;
    aurora = pow(aurora, 3.0);
    // мягкая маска сверху-снизу, чтобы не перекрывать края
    float aurora_mask = smoothstep(0.0, 0.6, uv.y) * smoothstep(1.0, 0.4, uv.y);
    col += aurora_color.rgb * aurora * aurora_intensity * aurora_mask * 0.35;

    // --- искры: точечные вспышки по сетке ---
    vec2 spark_uv = aspect_uv * 45.0;
    vec2 spark_id = floor(spark_uv);
    vec2 spark_local = fract(spark_uv) - 0.5;
    float spark_rand = hash21(spark_id);
    // анимируем: каждая ячейка мерцает со своей фазой
    float spark_phase = fract(spark_rand + TIME * 0.4);
    float spark_size = mix(0.02, 0.08, spark_rand);
    float spark_dist = length(spark_local);
    float spark = smoothstep(spark_size, 0.0, spark_dist);
    // мерцание: только часть ячеек «горит» в данный момент
    float spark_on = step(0.85, spark_rand) * smoothstep(0.0, 0.5, spark_phase) * smoothstep(1.0, 0.5, spark_phase);
    col += spark_color.rgb * spark * spark_on * spark_intensity;

    // --- виньетка (радиальная) ---
    vec2 vuv = uv - 0.5;
    vuv.x *= 1.777;
    float vig = 1.0 - smoothstep(0.35, 0.95, length(vuv)) * vignette_strength;
    col *= vig;

    // Сохраняем альфу ColorRect.modulate: без этого полноэкранный туман
    // становится полностью непрозрачным и скрывает 3D-модели под ним.
    COLOR = vec4(col, COLOR.a);
}