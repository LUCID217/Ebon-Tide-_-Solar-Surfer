extends Node3D

# Vox Ignis Environment
# A shattered super-terrestrial world, broken long before the current age.
# Its planetary core is exposed, glowing ember-red.
# Continental fragments float suspended in unstable equilibrium.

# References
var player: CharacterBody3D
var camera: Camera3D

# Environment layers
var skybox: MeshInstance3D
var core_glow: MeshInstance3D
var core_crust: MeshInstance3D  # Broken shell around core
var planetary_fragments: Array[MeshInstance3D] = []
var debris_particles: GPUParticles3D
var dust_particles: GPUParticles3D
var ember_particles: GPUParticles3D

# Parallax layers
var far_fragments: Array[Node3D] = []    # Slow movement
var mid_fragments: Array[Node3D] = []    # Medium movement  
var near_debris: Array[Node3D] = []      # Fast movement

# Animation
var core_pulse_time: float = 0.0
var fragment_drift_time: float = 0.0

# Colors - Vox Ignis palette
const COLOR_CORE_CENTER: Color = Color(1.0, 0.78, 0.29)     # Molten Core Gold #FFC84A
const COLOR_CORE_EDGE: Color = Color(1.0, 0.54, 0.12)      # Solar Amber #FF8A1F
const COLOR_SKY_TOP: Color = Color(0.043, 0.063, 0.15)     # Void Indigo #0B1026
const COLOR_SKY_HORIZON: Color = Color(0.067, 0.1, 0.23)   # Abyss Blue #111A3A
const COLOR_FRAGMENT: Color = Color(0.1, 0.06, 0.03)       # Charred Black #1A0F08
const COLOR_FRAGMENT_GLOW: Color = Color(1.0, 0.54, 0.12)  # Solar Amber veins
const COLOR_DUST: Color = Color(0.12, 0.66, 0.83, 0.15)    # Teal Ion haze #1ECAD3
const COLOR_EMBER: Color = Color(1.0, 0.78, 0.29, 0.8)     # Gold embers

func _ready() -> void:
	call_deferred("initialize")

func initialize() -> void:
	player = get_parent().get_node_or_null("Player")
	camera = get_viewport().get_camera_3d()
	
	create_skybox()
	create_planetary_core()
	create_core_crust()  # Broken shell silhouette around core
	create_planetary_fragments()
	create_debris_field()
	create_atmosphere_particles()
	update_world_environment()

# ============ SKYBOX ============

func create_skybox() -> void:
	# Large inverted sphere for sky - will follow player
	skybox = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 800.0
	sphere.height = 1600.0
	sphere.radial_segments = 32
	sphere.rings = 16
	skybox.mesh = sphere
	
	var mat = ShaderMaterial.new()
	mat.shader = create_sky_shader()
	skybox.material_override = mat
	
	# Flip normals inward
	skybox.scale = Vector3(-1, 1, -1)
	
	add_child(skybox)

func create_sky_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front;

// Deep space base - unified navy with gentle variation
uniform vec3 sky_top_color : source_color = vec3(0.06, 0.08, 0.2);       // Slightly deeper at zenith
uniform vec3 sky_mid_color : source_color = vec3(0.08, 0.12, 0.28);      // Core navy tone
uniform vec3 sky_horizon_color : source_color = vec3(0.09, 0.11, 0.26);  // Similar to mid, gentle violet
uniform vec3 nebula_color : source_color = vec3(0.18, 0.14, 0.38);       // Nebula Violet
uniform vec3 core_color : source_color = vec3(1.0, 0.78, 0.29);          // Molten Core Gold
uniform float core_intensity : hint_range(0.0, 2.0) = 1.2;

varying vec3 world_pos;

// Hash functions for star + nebula noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

// Value noise for nebula
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM for nebula structure
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 dir = normalize(world_pos);
	float y = dir.y;
	
	// === SOFT SKY GRADIENT ===
	// Gentle transitions — the concept has a smooth, even navy field
	float lower_blend = smoothstep(-0.3, 0.3, y);
	float upper_blend = smoothstep(0.2, 0.8, y);
	vec3 sky = mix(sky_horizon_color, sky_mid_color, lower_blend);
	sky = mix(sky, sky_top_color, upper_blend);
	
	// === NEBULA — SOFT SWIRLING INDIGO ===
	// Not a hard band — gentle swirls that fade at edges like the concept
	vec2 nebula_uv = dir.xz / (abs(y) + 0.3) * 2.5;
	// Multiple noise layers for organic swirl structure
	float swirl1 = fbm(nebula_uv * 1.5 + vec2(0.3, 0.7));
	float swirl2 = fbm(nebula_uv * 2.2 + vec2(2.1, 1.3));
	float swirl3 = fbm(nebula_uv * 0.8 + vec2(4.5, 0.2));  // Large-scale shape
	// Combine: large shape modulates fine detail
	float nebula_mask = swirl3 * 0.6 + 0.2;  // Broad soft regions
	float nebula_detail = swirl1 * swirl2;     // Fine swirl texture
	float nebula_strength = nebula_mask * nebula_detail * 0.6;
	// Gentle fade — present everywhere but stronger in upper sky
	nebula_strength *= smoothstep(-0.2, 0.15, y);
	// Soft edges — fade out gently, don't cut hard
	nebula_strength = smoothstep(0.05, 0.25, nebula_strength) * 0.4;
	sky = mix(sky, nebula_color, nebula_strength);
	// Brighter highlights within the nebula (lighter indigo-blue wisps)
	float nebula_bright = fbm(nebula_uv * 3.5 + vec2(1.7, 2.3));
	float highlight = nebula_strength * nebula_bright;
	sky += vec3(0.12, 0.15, 0.3) * highlight * 0.5;
	
	// === DENSE STARFIELD ===
	float star = 0.0;
	// Layer 1: Bright stars — FEW but LARGE, lazy twinkle
	{
		vec2 star_uv = dir.xz / (abs(y) + 0.35) * 20.0;  // 0.35 floor prevents horizon explosion
		vec2 grid = floor(star_uv);
		vec2 grid_uv = fract(star_uv) - 0.5;
		float h = hash(grid);
		if (h > 0.95) {  // Was 0.92 — fewer stars
			vec2 soff = vec2(hash(grid + 1.0), hash(grid + 2.0)) - 0.5;
			soff *= 0.5;
			float d = length(grid_uv - soff);
			float b = smoothstep(0.18, 0.0, d);  // Was 0.09 — 4x bigger point
			// LAZY twinkle — matches menu
			float phase = h * 6.283;
			float pulse_speed = 0.2 + h * 0.3;
			float pulse = sin(TIME * pulse_speed + phase);
			pulse = pulse * 0.5 + 0.5;
			pulse = smoothstep(0.3, 0.85, pulse);
			float twinkle = 0.6 + pulse * 0.4;
			star = b * twinkle * (0.7 + h * 0.3);
		}
	}
	// Layer 2: Medium stars — fewer, bigger, steady
	{
		vec2 star_uv2 = dir.xz / (abs(y) + 0.35) * 40.0;
		vec2 grid2 = floor(star_uv2);
		vec2 grid_uv2 = fract(star_uv2) - 0.5;
		float h2 = hash2(grid2);
		if (h2 > 0.93) {  // Was 0.88 — fewer
			vec2 soff2 = vec2(hash2(grid2 + 3.0), hash2(grid2 + 4.0)) - 0.5;
			soff2 *= 0.4;
			float d2 = length(grid_uv2 - soff2);
			float b2 = smoothstep(0.12, 0.0, d2);  // Was 0.06 — bigger
			star += b2 * 0.4;
		}
	}
	// Stars visible EVERYWHERE — top to bottom, full canvas
	// No horizon fade — you're flying through space, stars are all around
	star *= 1.0;
	// Dim stars where nebula is bright (stars behind nebula)
	star *= (1.0 - nebula_strength * 0.6);
	
	// === CORE GLOW REMOVED FROM SKY ===
	// The planet mesh handles its own glow. The sky stays COLD.
	// No warm mixing. No warm emission. Hard edge between space and planet.
	
	// === COMPOSE ===
	// Add crisp stars — bright ones are white, dense dust is silver-blue
	vec3 star_color = mix(vec3(0.85, 0.9, 1.0), vec3(1.0, 0.98, 0.95), star);  // Warmer at peak brightness
	sky += star_color * star * 1.3;
	
	// Subtle dither to prevent banding
	float dither = fract(sin(dot(dir.xy, vec2(12.9898, 78.233))) * 43758.5453);
	sky += (dither - 0.5) * 0.008;
	
	ALBEDO = sky;
	// Sky emission is just the sky itself — NO warm component
	EMISSION = sky;
}
"""
	return shader

# ============ PLANETARY CORE ============

func create_planetary_core() -> void:
	# The exposed, glowing ember-red core - ALWAYS in the distance
	# This follows the camera so you're eternally racing toward it
	core_glow = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 150.0
	sphere.height = 300.0
	sphere.radial_segments = 48
	sphere.rings = 24
	core_glow.mesh = sphere
	
	var mat = ShaderMaterial.new()
	mat.shader = create_core_shader()
	core_glow.material_override = mat
	
	add_child(core_glow)

func create_core_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;

uniform vec3 core_color : source_color = vec3(1.0, 0.78, 0.29);   // Molten Core Gold
uniform vec3 edge_color : source_color = vec3(1.0, 0.54, 0.12);   // Solar Amber
uniform vec3 rim_color : source_color = vec3(0.37, 0.57, 1.0);    // Cool cyan-blue rim
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float time : hint_range(0.0, 1000.0) = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Fresnel for edge detection
	float fresnel = pow(1.0 - abs(dot(local_normal, VIEW)), 2.0);
	
	// Pulsing veins of energy — these are the molten cracks
	float vein = sin(local_pos.x * 3.0 + time) * sin(local_pos.y * 2.5 + time * 0.7) * sin(local_pos.z * 2.0 + time * 1.3);
	vein = smoothstep(0.3, 0.8, vein * 0.5 + 0.5);
	
	// Core to edge gradient — this is the SURFACE color, mostly dark
	// The planet reads as a dark body with bright fracture lines
	vec3 surface_color = mix(edge_color * 0.15, edge_color * 0.08, fresnel);
	
	// Crack veins — these are the ONLY light source
	vec3 vein_color = mix(core_color, vec3(1.0, 0.95, 0.8), 0.4);  // White-gold at hottest
	float crack_brightness = vein * vein;  // Squared = narrower, brighter peaks
	vec3 color = mix(surface_color, vein_color, crack_brightness);
	
	// Pulse effect
	float pulse_effect = 1.0 + pulse * 0.2;
	
	// === COOL RIM HALO ===
	float rim_factor = pow(fresnel, 3.0);
	vec3 rim = rim_color * rim_factor * 1.5;
	
	// EMISSION: only cracks emit. Surface is dark.
	// crack_brightness is 0 on surface, peaks to 1.0 in cracks
	ALBEDO = color;
	EMISSION = vein_color * crack_brightness * 2.5 * pulse_effect + rim;
}
"""
	return shader

# ============ CORE CRUST (BROKEN SHELL) ============

func create_core_crust() -> void:
	# Dark broken shell around the glowing core - makes it read as "planet" not "sun"
	core_crust = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 160.0  # Slightly larger than core (150)
	sphere.height = 320.0
	sphere.radial_segments = 48
	sphere.rings = 24
	core_crust.mesh = sphere
	
	var mat = ShaderMaterial.new()
	mat.shader = create_crust_shader()
	core_crust.material_override = mat
	
	add_child(core_crust)

func create_crust_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 crust_color : source_color = vec3(0.1, 0.06, 0.03);
uniform vec3 edge_glow : source_color = vec3(1.0, 0.78, 0.29);
uniform float time : hint_range(0.0, 1000.0) = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

// Simple noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Spherical UV from position
	vec2 uv = vec2(atan(local_pos.x, local_pos.z), asin(local_pos.y / length(local_pos)));
	uv = uv / 3.14159 * 2.5;  // Smaller scale = bigger chunks
	
	// Chunky noise for continental plates
	float n = noise(uv * 1.5) * 0.6 + noise(uv * 3.0) * 0.3 + noise(uv * 6.0) * 0.1;
	
	// Fresnel - stronger at edges
	float fresnel = pow(1.0 - abs(dot(normalize(local_normal), VIEW)), 1.2);
	
	// Much more aggressive holes - 55% of surface is holes
	float hole_threshold = 0.38 + fresnel * 0.15;
	if (n > hole_threshold) {
		discard;  // Transparent - shows core glow through
	}
	
	// Strong edge glow where crust meets holes — this is what bloom catches
	float edge_factor = smoothstep(hole_threshold - 0.12, hole_threshold, n);
	vec3 color = mix(crust_color, edge_glow, edge_factor);
	
	// Cool rim on the outer edge of the crust (separates planet from space)
	vec3 cool_rim = vec3(0.37, 0.57, 1.0);  // Cyan-blue
	float rim_glow = pow(fresnel, 4.0) * 0.8;
	
	// Stronger emission at wound edges so bloom catches cracks (not whole surface)
	float emission_strength = edge_factor * 2.0 + fresnel * 0.15;
	
	ALBEDO = color;
	EMISSION = edge_glow * emission_strength + cool_rim * rim_glow;
	ALPHA = 1.0;
}
"""
	return shader

# ============ PLANETARY FRAGMENTS ============

# Store animation data per fragment
var fragment_data: Array[Dictionary] = []

func create_planetary_fragments() -> void:
	# Far layer - large, slow moving silhouettes
	for i in range(8):
		var frag = create_fragment(randf_range(30.0, 60.0), true)
		var angle = (TAU / 8.0) * i + randf_range(-0.3, 0.3)
		var dist = randf_range(200.0, 350.0)
		frag.position = Vector3(
			cos(angle) * dist * 0.6,
			randf_range(-80.0, 40.0),
			-dist
		)
		frag.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		# Animation data - each fragment spins and drifts uniquely
		var data = {
			"spin_speed": Vector3(randf_range(-0.1, 0.1), randf_range(-0.15, 0.15), randf_range(-0.08, 0.08)),
			"drift_speed": Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), 0),
			"drift_offset": Vector3.ZERO,
			"drift_range": randf_range(5.0, 15.0),
			"base_pos": frag.position,
			"wobble_phase": randf() * TAU,
			"wobble_speed": randf_range(0.3, 0.8)
		}
		fragment_data.append(data)
		far_fragments.append(frag)
		add_child(frag)
	
	# Continent-scale slabs - occasional core eclipse
	for i in range(2):
		var slab = create_fragment(randf_range(80.0, 120.0), true)
		slab.position = Vector3(
			randf_range(-80.0, 80.0),  # Can cross center
			randf_range(-30.0, 10.0),
			-480.0  # Between far fragments (-400) and core (-500)
		)
		slab.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		var slab_data = {
			"spin_speed": Vector3(randf_range(-0.03, 0.03), randf_range(-0.05, 0.05), randf_range(-0.02, 0.02)),
			"drift_speed": Vector3(randf_range(-0.2, 0.2), randf_range(-0.15, 0.15), 0),
			"drift_offset": Vector3.ZERO,
			"drift_range": randf_range(60.0, 100.0),  # Wide drift for eclipse
			"base_pos": slab.position,
			"wobble_phase": randf() * TAU,
			"wobble_speed": randf_range(0.06, 0.12)  # Very slow wobble
		}
		fragment_data.append(slab_data)
		far_fragments.append(slab)
		add_child(slab)
	
	# Mid layer - medium fragments with more detail and faster motion
	for i in range(12):
		var frag = create_fragment(randf_range(10.0, 25.0), true)
		var angle = (TAU / 12.0) * i + randf_range(-0.5, 0.5)
		var dist = randf_range(80.0, 150.0)
		frag.position = Vector3(
			cos(angle) * dist,
			randf_range(-30.0, 30.0),
			-dist
		)
		frag.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		# Faster animation for closer fragments
		var data = {
			"spin_speed": Vector3(randf_range(-0.2, 0.2), randf_range(-0.25, 0.25), randf_range(-0.15, 0.15)),
			"drift_speed": Vector3(randf_range(-1.0, 1.0), randf_range(-0.8, 0.8), 0),
			"drift_offset": Vector3.ZERO,
			"drift_range": randf_range(8.0, 20.0),
			"base_pos": frag.position,
			"wobble_phase": randf() * TAU,
			"wobble_speed": randf_range(0.5, 1.2)
		}
		fragment_data.append(data)
		mid_fragments.append(frag)
		add_child(frag)

func create_fragment(size: float, has_glow: bool) -> MeshInstance3D:
	var frag = MeshInstance3D.new()
	
	# Use a box mesh distorted to look rocky
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size, size * randf_range(0.4, 0.8), size * randf_range(0.6, 1.0))
	frag.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_FRAGMENT
	mat.metallic = 0.2
	mat.roughness = 0.9
	
	if has_glow:
		mat.emission_enabled = true
		mat.emission = Color(0.06, 0.08, 0.18)  # Faint cool blue edge — silhouette, not glow
		mat.emission_energy_multiplier = 0.3
	
	frag.material_override = mat
	
	return frag

# ============ DEBRIS FIELD ============

func create_debris_field() -> void:
	# Constant small debris drifting past
	debris_particles = GPUParticles3D.new()
	debris_particles.amount = 200
	debris_particles.lifetime = 8.0
	debris_particles.preprocess = 4.0
	debris_particles.visibility_aabb = AABB(Vector3(-100, -50, -200), Vector3(200, 100, 250))
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(60.0, 30.0, 100.0)
	
	# Drift toward player (positive Z)
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 15.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	
	# Slight gravity pull toward core
	mat.gravity = Vector3(0, -0.5, -2.0)
	
	# Tumble
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	
	# Size variation
	mat.scale_min = 0.2
	mat.scale_max = 1.5
	
	# Dark color
	mat.color = Color(0.1, 0.08, 0.12)
	
	debris_particles.process_material = mat
	
	# Simple box mesh for debris
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.3, 0.4)
	debris_particles.draw_pass_1 = mesh
	
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.albedo_color = COLOR_FRAGMENT
	mesh_mat.roughness = 0.9
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(0.06, 0.08, 0.15)  # Faint cool blue edge light
	mesh_mat.emission_energy_multiplier = 0.5
	debris_particles.material_override = mesh_mat
	
	debris_particles.position = Vector3(0, 5, -80)
	add_child(debris_particles)

# ============ ATMOSPHERE PARTICLES ============

func create_atmosphere_particles() -> void:
	# Dust haze
	dust_particles = GPUParticles3D.new()
	dust_particles.amount = 100
	dust_particles.lifetime = 6.0
	dust_particles.preprocess = 3.0
	
	var dust_mat = ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(40.0, 20.0, 60.0)
	dust_mat.direction = Vector3(0.2, 0.1, 0.8)
	dust_mat.spread = 30.0
	dust_mat.initial_velocity_min = 2.0
	dust_mat.initial_velocity_max = 5.0
	dust_mat.scale_min = 0.5
	dust_mat.scale_max = 2.0
	dust_mat.color = COLOR_DUST
	
	dust_particles.process_material = dust_mat
	
	var dust_mesh = QuadMesh.new()
	dust_mesh.size = Vector2(1.0, 1.0)
	dust_particles.draw_pass_1 = dust_mesh
	
	var dust_mesh_mat = StandardMaterial3D.new()
	dust_mesh_mat.albedo_color = COLOR_DUST
	dust_mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_particles.material_override = dust_mesh_mat
	
	dust_particles.position = Vector3(0, 5, -40)
	add_child(dust_particles)
	
	# Floating embers
	ember_particles = GPUParticles3D.new()
	ember_particles.amount = 50
	ember_particles.lifetime = 4.0
	ember_particles.preprocess = 2.0
	
	var ember_mat = ParticleProcessMaterial.new()
	ember_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_mat.emission_box_extents = Vector3(30.0, 15.0, 50.0)
	ember_mat.direction = Vector3(0, 0.3, 0.7)
	ember_mat.spread = 20.0
	ember_mat.initial_velocity_min = 3.0
	ember_mat.initial_velocity_max = 8.0
	ember_mat.gravity = Vector3(0, 1.0, 0)  # Embers rise
	ember_mat.scale_min = 0.05
	ember_mat.scale_max = 0.15
	ember_mat.color = COLOR_EMBER
	
	ember_particles.process_material = ember_mat
	
	var ember_mesh = SphereMesh.new()
	ember_mesh.radius = 0.5
	ember_mesh.height = 1.0
	ember_particles.draw_pass_1 = ember_mesh
	
	var ember_mesh_mat = StandardMaterial3D.new()
	ember_mesh_mat.albedo_color = COLOR_EMBER
	ember_mesh_mat.emission_enabled = true
	ember_mesh_mat.emission = Color(1.0, 0.78, 0.29)
	ember_mesh_mat.emission_energy_multiplier = 3.0
	ember_particles.material_override = ember_mesh_mat
	
	ember_particles.position = Vector3(0, 2, -30)
	add_child(ember_particles)

# ============ WORLD ENVIRONMENT ============

func update_world_environment() -> void:
	# Find existing WorldEnvironment (from scene) or create one
	var world_env = get_tree().root.find_child("WorldEnvironment", true, false)
	if not world_env:
		world_env = get_parent().get_node_or_null("WorldEnvironment")
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		get_parent().add_child(world_env)
	
	var env = Environment.new()
	
	# Background - Void Indigo (visible navy, not crushed black)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.1, 0.24)  # Matches mid-navy tone
	
	# Ambient light - COOL, enough energy to read the scene
	# Source: Color (Sky would reference our custom shader which can cause warm bleeding)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.1, 0.2)  # Cool indigo — NO warm component
	env.ambient_light_energy = 0.5  # Enough to read track, not enough to wash
	
	# Fog - MINIMAL. Cool-only. Space doesn't have warm fog.
	env.fog_enabled = true
	env.fog_light_color = Color(0.067, 0.1, 0.23)  # Abyss Blue #111A3A — COOL fog
	env.fog_density = 0.0004  # Very low — just enough for depth, not a haze
	env.fog_sky_affect = 0.0  # Don't let fog tint the sky
	
	# Glow/Bloom - THIS is what sells "finished." Rails and cracks must bloom.
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.2
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.35  # Only truly hot emission blooms
	
	# Tonemap - ACES for filmic contrast without crushing blacks
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	
	# Color correction - NEUTRAL. No warm push. Let the palette do the work.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02  # Was 0.95 — subtle lift
	env.adjustment_contrast = 1.05  # Was 1.15 — less crushing
	env.adjustment_saturation = 1.0  # Was 0.85 — full saturation
	
	world_env.environment = env

# ============ UPDATE ============

func _process(delta: float) -> void:
	if not player:
		return
	
	var player_pos = player.global_position
	
	# Skybox follows player so we're always inside it
	if skybox:
		skybox.global_position = player_pos
	
	# Core stays infinitely distant - always ahead of player, centered
	if core_glow:
		core_glow.global_position = Vector3(0, -30, player_pos.z - 500)
		
		# Animate core pulse
		core_pulse_time += delta
		var mat = core_glow.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("time", core_pulse_time)
			mat.set_shader_parameter("pulse", sin(core_pulse_time * 0.5) * 0.5 + 0.5)
	
	# Crust follows core
	if core_crust:
		core_crust.global_position = Vector3(0, -30, player_pos.z - 500)
		var crust_mat = core_crust.material_override as ShaderMaterial
		if crust_mat:
			crust_mat.set_shader_parameter("time", core_pulse_time)
	
	# Move particle systems with player
	if debris_particles:
		debris_particles.global_position.x = player_pos.x
		debris_particles.global_position.z = player_pos.z - 80
	
	if dust_particles:
		dust_particles.global_position.x = player_pos.x
		dust_particles.global_position.z = player_pos.z - 40
	
	if ember_particles:
		ember_particles.global_position.x = player_pos.x
		ember_particles.global_position.z = player_pos.z - 30
	
	# Animate fragments with spin, drift, and gravitational wobble
	fragment_drift_time += delta
	
	# Animate far fragments
	for i in range(far_fragments.size()):
		if i >= fragment_data.size():
			continue
		
		var frag = far_fragments[i]
		var data = fragment_data[i]
		
		# Spin - constant rotation
		frag.rotation.x += data.spin_speed.x * delta
		frag.rotation.y += data.spin_speed.y * delta
		frag.rotation.z += data.spin_speed.z * delta
		
		# Wobble - sinusoidal drift simulating unstable gravity
		data.wobble_phase += data.wobble_speed * delta
		var wobble_x = sin(data.wobble_phase) * data.drift_range
		var wobble_y = cos(data.wobble_phase * 0.7) * data.drift_range * 0.5
		
		# Far fragments - very distant, spread across the sky
		frag.global_position = Vector3(
			data.base_pos.x + wobble_x,
			data.base_pos.y + wobble_y,
			player_pos.z - 400 - (i * 30)  # Spread them out in Z
		)
	
	# Animate mid fragments
	for i in range(mid_fragments.size()):
		var data_idx = far_fragments.size() + i
		if data_idx >= fragment_data.size():
			continue
		
		var frag = mid_fragments[i]
		var data = fragment_data[data_idx]
		
		# Spin
		frag.rotation.x += data.spin_speed.x * delta
		frag.rotation.y += data.spin_speed.y * delta
		frag.rotation.z += data.spin_speed.z * delta
		
		# Wobble
		data.wobble_phase += data.wobble_speed * delta
		var wobble_x = sin(data.wobble_phase) * data.drift_range
		var wobble_y = cos(data.wobble_phase * 0.7) * data.drift_range * 0.5
		
		# Mid fragments - closer, visible parallax
		frag.global_position = Vector3(
			data.base_pos.x + wobble_x,
			data.base_pos.y + wobble_y,
			player_pos.z - 150 - (i * 20)  # Spread them out in Z
		)

func reset() -> void:
	core_pulse_time = 0.0
	fragment_drift_time = 0.0
