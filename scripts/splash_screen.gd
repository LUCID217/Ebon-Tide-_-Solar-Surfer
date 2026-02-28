extends Node3D

# Tide's Fang - Startup Splash Screen
# The pirate haven built into a massive fang-shaped rock formation
# Inspired by the concept art - towering rock with teeth, buildings clinging to it
# Aesthetic: Early-2000s animated adventure (Treasure Planet / Atlantis / Sinbad)

signal splash_complete

# Timing
var splash_duration: float = 4.0
var fade_in_time: float = 1.0
var hold_time: float = 2.0
var fade_out_time: float = 1.0
var elapsed: float = 0.0

# Scene elements
var camera: Camera3D
var fang_rock: Node3D
var buildings: Array[MeshInstance3D] = []
var ships: Array[Node3D] = []
var lights: Array[OmniLight3D] = []
var water_plane: MeshInstance3D

# UI
var ui_layer: CanvasLayer
var title_label: Label
var subtitle_label: Label
var fade_rect: ColorRect

# Animation
var camera_start_pos: Vector3
var camera_end_pos: Vector3
var rock_rotation_speed: float = 0.02

# Colors - using UITheme palette (cool sky blues + ink shadows + rust accents)
var COLOR_ROCK: Color = Color("#30354A")  # Deep Slate
var COLOR_ROCK_LIGHT: Color = Color("#3B445D")  # Steel Shadow
var COLOR_TEETH: Color = Color("#E5EFEB")  # Bone Highlight
var COLOR_BUILDING: Color = Color("#553025")  # Rust Wood
var COLOR_BUILDING_LIGHT: Color = Color("#6B4030")  # Lighter rust
var COLOR_WATER: Color = Color("#0E0E14")  # Ink Black
var COLOR_SKY: Color = Color("#7B90C4")  # Sky Low
var COLOR_EMBER_DISTANT: Color = Color("#A7C8EC")  # Sky Mist (cool glow)
var COLOR_LAMP: Color = Color("#E5EFEB")  # Bone Highlight

func _ready() -> void:
	setup_environment()
	setup_camera()
	create_water()
	create_fang_rock()
	create_buildings()
	create_ships()
	create_atmosphere()
	setup_ui()
	
	# Start faded out
	fade_rect.color.a = 1.0

func _process(delta: float) -> void:
	elapsed += delta
	
	# Slow camera drift
	var t = elapsed / splash_duration
	camera.position = camera_start_pos.lerp(camera_end_pos, ease(t, 0.3))
	camera.look_at(Vector3(0, 8, 0))
	
	# Gentle rock sway (like it's breathing)
	if fang_rock:
		fang_rock.rotation.y += rock_rotation_speed * delta
	
	# Flicker the lamps
	for light in lights:
		light.light_energy = 1.5 + sin(elapsed * 3.0 + light.position.x) * 0.3
	
	# Bob the ships
	for i in range(ships.size()):
		var ship = ships[i]
		ship.position.y = -0.5 + sin(elapsed * 0.8 + i * 1.5) * 0.15
		ship.rotation.z = sin(elapsed * 0.6 + i * 2.0) * 0.05
	
	# Handle fades
	if elapsed < fade_in_time:
		# Fade in
		fade_rect.color.a = 1.0 - (elapsed / fade_in_time)
		title_label.modulate.a = elapsed / fade_in_time
		subtitle_label.modulate.a = elapsed / fade_in_time
	elif elapsed < fade_in_time + hold_time:
		# Hold
		fade_rect.color.a = 0.0
		title_label.modulate.a = 1.0
		subtitle_label.modulate.a = 1.0
	elif elapsed < splash_duration:
		# Fade out
		var fade_progress = (elapsed - fade_in_time - hold_time) / fade_out_time
		fade_rect.color.a = fade_progress
		title_label.modulate.a = 1.0 - fade_progress
		subtitle_label.modulate.a = 1.0 - fade_progress
	else:
		# Done
		emit_signal("splash_complete")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event: InputEvent) -> void:
	# Skip splash on any input
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			emit_signal("splash_complete")
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ============ ENVIRONMENT ============

func setup_environment() -> void:
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	
	# Dark twilight sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = COLOR_SKY
	
	# Moody ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.18, 0.25)
	env.ambient_light_energy = 0.4
	
	# Subtle fog for depth
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.12, 0.2)
	env.fog_density = 0.01
	
	world_env.environment = env
	add_child(world_env)
	
	# Main light - distant ember glow from Vox Ignis on horizon
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-15, -45, 0)
	sun.light_color = COLOR_EMBER_DISTANT
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	add_child(sun)
	
	# Fill light - cool moonlight
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-30, 135, 0)
	moon.light_color = Color(0.6, 0.65, 0.8)
	moon.light_energy = 0.3
	add_child(moon)

func setup_camera() -> void:
	camera = Camera3D.new()
	camera_start_pos = Vector3(15, 6, 20)
	camera_end_pos = Vector3(12, 8, 18)
	camera.position = camera_start_pos
	camera.fov = 50
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 8, 0))

# ============ WATER ============

func create_water() -> void:
	water_plane = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(200, 200)
	water_plane.mesh = mesh
	water_plane.position = Vector3(0, -1, 0)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_WATER
	mat.metallic = 0.3
	mat.roughness = 0.4
	water_plane.material_override = mat
	
	add_child(water_plane)

# ============ THE FANG ============

func create_fang_rock() -> void:
	fang_rock = Node3D.new()
	fang_rock.name = "TidesFang"
	add_child(fang_rock)
	
	# Main rock body - curved fang shape
	create_main_spire()
	
	# Secondary teeth/spires
	create_tooth(Vector3(-3, 0, 2), 6, 0.8, -15)
	create_tooth(Vector3(2.5, 0, 3), 5, 0.6, 10)
	create_tooth(Vector3(-1, 0, -2), 4, 0.5, -5)
	
	# Upper jaw teeth (the dramatic ones from concept)
	create_upper_teeth()
	
	# Base rocks in water
	create_base_rocks()

func create_main_spire() -> void:
	# Build the main fang as stacked, tapered cylinders
	var segments = 8
	var base_radius = 5.0
	var height_per_segment = 3.0
	
	for i in range(segments):
		var seg = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		
		# Taper as we go up
		var taper = 1.0 - (float(i) / segments) * 0.7
		var radius = base_radius * taper
		var next_taper = 1.0 - (float(i + 1) / segments) * 0.7
		var top_radius = base_radius * next_taper * 0.9
		
		mesh.bottom_radius = radius
		mesh.top_radius = top_radius
		mesh.height = height_per_segment
		mesh.radial_segments = 8
		
		seg.mesh = mesh
		seg.position = Vector3(0, i * height_per_segment + height_per_segment / 2, 0)
		
		# Slight random offset for organic feel
		seg.position.x += randf_range(-0.3, 0.3)
		seg.position.z += randf_range(-0.3, 0.3)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = COLOR_ROCK.lerp(COLOR_ROCK_LIGHT, float(i) / segments * 0.5)
		mat.roughness = 0.9
		seg.material_override = mat
		
		fang_rock.add_child(seg)

func create_tooth(pos: Vector3, height: float, radius: float, lean: float) -> void:
	var tooth = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.2
	mesh.height = height
	mesh.radial_segments = 6
	
	tooth.mesh = mesh
	tooth.position = pos + Vector3(0, height / 2, 0)
	tooth.rotation_degrees.x = lean
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_ROCK
	mat.roughness = 0.85
	tooth.material_override = mat
	
	fang_rock.add_child(tooth)

func create_upper_teeth() -> void:
	# The dramatic curved teeth at the top - like the concept art
	var teeth_data = [
		{"angle": -30, "height": 4, "radius": 0.6, "y": 20},
		{"angle": -15, "height": 5, "radius": 0.7, "y": 21},
		{"angle": 0, "height": 6, "radius": 0.8, "y": 22},
		{"angle": 15, "height": 5, "radius": 0.7, "y": 21},
		{"angle": 30, "height": 4, "radius": 0.5, "y": 20},
	]
	
	for data in teeth_data:
		var tooth = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.bottom_radius = data.radius
		mesh.top_radius = data.radius * 0.15
		mesh.height = data.height
		mesh.radial_segments = 6
		
		tooth.mesh = mesh
		
		# Position curving outward and down like fangs
		var angle_rad = deg_to_rad(data.angle)
		tooth.position = Vector3(sin(angle_rad) * 2, data.y, cos(angle_rad) * 0.5)
		tooth.rotation_degrees = Vector3(30, data.angle, 0)  # Curve outward
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = COLOR_TEETH
		mat.roughness = 0.7
		tooth.material_override = mat
		
		fang_rock.add_child(tooth)

func create_base_rocks() -> void:
	# Scattered rocks around the base in the water
	for i in range(12):
		var rock = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		var size = randf_range(0.5, 2.0)
		mesh.radius = size
		mesh.height = size * 1.5
		mesh.radial_segments = 6
		mesh.rings = 4
		
		rock.mesh = mesh
		
		var angle = randf() * TAU
		var dist = randf_range(8, 20)
		rock.position = Vector3(cos(angle) * dist, randf_range(-1.5, 0.5), sin(angle) * dist)
		rock.scale = Vector3(1, randf_range(0.5, 1.2), 1)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = COLOR_ROCK.darkened(randf_range(0, 0.3))
		mat.roughness = 0.9
		rock.material_override = mat
		
		add_child(rock)

# ============ BUILDINGS ============

func create_buildings() -> void:
	# Buildings clinging to the rock at various heights
	var building_configs = [
		# Lower tier - docks and warehouses
		{"y": 2, "angle": 0, "dist": 4.5, "w": 1.5, "h": 2, "d": 1.2},
		{"y": 2, "angle": 45, "dist": 4.2, "w": 1.2, "h": 1.8, "d": 1.0},
		{"y": 3, "angle": 90, "dist": 4.0, "w": 1.0, "h": 2.5, "d": 0.8},
		{"y": 2, "angle": 135, "dist": 4.3, "w": 1.4, "h": 1.5, "d": 1.1},
		{"y": 3, "angle": 180, "dist": 4.1, "w": 1.1, "h": 2.2, "d": 0.9},
		{"y": 2, "angle": 225, "dist": 4.4, "w": 1.3, "h": 1.7, "d": 1.0},
		{"y": 3, "angle": 270, "dist": 4.0, "w": 0.9, "h": 2.8, "d": 0.7},
		{"y": 2, "angle": 315, "dist": 4.2, "w": 1.2, "h": 2.0, "d": 1.0},
		
		# Middle tier
		{"y": 6, "angle": 20, "dist": 3.5, "w": 1.0, "h": 2.5, "d": 0.8},
		{"y": 7, "angle": 70, "dist": 3.2, "w": 0.9, "h": 3.0, "d": 0.7},
		{"y": 6, "angle": 120, "dist": 3.4, "w": 1.1, "h": 2.2, "d": 0.9},
		{"y": 7, "angle": 200, "dist": 3.3, "w": 0.8, "h": 2.8, "d": 0.6},
		{"y": 6, "angle": 250, "dist": 3.5, "w": 1.0, "h": 2.0, "d": 0.8},
		{"y": 7, "angle": 300, "dist": 3.2, "w": 0.9, "h": 2.5, "d": 0.7},
		
		# Upper tier - smaller, precarious
		{"y": 11, "angle": 45, "dist": 2.5, "w": 0.7, "h": 2.0, "d": 0.5},
		{"y": 12, "angle": 135, "dist": 2.3, "w": 0.6, "h": 2.5, "d": 0.4},
		{"y": 11, "angle": 225, "dist": 2.4, "w": 0.8, "h": 1.8, "d": 0.6},
		{"y": 12, "angle": 315, "dist": 2.2, "w": 0.5, "h": 2.2, "d": 0.4},
		
		# Top tier - tiny structures
		{"y": 16, "angle": 90, "dist": 1.8, "w": 0.5, "h": 1.5, "d": 0.4},
		{"y": 17, "angle": 270, "dist": 1.6, "w": 0.4, "h": 1.8, "d": 0.3},
	]
	
	for config in building_configs:
		create_building(config)

func create_building(config: Dictionary) -> void:
	var building = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(config.w, config.h, config.d)
	building.mesh = mesh
	
	var angle_rad = deg_to_rad(config.angle)
	building.position = Vector3(
		cos(angle_rad) * config.dist,
		config.y + config.h / 2,
		sin(angle_rad) * config.dist
	)
	
	# Face outward from rock
	building.rotation.y = angle_rad + PI
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_BUILDING.lerp(COLOR_BUILDING_LIGHT, randf_range(0, 0.3))
	mat.roughness = 0.85
	building.material_override = mat
	
	fang_rock.add_child(building)
	buildings.append(building)
	
	# Add a lamp to some buildings
	if randf() > 0.5:
		add_building_lamp(building, config)

func add_building_lamp(building: MeshInstance3D, config: Dictionary) -> void:
	var lamp = OmniLight3D.new()
	lamp.light_color = COLOR_LAMP
	lamp.light_energy = 1.5
	lamp.omni_range = 3.0
	lamp.omni_attenuation = 1.5
	
	# Position lamp at building front
	lamp.position = Vector3(0, config.h * 0.3, config.d * 0.6)
	building.add_child(lamp)
	lights.append(lamp)
	
	# Lamp mesh
	var lamp_mesh = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	lamp_mesh.mesh = mesh
	lamp_mesh.position = lamp.position
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_LAMP
	mat.emission_enabled = true
	mat.emission = COLOR_LAMP
	mat.emission_energy_multiplier = 3.0
	lamp_mesh.material_override = mat
	
	building.add_child(lamp_mesh)

# ============ SHIPS ============

func create_ships() -> void:
	# A few ships moored around the base
	var ship_positions = [
		{"pos": Vector3(10, -0.5, 5), "rot": -30, "scale": 1.0},
		{"pos": Vector3(-8, -0.5, 8), "rot": 45, "scale": 0.8},
		{"pos": Vector3(6, -0.5, -10), "rot": 120, "scale": 1.2},
		{"pos": Vector3(-12, -0.5, -3), "rot": -80, "scale": 0.7},
	]
	
	for config in ship_positions:
		var ship = create_simple_ship(config.scale)
		ship.position = config.pos
		ship.rotation_degrees.y = config.rot
		add_child(ship)
		ships.append(ship)

func create_simple_ship(ship_scale: float) -> Node3D:
	var ship = Node3D.new()
	
	# Hull
	var hull = MeshInstance3D.new()
	var hull_mesh = BoxMesh.new()
	hull_mesh.size = Vector3(0.8, 0.4, 2.5) * ship_scale
	hull.mesh = hull_mesh
	
	var hull_mat = StandardMaterial3D.new()
	hull_mat.albedo_color = COLOR_BUILDING.darkened(0.2)
	hull_mat.roughness = 0.8
	hull.material_override = hull_mat
	
	ship.add_child(hull)
	
	# Mast
	var mast = MeshInstance3D.new()
	var mast_mesh = CylinderMesh.new()
	mast_mesh.top_radius = 0.03 * ship_scale
	mast_mesh.bottom_radius = 0.05 * ship_scale
	mast_mesh.height = 2.0 * ship_scale
	mast.mesh = mast_mesh
	mast.position.y = 1.0 * ship_scale
	
	var mast_mat = StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.3, 0.2, 0.1)
	mast.material_override = mast_mat
	
	ship.add_child(mast)
	
	# Sail (energy sail - glowing faintly)
	var sail = MeshInstance3D.new()
	var sail_mesh = BoxMesh.new()
	sail_mesh.size = Vector3(0.05, 1.2, 0.8) * ship_scale
	sail.mesh = sail_mesh
	sail.position.y = 1.2 * ship_scale
	
	var sail_mat = StandardMaterial3D.new()
	sail_mat.albedo_color = Color(0.8, 0.85, 0.9, 0.8)
	sail_mat.emission_enabled = true
	sail_mat.emission = Color(0.7, 0.8, 0.9)
	sail_mat.emission_energy_multiplier = 0.5
	sail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sail.material_override = sail_mat
	
	ship.add_child(sail)
	
	# Ship lamp
	var lamp = OmniLight3D.new()
	lamp.light_color = COLOR_LAMP
	lamp.light_energy = 0.8
	lamp.omni_range = 2.0
	lamp.position = Vector3(0, 0.5 * ship_scale, -0.8 * ship_scale)
	ship.add_child(lamp)
	lights.append(lamp)
	
	return ship

# ============ ATMOSPHERE ============

func create_atmosphere() -> void:
	# Distant ember glow on horizon (Vox Ignis)
	var glow = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 8
	mesh.radial_segments = 16
	mesh.rings = 8
	glow.mesh = mesh
	glow.position = Vector3(-80, 5, -60)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLOR_EMBER_DISTANT
	mat.emission_enabled = true
	mat.emission = COLOR_EMBER_DISTANT
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.3
	glow.material_override = mat
	
	add_child(glow)

# ============ UI ============

func setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Fade rect - use ink black
	fade_rect = ColorRect.new()
	fade_rect.color = Color("#0E0E14")  # INK_BLACK
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(fade_rect)
	
	# Title - bone highlight with slight sky tint
	title_label = Label.new()
	title_label.text = "TIDE'S FANG"
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.offset_left = -300
	title_label.offset_right = 300
	title_label.offset_top = 50
	title_label.offset_bottom = 120
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color("#E5EFEB"))  # BONE_HIGHLIGHT
	title_label.modulate.a = 0
	ui_layer.add_child(title_label)
	
	# Subtitle - weathered grey
	subtitle_label = Label.new()
	subtitle_label.text = "Where the drowned find harbor"
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER)
	subtitle_label.offset_left = -300
	subtitle_label.offset_right = 300
	subtitle_label.offset_top = 110
	subtitle_label.offset_bottom = 150
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color("#9AA29C"))  # WEATHERED_GREY
	subtitle_label.modulate.a = 0
	ui_layer.add_child(subtitle_label)
	
	# Skip hint (bottom) - UI graphite (subtle)
	var skip_label = Label.new()
	skip_label.text = "Tap to skip"
	skip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_label.offset_left = -100
	skip_label.offset_right = 100
	skip_label.offset_top = -40
	skip_label.offset_bottom = -20
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.add_theme_font_size_override("font_size", 12)
	skip_label.add_theme_color_override("font_color", Color("#545966"))  # UI_GRAPHITE
	ui_layer.add_child(skip_label)
