shader_type canvas_item;

uniform vec4 top_color    : source_color = vec4(0.12, 0.20, 0.42, 1.0);
uniform vec4 mid_color    : source_color = vec4(0.08, 0.30, 0.56, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.04, 0.10, 0.22, 1.0);
uniform float vignette_strength = 0.28;
uniform float star_brightness = 1.55;
uniform float time_scale = 0.25;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

// HERO TWINKLE - soft glow pulses, rolling tide feel
float hero_twinkle(vec2 base_uv, float t) {
    float total = 0.0;
    
    // multiple overlapping scales for organic distribution
    for (int i = 0; i < 3; i++) {
        float scale = 20.0 + float(i) * 12.0;  // 20, 32, 44
        vec2 cell_uv = base_uv * scale;
        vec2 id = floor(cell_uv);
        vec2 gv = fract(cell_uv) - 0.5;
        
        // unique seed per layer
        float seed = hash(id + float(i) * 100.0);
        
        // rare selection - spread across screen
        float is_hero = step(0.97, seed);
        
        // position inside cell
        vec2 jitter = vec2(hash(id + 4.1), hash(id + 8.3)) - 0.5;
        vec2 p = gv - jitter * 0.4;
        
        // soft circular falloff
        float d = length(p);
        float size = mix(0.08, 0.04, hash(id + 2.7));
        float core = smoothstep(size, 0.0, d);
        float glow = smoothstep(size * 3.0, 0.0, d) * 0.3;
        
        // SLOW lazy pulse - different phase per star
        float phase = seed * 6.283;
        float pulse_speed = 0.3 + seed * 0.4;  // 0.3 to 0.7 - lazy
        float pulse = sin(t * pulse_speed + phase);
        pulse = pulse * 0.5 + 0.5;  // 0 to 1
        pulse = smoothstep(0.4, 0.9, pulse);  // soft fade in/out
        
        total += is_hero * (core + glow) * pulse;
    }
    
    return total;
}

float star_layer(vec2 uv, float scale, float density) {
    vec2 gv = fract(uv * scale) - 0.5;
    vec2 id = floor(uv * scale);
    float n = hash(id);
    float present = step(1.0 - density, n);
    vec2 jitter = vec2(hash(id + 1.7), hash(id + 9.2)) - 0.5;
    vec2 p = gv - jitter * 0.35;
    float d = length(p);
    // bigger stars - visible pinpricks not static
    float size = mix(0.055, 0.012, hash(id + 3.1));
    float core = smoothstep(size, 0.0, d);
    float halo = smoothstep(size * 2.5, 0.0, d) * 0.4;
    float b = mix(0.35, 1.0, hash(id + 5.4));
    b += step(0.985, hash(id + 7.7)) * 1.25;
    return present * (core + halo) * b;
}

void fragment() {
    vec2 base_uv = UV;  // preserve clean UV for hero twinkle
    vec2 uv = UV;
    float t = TIME * time_scale;
    
    // slow oceanic bob - floating in space water, lazy drift
    uv.y += sin(t * 0.15) * 0.008;
    uv.x += cos(t * 0.12) * 0.006;
    
    // ship breathing - 30-60 second tilt cycle, microscopic but felt
    uv += vec2(
        sin(t * 0.1) * 0.002,
        cos(t * 0.13) * 0.002
    );
    
    // gradient
    vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.55, uv.y));
    col = mix(col, bottom_color.rgb, smoothstep(0.45, 1.0, uv.y));
    
    // vignette
    vec2 p = uv - 0.5;
    float v = smoothstep(0.65, 0.15, dot(p, p));
    col *= mix(1.0 - vignette_strength, 1.0, v);
    
    // parallax layers (far → near) - multiplane camera trick, lazy orbit speeds
    vec2 far_uv  = uv + vec2(t * 0.002, t * -0.001);
    vec2 mid_uv  = uv + vec2(t * 0.004, t * -0.002);
    vec2 near_uv = uv + vec2(t * 0.0092, t * -0.0046);  // 15% faster
    
    // very subtle rotational drift - 0.5 degrees over 60 seconds
    float rot_angle = t * 0.000145;  // ~0.5° per 60s
    mat2 rot = mat2(vec2(cos(rot_angle), -sin(rot_angle)), vec2(sin(rot_angle), cos(rot_angle)));
    vec2 rotated_uv = (uv - 0.5) * rot + 0.5;
    
    // fewer star cells = bigger visible stars, not static
    float stars =
        star_layer(far_uv, 70.0, 0.03) * 0.6 +    // far: slow, dim
        star_layer(mid_uv, 45.0, 0.04) * 0.8 +    // mid: medium
        star_layer(near_uv, 25.0, 0.05) * 1.1;    // near: larger, faster, bright
    
    // foreground dust layer - very faint, moves fastest, sells the depth
    vec2 dust_uv = rotated_uv + vec2(t * 0.015, t * -0.008);
    float dust = star_layer(dust_uv, 15.0, 0.02) * 0.25;  // sparse, subtle
    stars += dust;
    
    // UI safe zone (soft dim in center area for legibility)
    float center = smoothstep(0.55, 0.0, length(UV - vec2(0.5, 0.52)));
    float ui_safe = mix(1.0, 0.75, center);
    stars *= ui_safe;
    
    vec3 star_col = vec3(0.95, 0.98, 1.0) * stars * star_brightness;
    col += star_col;
    
    // HERO TWINKLE - soft glows, rolling tide feel
    float hero = hero_twinkle(base_uv, t) * ui_safe;
    col += vec3(0.95, 0.98, 1.0) * hero * 1.8;
    
    // subtle global shimmer - whole starfield breathes
    float shimmer = 0.02 * (sin(t * 0.7) * 0.5 + 0.5);
    col += vec3(1.0) * shimmer * stars;
    
    // cinematic blue wash - storybook glow
    col = mix(col, vec3(0.18, 0.32, 0.60), 0.08);
    
    COLOR = vec4(col, 1.0);
}
