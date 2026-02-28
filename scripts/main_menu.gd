extends Node3D

# Font hierarchy (see UI Font Baseline Guide)
# Display → BerkshireSwash (title only)
# UI → Cinzel Regular (buttons, menus)
const FONT_TITLE = preload("res://ui/fonts/BerkshireSwash-Regular.ttf")
const FONT_UI = preload("res://ui/fonts/Cinzel-Regular.ttf")

enum MenuState { MAIN, CREW, VESSELS, SHIPYARD, BLACK_MARKET, EXCHANGE }
var current_state: MenuState = MenuState.MAIN
var selected_index: int = 0

var camera: Camera3D
var carousel_root: Node3D
var character_meshes: Array[Node3D] = []
var vessel_meshes: Array[Node3D] = []
var current_display_items: Array[Node3D] = []

var fang_rock: Node3D
var backdrop_lights: Array[OmniLight3D] = []

var ui_layer: CanvasLayer
var ui_root: Control
var ui_backdrop: ColorRect  # Store reference to toggle visibility
var carousel_viewport: SubViewport  # Renders 3D carousel
var carousel_viewport_container: SubViewportContainer  # Displays viewport between backdrop and UI
var title_label: Label
var item_name_label: Label
var item_desc_label: Label
var coins_label: Label
var bits_label: Label
var shards_label: Label
var action_button: Button
var back_button: Button
var nav_left_button: Button
var nav_right_button: Button
var main_menu_container: VBoxContainer
var black_market_container: VBoxContainer

var target_rotation: float = 0.0
var current_rotation: float = 0.0
var elapsed_time: float = 0.0

# ============ UI COLORS - Tide's Fang Palette ============
# Aesthetic: Early-2000s animated adventure (Treasure Planet / Atlantis / Sinbad)
# Neutrals / Ink
const COLOR_INK_BLACK: Color = Color("#0E0E14")
const COLOR_DEEP_SLATE: Color = Color("#30354A")
const COLOR_STEEL_SHADOW: Color = Color("#3B445D")
const COLOR_UI_GRAPHITE: Color = Color("#545966")
# Sky / Atmosphere
const COLOR_SKY_MID: Color = Color("#8CA1D9")
const COLOR_SKY_LOW: Color = Color("#7B90C4")
const COLOR_SKY_MIST: Color = Color("#A7C8EC")
const COLOR_SKY_STEEL: Color = Color("#778BB6")
# Bone / Light
const COLOR_BONE: Color = Color("#E5EFEB")
const COLOR_WEATHERED: Color = Color("#9AA29C")
# Warm Accent (sparingly)
const COLOR_RUST: Color = Color("#553025")

# Legacy aliases for compatibility
const COLOR_SKY: Color = Color("#7B90C4")  # SKY_LOW
const COLOR_WATER: Color = Color("#0E0E14")  # INK_BLACK
const COLOR_ROCK: Color = Color("#30354A")  # DEEP_SLATE
const COLOR_EMBER: Color = Color("#A7C8EC")  # SKY_MIST (cool glow instead of orange)
const COLOR_TEXT: Color = Color("#E5EFEB")  # BONE
const COLOR_TEXT_DIM: Color = Color("#9AA29C")  # WEATHERED
const COLOR_GOLD: Color = Color("#D4A84B")  # Warm gold for currency
const COLOR_SHARD: Color = Color("#A7C8EC")  # SKY_MIST for sovereigns

const CHAR_COLORS: Dictionary = {
	"default": Color(0.2, 0.5, 0.9),       # Kane - Steel blue
	"korr": Color(0.2, 0.85, 0.75),        # Mary Korr - Bright teal
	"jubari": Color(0.3, 0.7, 0.4),        # Jubari - Sea green
	"thornveil": Color(0.7, 0.3, 0.85),    # Silas Thornveil - Vivid purple
	"kresh": Color(0.9, 0.2, 0.2),         # Vol Kresh - Crimson red
	"emissary": Color(0.1, 0.1, 0.12),     # Emissary - Near black with glow
}

# Character scale - Vol is a big boy, women are smaller
const CHAR_SCALES: Dictionary = {
	"default": 1.0,      # Kane - average
	"korr": 0.85,        # Mary - smaller
	"jubari": 1.05,      # Jubari - slightly bigger, stocky
	"thornveil": 0.95,   # Silas - lean, average
	"kresh": 1.25,       # Vol Kresh - BIG enforcer
	"emissary": 0.8,     # Emissary - small, ethereal
}

const VESSEL_COLORS: Dictionary = {
	"default": {"hull": Color(0.3, 0.28, 0.35), "sail": Color(0.5, 0.7, 1.0)},           # Fool's Hope - Blue sail
	"light_catcher": {"hull": Color(0.35, 0.32, 0.28), "sail": Color(1.0, 0.9, 0.4)},    # Gold/yellow sail
	"void_runner": {"hull": Color(0.15, 0.15, 0.2), "sail": Color(0.6, 0.3, 0.9)},       # Purple sail
	"dominion_cutter": {"hull": Color(0.25, 0.22, 0.3), "sail": Color(0.9, 0.9, 0.95)},  # White/silver sail
	"tidebreaker": {"hull": Color(0.35, 0.25, 0.18), "sail": Color(1.0, 0.5, 0.15)},     # Orange ember sail
	"harrowed_blessing": {"hull": Color(0.12, 0.1, 0.15), "sail": Color(0.3, 1.0, 0.8)}, # Ghostly cyan sail
}

# Vessel scales - some ships are bigger/smaller
const VESSEL_SCALES: Dictionary = {
	"default": 1.0,           # Fool's Hope - standard sloop
	"light_catcher": 0.85,    # Small, nimble
	"void_runner": 0.9,       # Sleek, compact
	"dominion_cutter": 1.15,  # Military vessel, bigger
	"tidebreaker": 1.1,       # Sturdy vessel
	"harrowed_blessing": 1.2, # Impressive blessed ship
}

var crew_ids: Array = []
var vessel_ids: Array = []

func _ready() -> void:
	create_backdrop()
	setup_environment()
	setup_carousel_viewport()  # Creates viewport with camera, lights, carousel_root
	create_all_meshes()
	setup_ui()
	show_main_menu()
	
	# Start music on menu load
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_music()
	
	print("Menu ready!")

func _process(delta: float) -> void:
	elapsed_time += delta
	current_rotation = lerp(current_rotation, target_rotation, delta * 6.0)
	if carousel_root:
		carousel_root.rotation.y = current_rotation
	for i in range(current_display_items.size()):
		var item = current_display_items[i]
		if item and is_instance_valid(item) and item.visible:
			item.position.y = sin(elapsed_time * 2.0 + i * 0.8) * 0.1
	# fang_rock and backdrop_lights are reserved for future use by create_backdrop()

	
	# Animate black market objects
	animate_black_market_objects()

func animate_black_market_objects() -> void:
	for child in carousel_root.get_children():
		if child.name == "TestLookingGlass" and child.visible:
			# Lazy orbit of the whole spyglass
			var spyglass = child.get_node_or_null("Spyglass")
			if spyglass:
				spyglass.rotation_degrees.y = elapsed_time * 15
				spyglass.rotation_degrees.x = sin(elapsed_time * 0.4) * 10
				spyglass.rotation_degrees.z = cos(elapsed_time * 0.3) * 8
			
			# Animate coins
			var coins_holder = child.get_node_or_null("CoinsHolder")
			if coins_holder:
				for i in range(coins_holder.get_child_count()):
					var coin = coins_holder.get_child(i)
					var base_y = 0.3 + i * 0.2
					coin.position.y = base_y + sin(elapsed_time * 2.5 + i * 1.2) * 0.08
					coin.rotation.y = elapsed_time * 2.0 + i * 0.8
		
		if child.name == "TestWheel" and child.visible:
			child.rotation.y = sin(elapsed_time * 0.3) * 0.1
		
		if child.name == "TestSack" and child.visible:
			# Lazy orbit of the sack
			var sack = child.get_node_or_null("Sack")
			if sack:
				sack.rotation_degrees.y = elapsed_time * 12
				sack.rotation_degrees.x = sin(elapsed_time * 0.5) * 5
				sack.rotation_degrees.z = cos(elapsed_time * 0.4) * 4
			
			# Animate bits - uniform floating pizza slices
			var bits_holder = child.get_node_or_null("BitsHolder")
			if bits_holder:
				for i in range(bits_holder.get_child_count()):
					var bit = bits_holder.get_child(i)
					# All at same base height, gentle unified bob
					bit.position.y = 0.35 + sin(elapsed_time * 1.5 + i * 0.5) * 0.08
					# Slow spin around the sack
					var angle = i * (TAU / 6) + elapsed_time * 0.3
					bit.position.x = cos(angle) * 0.6
					bit.position.z = sin(angle) * 0.6
					bit.rotation_degrees.y = rad_to_deg(angle) + 90
		
		if child.name == "TestChest" and child.visible:
			# Lazy orbit of the chest
			var chest_node = child.get_node_or_null("Chest")
			if chest_node:
				chest_node.rotation_degrees.y = elapsed_time * 10
				chest_node.rotation_degrees.x = sin(elapsed_time * 0.4) * 4
				chest_node.rotation_degrees.z = cos(elapsed_time * 0.35) * 3
			
			# Animate sovereigns - orbit around chest
			var sovereigns_holder = child.get_node_or_null("SovereignsHolder")
			if sovereigns_holder:
				for i in range(sovereigns_holder.get_child_count()):
					var coin = sovereigns_holder.get_child(i)
					coin.position.y = 0.35 + sin(elapsed_time * 1.5 + i * 0.5) * 0.06
					var angle = i * (TAU / 6) + elapsed_time * 0.25
					coin.position.x = cos(angle) * 0.7
					coin.position.z = sin(angle) * 0.7
					coin.rotation.y = elapsed_time * 1.5 + i * 0.5
		
		if child.name == "TestSkull" and child.visible:
			# Slower, more ominous lazy orbit
			var skull_node = child.get_node_or_null("SkullAssembly")
			if skull_node:
				skull_node.rotation_degrees.y = elapsed_time * 8
				skull_node.rotation_degrees.x = sin(elapsed_time * 0.3) * 3
				skull_node.rotation_degrees.z = cos(elapsed_time * 0.25) * 2
		
		# === BLACK MARKET ITEMS ===
		if child.name == "BMWheel" and child.visible:
			child.rotation.y = sin(elapsed_time * 0.3) * 0.1
		
		if child.name == "BMLookingGlass" and child.visible:
			var spyglass = child.get_node_or_null("Spyglass")
			if spyglass:
				spyglass.rotation_degrees.y = elapsed_time * 15
				spyglass.rotation_degrees.x = sin(elapsed_time * 0.4) * 10
				spyglass.rotation_degrees.z = cos(elapsed_time * 0.3) * 8
			var coins_holder = child.get_node_or_null("CoinsHolder")
			if coins_holder:
				for i in range(coins_holder.get_child_count()):
					var coin = coins_holder.get_child(i)
					var base_y = 0.3 + i * 0.2
					coin.position.y = base_y + sin(elapsed_time * 2.5 + i * 1.2) * 0.08
					coin.rotation.y = elapsed_time * 2.0 + i * 0.8
		
		if child.name == "BMSack" and child.visible:
			var sack = child.get_node_or_null("Sack")
			if sack:
				sack.rotation_degrees.y = elapsed_time * 12
				sack.rotation_degrees.x = sin(elapsed_time * 0.5) * 5
				sack.rotation_degrees.z = cos(elapsed_time * 0.4) * 4
			var bits_holder = child.get_node_or_null("BitsHolder")
			if bits_holder:
				for i in range(bits_holder.get_child_count()):
					var bit = bits_holder.get_child(i)
					bit.position.y = 0.35 + sin(elapsed_time * 1.5 + i * 0.5) * 0.08
					var angle = i * (TAU / 6) + elapsed_time * 0.3
					bit.position.x = cos(angle) * 0.6
					bit.position.z = sin(angle) * 0.6
					bit.rotation_degrees.y = rad_to_deg(angle) + 90
		
		if child.name == "BMChest" and child.visible:
			var chest_node = child.get_node_or_null("Chest")
			if chest_node:
				chest_node.rotation_degrees.y = elapsed_time * 10
				chest_node.rotation_degrees.x = sin(elapsed_time * 0.4) * 4
				chest_node.rotation_degrees.z = cos(elapsed_time * 0.35) * 3
			var sovereigns_holder = child.get_node_or_null("SovereignsHolder")
			if sovereigns_holder:
				for i in range(sovereigns_holder.get_child_count()):
					var coin = sovereigns_holder.get_child(i)
					coin.position.y = 0.35 + sin(elapsed_time * 1.5 + i * 0.5) * 0.06
					var angle = i * (TAU / 6) + elapsed_time * 0.25
					coin.position.x = cos(angle) * 0.7
					coin.position.z = sin(angle) * 0.7
					coin.rotation.y = elapsed_time * 1.5 + i * 0.5
		
		if child.name == "BMSkull" and child.visible:
			var skull_node = child.get_node_or_null("SkullAssembly")
			if skull_node:
				skull_node.rotation_degrees.y = elapsed_time * 8
				skull_node.rotation_degrees.x = sin(elapsed_time * 0.3) * 3
		
		# === EXCHANGE ITEMS ===
		if child.name == "EXMarks" and child.visible:
			var marks_node = child.get_node_or_null("MarksAssembly")
			if marks_node:
				marks_node.rotation_degrees.y = elapsed_time * 15
				marks_node.rotation_degrees.x = sin(elapsed_time * 0.4) * 5
		
		if child.name == "EXBits" and child.visible:
			var bits_node = child.get_node_or_null("BitsAssembly")
			if bits_node:
				bits_node.rotation_degrees.y = elapsed_time * 12
				bits_node.rotation_degrees.x = sin(elapsed_time * 0.5) * 6
		
		if child.name == "EXSovereigns" and child.visible:
			var sovs_node = child.get_node_or_null("SovereignsAssembly")
			if sovs_node:
				sovs_node.rotation_degrees.y = elapsed_time * 10
				sovs_node.rotation_degrees.z = sin(elapsed_time * 0.3) * 8

func _unhandled_input(event: InputEvent) -> void:
	# Use _unhandled_input so UI gets first chance
	if current_state == MenuState.MAIN:
		return
	
	# Keyboard navigation
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			navigate(-1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			navigate(1)
		elif event.keycode == KEY_ESCAPE:
			_on_back_pressed()
	
	# Touch swipe navigation for carousel
	if event is InputEventScreenTouch:
		if event.pressed:
			menu_touch_start = event.position
			menu_touch_id = event.index
		elif event.index == menu_touch_id:
			var swipe_delta = event.position - menu_touch_start
			# Horizontal swipe detection
			if abs(swipe_delta.x) > 60.0 and abs(swipe_delta.x) > abs(swipe_delta.y) * 1.5:
				if swipe_delta.x < 0:
					navigate(1)  # Swipe left = next item
				else:
					navigate(-1)  # Swipe right = previous item
			menu_touch_id = -1

# Touch tracking for menu
var menu_touch_start: Vector2 = Vector2.ZERO
var menu_touch_id: int = -1

func create_backdrop() -> void:
	# No 3D backdrop - using Vespera Pop dark theme
	pass

func setup_environment() -> void:
	# Environment goes inside the SubViewport - set up in setup_carousel_viewport
	pass

func setup_carousel_viewport() -> void:
	# Create SubViewport for 3D carousel rendering
	carousel_viewport = SubViewport.new()
	carousel_viewport.transparent_bg = true  # Critical: let backdrop show through
	carousel_viewport.size = Vector2i(1280, 720)
	carousel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create WorldEnvironment inside viewport
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)  # Transparent
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#EAF2FF")
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.2
	we.environment = env
	carousel_viewport.add_child(we)
	
	# Camera inside viewport
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.5, 6)
	camera.rotation_degrees = Vector3(-5, 0, 0)
	camera.fov = 50
	camera.current = true
	carousel_viewport.add_child(camera)
	
	# Lights inside viewport
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_color = Color("#2EF2D0")
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	carousel_viewport.add_child(sun)
	
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color("#FF7A2A")
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	carousel_viewport.add_child(fill)
	
	var bottom_fill = DirectionalLight3D.new()
	bottom_fill.rotation_degrees = Vector3(60, 0, 0)
	bottom_fill.light_color = Color("#A66BFF")
	bottom_fill.light_energy = 0.3
	bottom_fill.shadow_enabled = false
	carousel_viewport.add_child(bottom_fill)
	
	# Carousel root inside viewport
	carousel_root = Node3D.new()
	carousel_root.position = Vector3(0, 0, -3.0)
	carousel_viewport.add_child(carousel_root)
	
	# Add viewport to scene tree (will be reparented to container in setup_ui)
	add_child(carousel_viewport)


func setup_camera() -> void:
	# Camera is now created inside setup_carousel_viewport
	pass

func setup_carousel() -> void:
	# Carousel root is now created inside setup_carousel_viewport — this function is dead code
	pass

func create_all_meshes() -> void:
	crew_ids = GameData.RIDERS.keys()
	vessel_ids = GameData.BOARDS.keys()
	print("Crew IDs: ", crew_ids)
	print("Vessel IDs: ", vessel_ids)
	for id in crew_ids:
		var cm = create_character_mesh(id)
		cm.visible = false
		carousel_root.add_child(cm)
		character_meshes.append(cm)
	for id in vessel_ids:
		var vm = create_vessel_mesh(id)
		vm.visible = false
		carousel_root.add_child(vm)
		vessel_meshes.append(vm)

func create_character_mesh(id: String) -> Node3D:
	var root = Node3D.new()
	root.name = id
	var color = CHAR_COLORS.get(id, Color(0.5, 0.5, 0.6))
	var char_scale = CHAR_SCALES.get(id, 1.0)
	print("Creating character ", id, " with color ", color, " scale ", char_scale)
	
	# Special case for Emissary - dark with glowing accents
	var is_emissary = (id == "emissary")
	var glow_color = Color(0.4, 0.9, 0.7) if is_emissary else color
	var emission_strength = 3.0 if is_emissary else 0.5
	
	# Try to load 3D model
	var rider_scene = load("res://models/rider_base.glb")
	if rider_scene:
		var model = rider_scene.instantiate()
		# Model is 1.8 units tall. Menu primitives had head at ~1.4 * scale.
		# Scale the model to match: (1.4 / 1.8) * char_scale ≈ 0.78 * char_scale
		var model_scale = 0.78 * char_scale
		model.scale = Vector3(model_scale, model_scale, model_scale)
		model.position.y = 0.0
		model.rotation_degrees.y = 180.0
		
		# Apply character-specific material
		var mat = StandardMaterial3D.new()
		if is_emissary:
			mat.albedo_color = Color(0.08, 0.08, 0.1)
		else:
			mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = glow_color * 0.4
		mat.emission_energy_multiplier = emission_strength
		mat.roughness = 0.6
		mat.metallic = 0.2
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive_menu(model, mat)
		root.add_child(model)
	else:
		# Fallback: original capsule placeholder
		var body = MeshInstance3D.new()
		var bm = CapsuleMesh.new()
		bm.radius = 0.28 * char_scale
		bm.height = 1.0 * char_scale
		body.mesh = bm
		body.position.y = 0.7 * char_scale
		var bmat = StandardMaterial3D.new()
		bmat.albedo_color = color
		bmat.emission_enabled = true
		bmat.emission = color * 0.4
		bmat.emission_energy_multiplier = emission_strength
		body.material_override = bmat
		root.add_child(body)
	
	# Platform (always present)
	var plat = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.5 * char_scale
	pm.bottom_radius = 0.6 * char_scale
	pm.height = 0.12
	plat.mesh = pm
	plat.position.y = -0.18
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	return root

func _apply_material_recursive_menu(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursive_menu(child, material)

func create_vessel_mesh(id: String) -> Node3D:
	var root = Node3D.new()
	root.name = id
	var vc = VESSEL_COLORS.get(id, {"hull": Color(0.3, 0.25, 0.2), "sail": Color(1.0, 0.5, 0.2)})
	var v_scale = VESSEL_SCALES.get(id, 1.0)
	print("Creating vessel ", id, " with colors ", vc, " scale ", v_scale)
	
	# Map vessel IDs to GLB model paths (add more as models are created)
	var vessel_models: Dictionary = {
		"default": "res://models/vessel_default.glb",
	}
	
	var model_path = vessel_models.get(id, "")
	var vessel_scene = load(model_path) if model_path != "" else null
	
	if vessel_scene:
		var model = vessel_scene.instantiate()
		# Vessel model is ~2.5 units long. Scale to match menu display.
		# Menu primitives had hull at 1.6 * v_scale, so scale model to fit similarly
		var model_scale = 1.5 * v_scale
		model.scale = Vector3(model_scale, model_scale, model_scale)
		model.position.y = 1.2 * v_scale
		# Face camera in menu (180 degrees)
		model.rotation_degrees.y = 220.0
		
		# Apply vessel-colored material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = vc.hull
		mat.metallic = 0.3
		mat.roughness = 0.6
		mat.emission_enabled = true
		mat.emission = vc.sail * 0.3
		mat.emission_energy_multiplier = 1.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive_menu(model, mat)
		root.add_child(model)
	else:
		# Fallback: procedural vessel for models not yet created
		var hull = MeshInstance3D.new()
		var hm = BoxMesh.new()
		hm.size = Vector3(0.6, 0.25, 1.6) * v_scale
		hull.mesh = hm
		hull.position.y = 0.15 * v_scale
		var hmat = StandardMaterial3D.new()
		hmat.albedo_color = vc.hull
		hmat.metallic = 0.3
		hmat.roughness = 0.6
		hull.material_override = hmat
		root.add_child(hull)
		
		var mast = MeshInstance3D.new()
		var mm = CylinderMesh.new()
		mm.top_radius = 0.03 * v_scale
		mm.bottom_radius = 0.05 * v_scale
		mm.height = 1.2 * v_scale
		mast.mesh = mm
		mast.position.y = 0.75 * v_scale
		var mmat = StandardMaterial3D.new()
		mmat.albedo_color = Color(0.35, 0.25, 0.18)
		mast.material_override = mmat
		root.add_child(mast)
		
		var sail_node = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(0.05, 0.85, 0.6) * v_scale
		sail_node.mesh = sm
		sail_node.position.y = 0.85 * v_scale
		var smat = StandardMaterial3D.new()
		smat.albedo_color = vc.sail
		smat.emission_enabled = true
		smat.emission = vc.sail
		smat.emission_energy_multiplier = 3.0
		sail_node.material_override = smat
		root.add_child(sail_node)
		
		var eng = MeshInstance3D.new()
		var em_mesh = SphereMesh.new()
		em_mesh.radius = 0.15 * v_scale
		eng.mesh = em_mesh
		eng.position = Vector3(0, 0.12 * v_scale, -0.85 * v_scale)
		var emat = StandardMaterial3D.new()
		emat.albedo_color = vc.sail
		emat.emission_enabled = true
		emat.emission = vc.sail
		emat.emission_energy_multiplier = 4.0
		eng.material_override = emat
		root.add_child(eng)
	
	# Platform (always present)
	var plat = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.6 * v_scale
	pm.bottom_radius = 0.7 * v_scale
	pm.height = 0.1
	plat.mesh = pm
	plat.position.y = -0.12
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	return root

# ============ BLACK MARKET 3D OBJECTS ============

func create_wheel_of_fortune() -> Node3D:
	var root = Node3D.new()
	root.name = "wheel_of_fortune"
	
	# Colors
	var wood_color = Color(0.4, 0.28, 0.18)
	var wood_dark = Color(0.25, 0.18, 0.12)
	var gold_color = Color(0.9, 0.75, 0.3)
	var red_color = Color(0.8, 0.2, 0.15)
	var segment_colors = [
		Color(0.8, 0.2, 0.15),   # Red
		Color(0.9, 0.75, 0.2),   # Gold
		Color(0.2, 0.5, 0.8),    # Blue
		Color(0.9, 0.75, 0.2),   # Gold
		Color(0.15, 0.6, 0.3),   # Green
		Color(0.9, 0.75, 0.2),   # Gold
		Color(0.7, 0.3, 0.7),    # Purple
		Color(0.9, 0.75, 0.2),   # Gold
	]
	
	# Stand - two wooden legs
	for x in [-0.3, 0.3]:
		var leg = MeshInstance3D.new()
		var lm = BoxMesh.new()
		lm.size = Vector3(0.12, 1.2, 0.12)
		leg.mesh = lm
		leg.position = Vector3(x, 0.4, 0)
		leg.rotation_degrees.z = -x * 20  # Angle outward
		var lmat = StandardMaterial3D.new()
		lmat.albedo_color = wood_dark
		lmat.roughness = 0.8
		leg.material_override = lmat
		root.add_child(leg)
	
	# Cross brace
	var brace = MeshInstance3D.new()
	var brm = BoxMesh.new()
	brm.size = Vector3(0.5, 0.08, 0.08)
	brace.mesh = brm
	brace.position = Vector3(0, 0.3, 0)
	var brmat = StandardMaterial3D.new()
	brmat.albedo_color = wood_dark
	brace.material_override = brmat
	root.add_child(brace)
	
	# Wheel hub (center)
	var hub = MeshInstance3D.new()
	var hubm = CylinderMesh.new()
	hubm.top_radius = 0.15
	hubm.bottom_radius = 0.15
	hubm.height = 0.1
	hub.mesh = hubm
	hub.position = Vector3(0, 0.9, 0.08)
	hub.rotation_degrees.x = 90
	var hubmat = StandardMaterial3D.new()
	hubmat.albedo_color = gold_color
	hubmat.metallic = 0.7
	hubmat.roughness = 0.3
	hub.material_override = hubmat
	root.add_child(hub)
	
	# Wheel rim (outer ring)
	var rim = MeshInstance3D.new()
	var rimm = TorusMesh.new()
	rimm.inner_radius = 0.55
	rimm.outer_radius = 0.65
	rimm.rings = 24
	rimm.ring_segments = 12
	rim.mesh = rimm
	rim.position = Vector3(0, 0.9, 0.05)
	rim.rotation_degrees.x = 90
	var rimmat = StandardMaterial3D.new()
	rimmat.albedo_color = wood_color
	rimmat.roughness = 0.7
	rim.material_override = rimmat
	root.add_child(rim)
	
	# Wheel segments (pie slices)
	var num_segments = 8
	for i in range(num_segments):
		var segment = MeshInstance3D.new()
		var segm = CylinderMesh.new()
		segm.top_radius = 0.55
		segm.bottom_radius = 0.55
		segm.height = 0.05
		segm.radial_segments = 3  # Triangle-ish
		segment.mesh = segm
		segment.position = Vector3(0, 0.9, 0.05)
		segment.rotation_degrees.x = 90
		segment.rotation_degrees.z = i * (360.0 / num_segments)
		var segmat = StandardMaterial3D.new()
		segmat.albedo_color = segment_colors[i]
		segmat.emission_enabled = true
		segmat.emission = segment_colors[i] * 0.3
		segmat.emission_energy_multiplier = 0.5
		segment.material_override = segmat
		root.add_child(segment)
	
	# Wheel face (flat disc behind segments)
	var face = MeshInstance3D.new()
	var facem = CylinderMesh.new()
	facem.top_radius = 0.54
	facem.bottom_radius = 0.54
	facem.height = 0.03
	face.mesh = facem
	face.position = Vector3(0, 0.9, 0.02)
	face.rotation_degrees.x = 90
	var facemat = StandardMaterial3D.new()
	facemat.albedo_color = Color(0.15, 0.12, 0.1)
	face.material_override = facemat
	root.add_child(face)
	
	# Spokes
	for i in range(8):
		var spoke = MeshInstance3D.new()
		var spokm = BoxMesh.new()
		spokm.size = Vector3(0.03, 0.45, 0.04)
		spoke.mesh = spokm
		spoke.position = Vector3(0, 0.9, 0.06)
		spoke.rotation_degrees.z = i * 45
		var spokmat = StandardMaterial3D.new()
		spokmat.albedo_color = gold_color
		spokmat.metallic = 0.6
		spoke.material_override = spokmat
		root.add_child(spoke)
	
	# Pointer (top, pointing down at wheel)
	var pointer = MeshInstance3D.new()
	var ptrm = PrismMesh.new()
	ptrm.size = Vector3(0.15, 0.2, 0.08)
	pointer.mesh = ptrm
	pointer.position = Vector3(0, 1.55, 0.1)
	pointer.rotation_degrees.z = 180  # Point down
	var ptrmat = StandardMaterial3D.new()
	ptrmat.albedo_color = red_color
	ptrmat.emission_enabled = true
	ptrmat.emission = red_color
	ptrmat.emission_energy_multiplier = 1.0
	pointer.material_override = ptrmat
	root.add_child(pointer)
	
	# Pointer mount
	var pmount = MeshInstance3D.new()
	var pmm = BoxMesh.new()
	pmm.size = Vector3(0.2, 0.1, 0.1)
	pmount.mesh = pmm
	pmount.position = Vector3(0, 1.6, 0.05)
	var pmmat = StandardMaterial3D.new()
	pmmat.albedo_color = wood_dark
	pmount.material_override = pmmat
	root.add_child(pmount)
	
	# Platform base
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.5
	platm.bottom_radius = 0.6
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.18
	var platmat = StandardMaterial3D.new()
	platmat.albedo_color = Color(0.15, 0.12, 0.18)
	platmat.metallic = 0.6
	plat.material_override = platmat
	root.add_child(plat)
	
	return root

func create_looking_glass_coins() -> Node3D:
	var root = Node3D.new()
	root.name = "looking_glass_coins"
	
	# Colors
	var gold_color = Color(0.95, 0.8, 0.3)
	var glass_color = Color(0.4, 0.7, 0.9)  # Blue-ish glass
	
	# Spyglass holder - everything attached rotates together
	var spyglass = Node3D.new()
	spyglass.name = "Spyglass"
	spyglass.position = Vector3(0, 0.6, 0)
	root.add_child(spyglass)
	
	# Materials
	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.95, 0.75, 0.3)  # BRIGHT golden brass
	brass_mat.metallic = 0.95
	brass_mat.roughness = 0.1
	brass_mat.emission_enabled = true
	brass_mat.emission = Color(0.9, 0.7, 0.2)
	brass_mat.emission_energy_multiplier = 0.3  # Subtle glow
	
	var brown_mat = StandardMaterial3D.new()
	brown_mat.albedo_color = Color(0.2, 0.12, 0.06)  # VERY dark leather
	brown_mat.roughness = 0.95
	brown_mat.metallic = 0.0
	
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = gold_color
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.1
	
	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(glass_color.r, glass_color.g, glass_color.b, 0.4)
	glass_mat.metallic = 0.2
	glass_mat.roughness = 0.0
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = glass_color
	glass_mat.emission_energy_multiplier = 0.6
	
	# === BIG END (objective) - from z = -0.55 ===
	
	# Convex glass lens (big end) - bulging outward
	var big_lens = MeshInstance3D.new()
	var blm = SphereMesh.new()
	blm.radius = 0.18
	blm.height = 0.18  # Half sphere for convex
	big_lens.mesh = blm
	big_lens.rotation_degrees.x = 90
	big_lens.position.z = -0.58
	big_lens.material_override = glass_mat
	spyglass.add_child(big_lens)
	
	# Gold end cap ring (big end)
	var big_cap = MeshInstance3D.new()
	var bcm = TorusMesh.new()
	bcm.inner_radius = 0.16
	bcm.outer_radius = 0.22
	big_cap.mesh = bcm
	big_cap.rotation_degrees.x = 90
	big_cap.position.z = -0.54
	big_cap.material_override = gold_mat
	spyglass.add_child(big_cap)
	
	# BROWN outer band (big end)
	var outer_band = MeshInstance3D.new()
	var obm = CylinderMesh.new()
	obm.top_radius = 0.20
	obm.bottom_radius = 0.18
	obm.height = 0.12
	outer_band.mesh = obm
	outer_band.rotation_degrees.x = 90
	outer_band.position.z = -0.46
	outer_band.material_override = brown_mat
	spyglass.add_child(outer_band)
	
	# BRASS inner tube (big section)
	var brass_tube1 = MeshInstance3D.new()
	var bt1m = CylinderMesh.new()
	bt1m.top_radius = 0.16
	bt1m.bottom_radius = 0.14
	bt1m.height = 0.22
	brass_tube1.mesh = bt1m
	brass_tube1.rotation_degrees.x = 90
	brass_tube1.position.z = -0.28
	brass_tube1.material_override = brass_mat
	spyglass.add_child(brass_tube1)
	
	# BROWN middle band (leather grip)
	var middle_band = MeshInstance3D.new()
	var mbm = CylinderMesh.new()
	mbm.top_radius = 0.15
	mbm.bottom_radius = 0.15
	mbm.height = 0.18
	middle_band.mesh = mbm
	middle_band.rotation_degrees.x = 90
	middle_band.position.z = -0.08
	middle_band.material_override = brown_mat
	spyglass.add_child(middle_band)
	
	# BRASS inner tube (small section)
	var brass_tube2 = MeshInstance3D.new()
	var bt2m = CylinderMesh.new()
	bt2m.top_radius = 0.12
	bt2m.bottom_radius = 0.10
	bt2m.height = 0.18
	brass_tube2.mesh = bt2m
	brass_tube2.rotation_degrees.x = 90
	brass_tube2.position.z = 0.1
	brass_tube2.material_override = brass_mat
	spyglass.add_child(brass_tube2)
	
	# BROWN lower band (small end)
	var lower_band = MeshInstance3D.new()
	var lbm = CylinderMesh.new()
	lbm.top_radius = 0.11
	lbm.bottom_radius = 0.10
	lbm.height = 0.1
	lower_band.mesh = lbm
	lower_band.rotation_degrees.x = 90
	lower_band.position.z = 0.24
	lower_band.material_override = brown_mat
	spyglass.add_child(lower_band)
	
	# === SMALL END (eyepiece) ===
	
	# Gold end cap ring (small end)
	var small_cap = MeshInstance3D.new()
	var scm = TorusMesh.new()
	scm.inner_radius = 0.07
	scm.outer_radius = 0.11
	small_cap.mesh = scm
	small_cap.rotation_degrees.x = 90
	small_cap.position.z = 0.32
	small_cap.material_override = gold_mat
	spyglass.add_child(small_cap)
	
	# Flat glass lens (small end)
	var small_lens = MeshInstance3D.new()
	var slm = CylinderMesh.new()
	slm.top_radius = 0.07
	slm.bottom_radius = 0.07
	slm.height = 0.015
	small_lens.mesh = slm
	small_lens.rotation_degrees.x = 90
	small_lens.position.z = 0.33
	small_lens.material_override = glass_mat
	spyglass.add_child(small_lens)
	
	# Floating coins - separate from spyglass, orbit OUTSIDE of it
	var coins_holder = Node3D.new()
	coins_holder.name = "CoinsHolder"
	root.add_child(coins_holder)
	
	for i in range(4):
		var coin = MeshInstance3D.new()
		coin.name = "Coin" + str(i)
		var cm = CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.1
		cm.height = 0.025
		coin.mesh = cm
		var angle = i * (TAU / 4)
		coin.position = Vector3(cos(angle) * 0.85, 0.3 + i * 0.2, sin(angle) * 0.85)
		coin.rotation_degrees.x = 90
		var cmat = StandardMaterial3D.new()
		cmat.albedo_color = gold_color
		cmat.metallic = 0.95
		cmat.roughness = 0.15
		cmat.emission_enabled = true
		cmat.emission = gold_color
		cmat.emission_energy_multiplier = 1.2
		coin.material_override = cmat
		coins_holder.add_child(coin)
	
	# Platform base
	var plat = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.6
	pm.height = 0.12
	plat.mesh = pm
	plat.position.y = -0.18
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root

func create_sack_of_bits() -> Node3D:
	var root = Node3D.new()
	root.name = "sack_of_bits"
	
	# Colors
	var canvas_color = Color(0.55, 0.45, 0.3)  # Weathered canvas
	var rope_color = Color(0.4, 0.32, 0.2)     # Hemp rope
	var bit_color = Color(0.85, 0.7, 0.35)     # Golden bits
	
	# Sack holder for lazy orbit
	var sack = Node3D.new()
	sack.name = "Sack"
	sack.position = Vector3(0, 0.3, 0)
	root.add_child(sack)
	
	# Materials
	var canvas_mat = StandardMaterial3D.new()
	canvas_mat.albedo_color = canvas_color
	canvas_mat.roughness = 0.95
	canvas_mat.metallic = 0.0
	
	var rope_mat = StandardMaterial3D.new()
	rope_mat.albedo_color = rope_color
	rope_mat.roughness = 0.9
	rope_mat.metallic = 0.0
	
	var bit_mat = StandardMaterial3D.new()
	bit_mat.albedo_color = bit_color
	bit_mat.metallic = 0.85
	bit_mat.roughness = 0.2
	bit_mat.emission_enabled = true
	bit_mat.emission = bit_color
	bit_mat.emission_energy_multiplier = 0.5
	
	# Main sack body - round bulging bottom (Robin Hood style)
	var body = MeshInstance3D.new()
	var bm = SphereMesh.new()
	bm.radius = 0.32
	bm.height = 0.6  # Rounder, not squashed
	body.mesh = bm
	body.position.y = 0.0
	body.material_override = canvas_mat
	sack.add_child(body)
	
	# Upper bulge (where contents push up)
	var bulge = MeshInstance3D.new()
	var bulgem = SphereMesh.new()
	bulgem.radius = 0.25
	bulgem.height = 0.35
	bulge.mesh = bulgem
	bulge.position.y = 0.22
	bulge.material_override = canvas_mat
	sack.add_child(bulge)
	
	# Gathered neck (cinched part)
	var neck = MeshInstance3D.new()
	var nm = CylinderMesh.new()
	nm.top_radius = 0.06
	nm.bottom_radius = 0.15
	nm.height = 0.18
	neck.mesh = nm
	neck.position.y = 0.42
	neck.material_override = canvas_mat
	sack.add_child(neck)
	
	# Floppy top (fabric above the tie)
	var flop = MeshInstance3D.new()
	var fm = CylinderMesh.new()
	fm.top_radius = 0.1
	fm.bottom_radius = 0.06
	fm.height = 0.12
	flop.mesh = fm
	flop.position.y = 0.54
	flop.rotation_degrees.z = 15  # Slightly tilted
	flop.material_override = canvas_mat
	sack.add_child(flop)
	
	# Rope tie around neck
	var rope = MeshInstance3D.new()
	var rm = TorusMesh.new()
	rm.inner_radius = 0.06
	rm.outer_radius = 0.1
	rope.mesh = rm
	rope.position.y = 0.42
	rope.rotation_degrees.x = 90
	rope.material_override = rope_mat
	sack.add_child(rope)
	
	# Rope knot
	var knot = MeshInstance3D.new()
	var km = SphereMesh.new()
	km.radius = 0.05
	knot.mesh = km
	knot.position = Vector3(0.1, 0.42, 0)
	knot.material_override = rope_mat
	sack.add_child(knot)
	
	# Rope tails hanging
	for i in range(2):
		var tail = MeshInstance3D.new()
		var tm = CylinderMesh.new()
		tm.top_radius = 0.015
		tm.bottom_radius = 0.01
		tm.height = 0.12
		tail.mesh = tm
		tail.position = Vector3(0.1 + i * 0.03, 0.36, i * 0.02)
		tail.rotation_degrees.z = 25 + i * 15
		tail.rotation_degrees.x = i * 20
		tail.material_override = rope_mat
		sack.add_child(tail)
	
	# Floating bits - 6 golden pizza slices (triangular wedges)
	var bits_holder = Node3D.new()
	bits_holder.name = "BitsHolder"
	root.add_child(bits_holder)
	
	for i in range(6):  # 6 bits for pieces of six!
		var bit = MeshInstance3D.new()
		bit.name = "Bit" + str(i)
		
		# Pizza slice shape - use prism (triangular)
		var pm = PrismMesh.new()
		pm.size = Vector3(0.12, 0.03, 0.18)  # Flat triangular slice
		bit.mesh = pm
		
		var angle = i * (TAU / 6)
		var radius = 0.6
		bit.position = Vector3(cos(angle) * radius, 0.35, sin(angle) * radius)
		# Point the slices outward like a pizza being divided
		bit.rotation_degrees.y = rad_to_deg(angle) + 90
		bit.rotation_degrees.x = 90  # Lay flat-ish
		bit.material_override = bit_mat
		bits_holder.add_child(bit)
	
	# Platform base
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.5
	platm.bottom_radius = 0.6
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.45
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root

func create_chest_of_sovereigns() -> Node3D:
	var root = Node3D.new()
	root.name = "chest_of_sovereigns"
	
	# Colors
	var wood_color = Color(0.3, 0.2, 0.12)
	var brass_color = Color(0.6, 0.5, 0.25)
	var gold_color = Color(0.95, 0.8, 0.2)
	
	# Chest holder for lazy orbit
	var chest = Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 0.25, 0)
	root.add_child(chest)
	
	# Materials
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = wood_color
	wood_mat.roughness = 0.9
	wood_mat.metallic = 0.0
	
	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = brass_color
	brass_mat.metallic = 0.7
	brass_mat.roughness = 0.3
	
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = gold_color
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.15
	gold_mat.emission_enabled = true
	gold_mat.emission = gold_color
	gold_mat.emission_energy_multiplier = 0.5
	
	# === CHEST BODY ===
	# Main body box
	var body = MeshInstance3D.new()
	var bodym = BoxMesh.new()
	bodym.size = Vector3(0.6, 0.35, 0.4)
	body.mesh = bodym
	body.position.y = 0.175  # Origin at bottom, so center is half height
	body.material_override = wood_mat
	chest.add_child(body)
	
	# === LID ===
	# Box lid with slight height to suggest curve
	var lid = MeshInstance3D.new()
	var lidm = BoxMesh.new()
	lidm.size = Vector3(0.6, 0.12, 0.4)
	lid.mesh = lidm
	lid.position.y = 0.41  # Sits on top of body (0.35 + 0.06)
	lid.material_override = wood_mat
	chest.add_child(lid)
	
	# Lid top curve (rounded top using a cylinder)
	var lid_curve = MeshInstance3D.new()
	var lcm = CylinderMesh.new()
	lcm.top_radius = 0.2
	lcm.bottom_radius = 0.2
	lcm.height = 0.6  # Width of chest
	lid_curve.mesh = lcm
	lid_curve.rotation_degrees.z = 90  # Rotate to run along X axis
	lid_curve.position.y = 0.42
	lid_curve.material_override = wood_mat
	chest.add_child(lid_curve)
	
	# === HORIZONTAL BANDS (around body) ===
	# Bottom band
	var band_bottom = MeshInstance3D.new()
	var bbm = BoxMesh.new()
	bbm.size = Vector3(0.64, 0.04, 0.44)
	band_bottom.mesh = bbm
	band_bottom.position.y = 0.04
	band_bottom.material_override = brass_mat
	chest.add_child(band_bottom)
	
	# Top band (at body top)
	var band_top = MeshInstance3D.new()
	var btm = BoxMesh.new()
	btm.size = Vector3(0.64, 0.04, 0.44)
	band_top.mesh = btm
	band_top.position.y = 0.33
	band_top.material_override = brass_mat
	chest.add_child(band_top)
	
	# === VERTICAL BANDS (over lid, front to back) ===
	# Left strap
	var strap_left = MeshInstance3D.new()
	var slm = BoxMesh.new()
	slm.size = Vector3(0.05, 0.14, 0.44)
	strap_left.mesh = slm
	strap_left.position = Vector3(-0.2, 0.41, 0)
	strap_left.material_override = brass_mat
	chest.add_child(strap_left)
	
	# Right strap
	var strap_right = MeshInstance3D.new()
	var srm = BoxMesh.new()
	srm.size = Vector3(0.05, 0.14, 0.44)
	strap_right.mesh = srm
	strap_right.position = Vector3(0.2, 0.41, 0)
	strap_right.material_override = brass_mat
	chest.add_child(strap_right)
	
	# === LOCK PLATE (front center) ===
	var lock = MeshInstance3D.new()
	var lockm = BoxMesh.new()
	lockm.size = Vector3(0.1, 0.1, 0.03)
	lock.mesh = lockm
	lock.position = Vector3(0, 0.25, 0.21)  # Front face
	lock.material_override = brass_mat
	chest.add_child(lock)
	
	# Lock keyhole (small dark indent)
	var keyhole = MeshInstance3D.new()
	var khm = CylinderMesh.new()
	khm.top_radius = 0.015
	khm.bottom_radius = 0.015
	khm.height = 0.02
	keyhole.mesh = khm
	keyhole.rotation_degrees.x = 90
	keyhole.position = Vector3(0, 0.24, 0.225)
	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.05, 0.03, 0.02)
	keyhole.material_override = dark_mat
	chest.add_child(keyhole)
	
	# === FLOATING SOVEREIGNS ===
	var sovereigns_holder = Node3D.new()
	sovereigns_holder.name = "SovereignsHolder"
	root.add_child(sovereigns_holder)
	
	for i in range(6):
		var coin = MeshInstance3D.new()
		coin.name = "Sovereign" + str(i)
		
		var cm = CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.1
		cm.height = 0.035  # Chunky coins
		coin.mesh = cm
		
		var angle = i * (TAU / 6)
		coin.position = Vector3(cos(angle) * 0.7, 0.35, sin(angle) * 0.7)
		coin.rotation_degrees.x = 90  # Flat like a coin
		coin.material_override = gold_mat
		sovereigns_holder.add_child(coin)
	
	# === PLATFORM BASE ===
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.55
	platm.bottom_radius = 0.65
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.15
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root

func create_skull_and_crossbones() -> Node3D:
	# PLACEHOLDER - simple white sphere until proper skull is built
	var root = Node3D.new()
	root.name = "skull_and_crossbones"
	
	var assembly = Node3D.new()
	assembly.name = "SkullAssembly"
	assembly.position = Vector3(0, 0.3, 0)
	root.add_child(assembly)
	
	# White sphere placeholder
	var sphere = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.3
	sphere.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.9, 0.9)
	mat.emission_energy_multiplier = 0.3
	sphere.material_override = mat
	assembly.add_child(sphere)
	
	# Platform
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.5
	platm.bottom_radius = 0.6
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.15
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root

func setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Create a Control root for the theme
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	
	# === SPACE BACKDROP with animated stars ===
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color.WHITE  # Shader handles the actual color
	
	# Load and apply the shader
	var shader = load("res://ui/SpaceBackdrop.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		# Shader defaults are already tuned - no overrides needed
		backdrop.material = mat
	
	ui_root.add_child(backdrop)
	# Move backdrop to back
	ui_root.move_child(backdrop, 0)
	ui_backdrop = backdrop
	
	# === CAROUSEL VIEWPORT CONTAINER ===
	# Sits between backdrop and UI - displays 3D carousel with transparent background
	carousel_viewport_container = SubViewportContainer.new()
	carousel_viewport_container.name = "CarouselViewportContainer"
	carousel_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	carousel_viewport_container.stretch = true
	carousel_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reparent the viewport into the container
	carousel_viewport.get_parent().remove_child(carousel_viewport)
	carousel_viewport_container.add_child(carousel_viewport)
	ui_root.add_child(carousel_viewport_container)
	# Hide by default - show when entering carousel menus
	carousel_viewport_container.visible = false
	
	# Apply Vespera Pop theme
	MenuTheme.apply_to(ui_root)
	
	# TitleGroup - plain Control, NOT a container
	var title_group = Control.new()
	title_group.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_group.offset_top = 18
	title_group.offset_left = -280
	title_group.offset_right = 280
	title_group.offset_bottom = 100
	ui_root.add_child(title_group)
	
	# Plank - visual only, safe to rotate
	var plank = ColorRect.new()
	plank.set_anchors_preset(Control.PRESET_FULL_RECT)
	plank.color = Color("#3D2A1E")
	plank.pivot_offset = Vector2(280, 41)  # Center pivot
	plank.rotation = deg_to_rad(-1.5)
	
	# Plank border/style via a StyleBoxFlat on a Panel inside
	var plank_panel = Panel.new()
	plank_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var plank_style = StyleBoxFlat.new()
	plank_style.bg_color = Color("#3D2A1E")
	plank_style.border_color = Color("#2A1D14")
	plank_style.border_width_left = 4
	plank_style.border_width_right = 4
	plank_style.border_width_top = 3
	plank_style.border_width_bottom = 5
	plank_style.corner_radius_top_left = 8
	plank_style.corner_radius_top_right = 12
	plank_style.corner_radius_bottom_left = 10
	plank_style.corner_radius_bottom_right = 6
	plank_style.shadow_color = Color(0, 0, 0, 0.4)
	plank_style.shadow_size = 6
	plank_style.shadow_offset = Vector2(2, 4)
	plank_style.anti_aliasing = true
	plank_panel.add_theme_stylebox_override("panel", plank_style)
	plank_panel.pivot_offset = Vector2(280, 41)
	plank_panel.rotation = deg_to_rad(-1.5)
	title_group.add_child(plank_panel)
	
	# Title label - same rotation as plank
	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.pivot_offset = Vector2(280, 41)
	title_label.rotation = deg_to_rad(-1.5)
	title_label.add_theme_font_override("font", FONT_TITLE)
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color("#F5E6D3"))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_group.add_child(title_label)
	
	coins_label = Label.new()
	coins_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins_label.offset_left = -180
	coins_label.offset_right = -20
	coins_label.offset_top = 15
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 24)
	coins_label.add_theme_color_override("font_color", Color("#FF7A2A"))  # C_ACCENT_EMBER for gold
	ui_root.add_child(coins_label)
	
	shards_label = Label.new()
	shards_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shards_label.offset_left = -180
	shards_label.offset_right = -20
	shards_label.offset_top = 75
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shards_label.add_theme_font_size_override("font_size", 20)
	shards_label.add_theme_color_override("font_color", Color("#A66BFF"))  # C_ACCENT_VIO for sovereigns
	ui_root.add_child(shards_label)
	
	bits_label = Label.new()
	bits_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bits_label.offset_left = -180
	bits_label.offset_right = -20
	bits_label.offset_top = 45
	bits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bits_label.add_theme_font_size_override("font_size", 20)
	bits_label.add_theme_color_override("font_color", COLOR_GOLD)
	ui_root.add_child(bits_label)
	
	item_name_label = Label.new()
	item_name_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	item_name_label.offset_bottom = -120
	item_name_label.offset_top = -160
	item_name_label.offset_left = -300
	item_name_label.offset_right = 300
	item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_label.add_theme_font_size_override("font_size", 28)
	item_name_label.add_theme_color_override("font_color", Color("#EAF2FF"))
	item_name_label.visible = false
	ui_root.add_child(item_name_label)
	
	item_desc_label = Label.new()
	item_desc_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	item_desc_label.offset_bottom = -85
	item_desc_label.offset_top = -120
	item_desc_label.offset_left = -350
	item_desc_label.offset_right = 350
	item_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_desc_label.add_theme_font_size_override("font_size", 15)
	item_desc_label.add_theme_color_override("font_color", Color("#A9B8D6"))  # C_TEXT_MUTED
	item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	item_desc_label.visible = false
	ui_root.add_child(item_desc_label)
	
	# NAV BUTTONS - theme handles styling
	nav_left_button = Button.new()
	nav_left_button.text = "◀"
	nav_left_button.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	nav_left_button.offset_left = 20
	nav_left_button.offset_right = 80
	nav_left_button.offset_top = -35
	nav_left_button.offset_bottom = 35
	nav_left_button.add_theme_font_size_override("font_size", 36)
	nav_left_button.visible = false
	nav_left_button.mouse_filter = Control.MOUSE_FILTER_STOP
	nav_left_button.focus_mode = Control.FOCUS_ALL
	ui_root.add_child(nav_left_button)
	nav_left_button.pressed.connect(_on_nav_left_pressed)
	
	nav_right_button = Button.new()
	nav_right_button.text = "▶"
	nav_right_button.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	nav_right_button.offset_left = -80
	nav_right_button.offset_right = -20
	nav_right_button.offset_top = -35
	nav_right_button.offset_bottom = 35
	nav_right_button.add_theme_font_size_override("font_size", 36)
	nav_right_button.visible = false
	nav_right_button.mouse_filter = Control.MOUSE_FILTER_STOP
	nav_right_button.focus_mode = Control.FOCUS_ALL
	ui_root.add_child(nav_right_button)
	nav_right_button.pressed.connect(_on_nav_right_pressed)
	
	action_button = Button.new()
	action_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	action_button.offset_left = -80
	action_button.offset_right = 80
	action_button.offset_top = -75
	action_button.offset_bottom = -35
	action_button.add_theme_font_size_override("font_size", 18)
	action_button.visible = false
	ui_root.add_child(action_button)
	action_button.pressed.connect(_on_action_pressed)
	
	back_button = Button.new()
	back_button.text = "← BACK"
	back_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_button.offset_left = 15
	back_button.offset_right = 105
	back_button.offset_top = 15
	back_button.offset_bottom = 45
	back_button.visible = false
	ui_root.add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)
	
	create_main_menu_buttons()
	create_black_market_ui()

func create_main_menu_buttons() -> void:
	main_menu_container = VBoxContainer.new()
	main_menu_container.set_anchors_preset(Control.PRESET_CENTER)
	main_menu_container.offset_left = -145
	main_menu_container.offset_right = 145
	main_menu_container.offset_top = -185
	main_menu_container.offset_bottom = 185
	main_menu_container.add_theme_constant_override("separation", 14)
	ui_root.add_child(main_menu_container)
	
	var btn_set_sail = Button.new()
	btn_set_sail.text = "SET SAIL"
	btn_set_sail.custom_minimum_size = Vector2(260, 56)
	btn_set_sail.add_theme_font_override("font", FONT_UI)
	btn_set_sail.add_theme_font_size_override("font_size", 22)
	btn_set_sail.pressed.connect(_on_play)
	main_menu_container.add_child(btn_set_sail)
	
	var btn_crew = Button.new()
	btn_crew.text = "CREW"
	btn_crew.custom_minimum_size = Vector2(260, 48)
	btn_crew.add_theme_font_override("font", FONT_UI)
	btn_crew.add_theme_font_size_override("font_size", 18)
	btn_crew.pressed.connect(_on_crew)
	main_menu_container.add_child(btn_crew)
	
	var btn_vessels = Button.new()
	btn_vessels.text = "VESSELS"
	btn_vessels.custom_minimum_size = Vector2(260, 48)
	btn_vessels.add_theme_font_override("font", FONT_UI)
	btn_vessels.add_theme_font_size_override("font_size", 18)
	btn_vessels.pressed.connect(_on_vessels)
	main_menu_container.add_child(btn_vessels)
	
	var btn_shipyard = Button.new()
	btn_shipyard.text = "SHIPYARD"
	btn_shipyard.custom_minimum_size = Vector2(260, 48)
	btn_shipyard.add_theme_font_override("font", FONT_UI)
	btn_shipyard.add_theme_font_size_override("font_size", 18)
	btn_shipyard.pressed.connect(_on_shipyard)
	main_menu_container.add_child(btn_shipyard)
	
	var btn_market = Button.new()
	btn_market.text = "BLACK MARKET"
	btn_market.custom_minimum_size = Vector2(260, 48)
	btn_market.add_theme_font_override("font", FONT_UI)
	btn_market.add_theme_font_size_override("font_size", 18)
	btn_market.pressed.connect(_on_black_market)
	main_menu_container.add_child(btn_market)
	
	var btn_exchange = Button.new()
	btn_exchange.text = "EXCHANGE"
	btn_exchange.custom_minimum_size = Vector2(260, 48)
	btn_exchange.add_theme_font_override("font", FONT_UI)
	btn_exchange.add_theme_font_size_override("font_size", 18)
	btn_exchange.pressed.connect(_on_exchange)
	main_menu_container.add_child(btn_exchange)
	
	var btn_settings = Button.new()
	btn_settings.text = "SETTINGS"
	btn_settings.custom_minimum_size = Vector2(260, 48)
	btn_settings.add_theme_font_override("font", FONT_UI)
	btn_settings.add_theme_font_size_override("font_size", 18)
	btn_settings.pressed.connect(_on_settings)
	main_menu_container.add_child(btn_settings)

func create_black_market_ui() -> void:
	black_market_container = VBoxContainer.new()
	black_market_container.set_anchors_preset(Control.PRESET_CENTER)
	black_market_container.offset_left = -150
	black_market_container.offset_right = 150
	black_market_container.offset_top = -100
	black_market_container.offset_bottom = 150
	black_market_container.add_theme_constant_override("separation", 12)
	black_market_container.visible = false
	ui_root.add_child(black_market_container)
	
	var spin_btn = Button.new()
	spin_btn.text = "🎰 FREE DAILY SPIN"
	spin_btn.custom_minimum_size = Vector2(280, 45)
	spin_btn.add_theme_font_size_override("font_size", 16)
	spin_btn.pressed.connect(_on_free_spin)
	black_market_container.add_child(spin_btn)
	
	var ad_coins_btn = Button.new()
	ad_coins_btn.text = "📺 Watch Ad → ◈ 100 Marks"
	ad_coins_btn.custom_minimum_size = Vector2(280, 45)
	ad_coins_btn.add_theme_font_size_override("font_size", 16)
	ad_coins_btn.pressed.connect(_on_ad_coins)
	black_market_container.add_child(ad_coins_btn)
	
	var sep = Label.new()
	sep.text = "── PREMIUM ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 12)
	sep.add_theme_color_override("font_color", Color("#A9B8D6"))  # C_TEXT_MUTED
	black_market_container.add_child(sep)
	
	var buy_bits = Button.new()
	buy_bits.text = "🪙 6 Bits → $1.99"
	buy_bits.custom_minimum_size = Vector2(280, 45)
	buy_bits.add_theme_font_size_override("font_size", 16)
	buy_bits.pressed.connect(_on_buy_bits)
	black_market_container.add_child(buy_bits)
	
	var buy_sovs = Button.new()
	buy_sovs.text = "🪙 6 Sovereigns → $11.99"
	buy_sovs.custom_minimum_size = Vector2(280, 45)
	buy_sovs.add_theme_font_size_override("font_size", 16)
	buy_sovs.pressed.connect(_on_buy_sovereigns)
	black_market_container.add_child(buy_sovs)
	
	var ebon_pass = Button.new()
	ebon_pass.text = "⭐ EBON PASS → $6.99/mo"
	ebon_pass.custom_minimum_size = Vector2(280, 50)
	ebon_pass.add_theme_font_size_override("font_size", 18)
	ebon_pass.pressed.connect(_on_ebon_pass)
	black_market_container.add_child(ebon_pass)

func show_main_menu() -> void:
	current_state = MenuState.MAIN
	title_label.text = "EBON TIDE"
	update_currency_display()
	hide_all_items()
	
	carousel_viewport_container.visible = false  # Hide 3D carousel viewport
	main_menu_container.visible = true
	black_market_container.visible = false
	item_name_label.visible = false
	item_desc_label.visible = false
	action_button.visible = false
	back_button.visible = false
	nav_left_button.visible = false
	nav_right_button.visible = false
	print("Showing main menu")

func show_crew_select() -> void:
	current_state = MenuState.CREW
	title_label.text = "SELECT CREW"
	
	selected_index = max(0, crew_ids.find(GameData.current_rider))
	current_display_items.clear()
	for m in character_meshes:
		current_display_items.append(m)
	arrange_carousel()
	show_carousel_ui()
	update_selection_display()
	print("Showing crew select, items: ", current_display_items.size())

func show_vessel_select() -> void:
	current_state = MenuState.VESSELS
	title_label.text = "SELECT VESSEL"
	
	selected_index = max(0, vessel_ids.find(GameData.current_board))
	current_display_items.clear()
	for m in vessel_meshes:
		current_display_items.append(m)
	arrange_carousel()
	show_carousel_ui()
	update_selection_display()
	print("Showing vessel select, items: ", current_display_items.size())

func show_shipyard() -> void:
	current_state = MenuState.SHIPYARD
	title_label.text = "SHIPYARD"
	
	current_display_items.clear()
	var locked_ids: Array = []
	
	for i in range(crew_ids.size()):
		if crew_ids[i] not in GameData.unlocked_riders:
			current_display_items.append(character_meshes[i])
			locked_ids.append({"type": "crew", "id": crew_ids[i]})
	
	for i in range(vessel_ids.size()):
		if vessel_ids[i] not in GameData.unlocked_boards:
			current_display_items.append(vessel_meshes[i])
			locked_ids.append({"type": "vessel", "id": vessel_ids[i]})
	
	set_meta("locked_ids", locked_ids)
	
	if current_display_items.is_empty():
		hide_all_items()
		item_name_label.text = "All Unlocked!"
		item_desc_label.text = "You own everything. Nice!"
		action_button.visible = false
		nav_left_button.visible = false
		nav_right_button.visible = false
	else:
		selected_index = 0
		arrange_carousel()
		update_shipyard_display()
		nav_left_button.visible = current_display_items.size() > 1
		nav_right_button.visible = current_display_items.size() > 1
	
	main_menu_container.visible = false
	black_market_container.visible = false
	carousel_viewport_container.visible = true  # Show 3D carousel
	item_name_label.visible = true
	item_desc_label.visible = true
	back_button.visible = true
	print("Showing shipyard, locked items: ", current_display_items.size())

func show_black_market() -> void:
	current_state = MenuState.BLACK_MARKET
	title_label.text = "BLACK MARKET"
	hide_all_items()
	
	main_menu_container.visible = false
	black_market_container.visible = false
	carousel_viewport_container.visible = true  # Show 3D carousel
	item_name_label.visible = true
	item_desc_label.visible = true
	action_button.visible = true
	action_button.disabled = false
	back_button.visible = true
	nav_left_button.visible = true
	nav_right_button.visible = true
	
	# Create all black market items if they don't exist
	if not carousel_root.has_node("BMWheel"):
		var wheel = create_wheel_of_fortune()
		wheel.name = "BMWheel"
		carousel_root.add_child(wheel)
	
	if not carousel_root.has_node("BMLookingGlass"):
		var glass = create_looking_glass_coins()
		glass.name = "BMLookingGlass"
		carousel_root.add_child(glass)
	
	if not carousel_root.has_node("BMSack"):
		var sack = create_sack_of_bits()
		sack.name = "BMSack"
		carousel_root.add_child(sack)
	
	if not carousel_root.has_node("BMChest"):
		var chest = create_chest_of_sovereigns()
		chest.name = "BMChest"
		carousel_root.add_child(chest)
	
	if not carousel_root.has_node("BMSkull"):
		var skull = create_skull_and_crossbones()
		skull.name = "BMSkull"
		carousel_root.add_child(skull)
	
	# Build display items array for carousel
	current_display_items.clear()
	for item_name in black_market_items:
		var item = carousel_root.get_node_or_null(item_name)
		if item:
			current_display_items.append(item)
	
	# Arrange in carousel and show first item
	selected_index = 0
	arrange_carousel()
	update_black_market_display()
	
	print("Showing black market carousel with ", current_display_items.size(), " items")

var black_market_items: Array = ["BMWheel", "BMLookingGlass", "BMSack", "BMChest", "BMSkull"]
var black_market_names: Array = ["Wheel of Fortune", "Looking Glass", "Sack of Bits", "Chest of Sovereigns", "Ebon Pass"]
var black_market_descs: Array = ["Free daily spin!", "Watch ad for 100 Marks", "6 Bits - $1.99", "6 Sovereigns - $11.99", "Ad-free runs - $6.99/mo"]
var black_market_buttons: Array = ["SPIN", "WATCH AD", "PURCHASE", "PURCHASE", "SUBSCRIBE"]

func update_black_market_display() -> void:
	# Update labels based on selected_index
	item_name_label.text = black_market_names[selected_index]
	item_desc_label.text = black_market_descs[selected_index]
	action_button.text = black_market_buttons[selected_index]

func show_carousel_ui() -> void:
	main_menu_container.visible = false
	black_market_container.visible = false
	carousel_viewport_container.visible = true  # Show 3D carousel viewport
	item_name_label.visible = true
	item_desc_label.visible = true
	action_button.visible = true
	back_button.visible = true
	nav_left_button.visible = true
	nav_right_button.visible = true

func hide_all_items() -> void:
	# Hide character meshes
	for m in character_meshes:
		if is_instance_valid(m):
			m.visible = false
	# Hide vessel meshes
	for m in vessel_meshes:
		if is_instance_valid(m):
			m.visible = false
	# Hide ALL carousel items (Test*, BM*, EX*)
	for child in carousel_root.get_children():
		if child.name.begins_with("Test") or child.name.begins_with("BM") or child.name.begins_with("EX"):
			child.visible = false

func arrange_carousel() -> void:
	hide_all_items()
	var count = current_display_items.size()
	if count == 0:
		return
	
	var radius = 3.0
	var angle_step = TAU / max(count, 1)
	
	# Position items in a circle - item 0 starts at front (z+)
	for i in range(count):
		var item = current_display_items[i]
		if not is_instance_valid(item):
			continue
		var angle = i * angle_step
		# Place in circle: front is positive Z, left is negative X
		item.position = Vector3(sin(angle) * radius, 0, cos(angle) * radius)
		# Face outward from center
		item.rotation.y = angle + PI
		item.visible = true
	
	# Rotate carousel so selected_index item is at front (angle 0)
	# Negative rotation brings higher indices to front
	target_rotation = -selected_index * angle_step
	current_rotation = target_rotation
	print("Arranged carousel: ", count, " items, selected: ", selected_index)

func update_currency_display() -> void:
	coins_label.text = "◈ " + str(GameData.marks)
	bits_label.text = "◆ " + str(GameData.bits)
	shards_label.text = "🪙 " + str(GameData.sovereigns)

func navigate(dir: int) -> void:
	var count = current_display_items.size()
	print("Navigate called: dir=", dir, " count=", count, " current=", selected_index)
	if count == 0:
		return
	
	selected_index = (selected_index + dir + count) % count
	var angle_step = TAU / max(count, 1)
	var new_target = -selected_index * angle_step
	
	# Make rotation take the short way around (smooth wrap)
	while new_target - current_rotation > PI:
		new_target -= TAU
	while new_target - current_rotation < -PI:
		new_target += TAU
	
	target_rotation = new_target
	
	print("New selected_index: ", selected_index, " target_rotation: ", target_rotation)
	
	match current_state:
		MenuState.CREW, MenuState.VESSELS:
			update_selection_display()
		MenuState.SHIPYARD:
			update_shipyard_display()
		MenuState.BLACK_MARKET:
			update_black_market_display()
		MenuState.EXCHANGE:
			update_exchange_display()

func update_selection_display() -> void:
	var id: String
	var data: Dictionary
	var is_equipped: bool
	var is_unlocked: bool
	
	if current_state == MenuState.CREW:
		id = crew_ids[selected_index]
		data = GameData.RIDERS[id]
		is_equipped = (id == GameData.current_rider)
		is_unlocked = id in GameData.unlocked_riders
	else:
		id = vessel_ids[selected_index]
		data = GameData.BOARDS[id]
		is_equipped = (id == GameData.current_board)
		is_unlocked = id in GameData.unlocked_boards
	
	var dname = data.get("name", id.capitalize())
	item_name_label.text = dname + (" ✓" if is_equipped else "")
	
	if current_state == MenuState.CREW:
		item_desc_label.text = data.get("perk_name", "") + ": " + data.get("perk_desc", "")
	else:
		item_desc_label.text = "Speed %d%% • Coins %d%% • Handling %d%%" % [
			int(data.get("speed_mult", 1.0) * 100),
			int(data.get("coin_mult", 1.0) * 100),
			int(data.get("handling_mult", 1.0) * 100)
		]
	
	if is_equipped:
		action_button.text = "EQUIPPED"
		action_button.disabled = true
	elif is_unlocked:
		action_button.text = "SELECT"
		action_button.disabled = false
	else:
		action_button.text = "🔒 LOCKED"
		action_button.disabled = true
	
	print("Updated display: ", dname)

func update_shipyard_display() -> void:
	var locked_ids = get_meta("locked_ids", [])
	if selected_index >= locked_ids.size():
		return
	
	var info = locked_ids[selected_index]
	var data: Dictionary
	if info.type == "crew":
		data = GameData.RIDERS[info.id]
	else:
		data = GameData.BOARDS[info.id]
	
	var price = data.get("price", 0)
	item_name_label.text = data.get("name", info.id.capitalize())
	item_desc_label.text = "Price: 🪙 " + str(price) + " Sovereign" + ("s" if price != 1 else "")
	
	action_button.visible = true
	if GameData.sovereigns >= price:
		action_button.text = "BUY 🪙 " + str(price)
		action_button.disabled = false
	else:
		action_button.text = "Need 🪙 " + str(price - GameData.sovereigns) + " more"
		action_button.disabled = true

# BUTTON CALLBACKS
func _on_nav_left_pressed() -> void:
	print("LEFT ARROW CLICKED!")
	navigate(-1)

func _on_nav_right_pressed() -> void:
	print("RIGHT ARROW CLICKED!")
	navigate(1)

func _on_action_pressed() -> void:
	print("Action pressed")
	match current_state:
		MenuState.CREW:
			var id = crew_ids[selected_index]
			if id in GameData.unlocked_riders:
				GameData.current_rider = id
				GameData.save_game()
				update_selection_display()
		MenuState.VESSELS:
			var id = vessel_ids[selected_index]
			if id in GameData.unlocked_boards:
				GameData.current_board = id
				GameData.save_game()
				update_selection_display()
		MenuState.SHIPYARD:
			buy_shipyard_item()
		MenuState.BLACK_MARKET:
			_handle_black_market_action()
		MenuState.EXCHANGE:
			do_exchange_action()

func _handle_black_market_action() -> void:
	match selected_index:
		0: _on_free_spin()
		1: _on_ad_coins()
		2: _on_buy_bits()
		3: _on_buy_sovereigns()
		4: _on_ebon_pass()

func buy_shipyard_item() -> void:
	var locked_ids = get_meta("locked_ids", [])
	if selected_index >= locked_ids.size():
		return
	var info = locked_ids[selected_index]
	var success = false
	
	if info.type == "crew":
		success = GameData.unlock_rider_with_sovereigns(info.id)
	else:
		success = GameData.unlock_board_with_sovereigns(info.id)
	
	if success:
		update_currency_display()
		show_shipyard()

func _on_back_pressed() -> void:
	print("Back pressed")
	show_main_menu()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_crew() -> void:
	show_crew_select()

func _on_vessels() -> void:
	show_vessel_select()

func _on_shipyard() -> void:
	show_shipyard()

func _on_black_market() -> void:
	show_black_market()

func _on_exchange() -> void:
	show_exchange()

func _on_settings() -> void:
	var sp = get_node_or_null("/root/SettingsPanel")
	if sp:
		sp.open()

func _on_free_spin() -> void:
	var reward = randi_range(25, 150)
	GameData.add_marks(reward)
	update_currency_display()
	print("Won ", reward, " marks!")

func _on_ad_coins() -> void:
	GameData.add_marks(100)
	update_currency_display()
	print("Ad watched: +100 marks")

func _on_buy_bits() -> void:
	# IAP: $1.99 for 6 Bits — placeholder until store integration
	print("IAP: Purchase flow not yet integrated (Bits)")

func _on_buy_sovereigns() -> void:
	# IAP: $11.99 for 6 Sovereigns — placeholder until store integration
	print("IAP: Purchase flow not yet integrated (Sovereigns)")

func _on_ebon_pass() -> void:
	# IAP: Ebon Pass — placeholder until store integration
	print("IAP: Ebon Pass not yet integrated")

# ============ EXCHANGE MENU ============
var exchange_marks_input: int = 1
var exchange_bits_input: int = 1

func show_exchange() -> void:
	current_state = MenuState.EXCHANGE
	title_label.text = "EXCHANGE"
	hide_all_items()
	main_menu_container.visible = false
	black_market_container.visible = false
	carousel_viewport_container.visible = true  # Show 3D carousel
	item_name_label.visible = true
	item_desc_label.visible = true
	action_button.visible = true
	action_button.disabled = false
	back_button.visible = true
	nav_left_button.visible = true
	nav_right_button.visible = true
	
	# Create exchange 3D items if they don't exist
	if not carousel_root.has_node("EXMarks"):
		var marks_obj = create_exchange_marks()
		marks_obj.name = "EXMarks"
		carousel_root.add_child(marks_obj)
	
	if not carousel_root.has_node("EXBits"):
		var bits_obj = create_exchange_bits()
		bits_obj.name = "EXBits"
		carousel_root.add_child(bits_obj)
	
	if not carousel_root.has_node("EXSovereigns"):
		var sovs_obj = create_exchange_sovereigns()
		sovs_obj.name = "EXSovereigns"
		carousel_root.add_child(sovs_obj)
	
	# Build display items array for carousel
	current_display_items.clear()
	for item_name in exchange_items:
		var item = carousel_root.get_node_or_null(item_name)
		if item:
			current_display_items.append(item)
	
	# Arrange in carousel
	selected_index = 0
	arrange_carousel()
	update_exchange_display()
	
	print("Showing exchange carousel with ", current_display_items.size(), " items")

var exchange_items: Array = ["EXMarks", "EXBits", "EXSovereigns"]
var exchange_names: Array = ["Marks", "Bits", "Sovereigns"]

func update_exchange_display() -> void:
	var idx = selected_index
	item_name_label.text = exchange_names[idx]
	
	match idx:
		0:  # Marks
			item_desc_label.text = "You have: " + str(GameData.marks) + " Marks"
			action_button.text = "TRADE UP (100 → 1 Bit)"
		1:  # Bits
			item_desc_label.text = "You have: " + str(GameData.bits) + " Bits"
			action_button.text = "TRADE UP (6 → 1 Sov)"
		2:  # Sovereigns
			item_desc_label.text = "You have: " + str(GameData.sovereigns) + " Sovereigns"
			action_button.text = "TRADE DOWN (1 → 6 Bits)"

func do_exchange_action() -> void:
	match selected_index:
		0:  # Marks → Bits
			if GameData.exchange_marks_to_bits(1):
				print("Exchanged 100 Marks → 1 Bit")
		1:  # Bits → Sovereigns
			if GameData.exchange_bits_to_sovereigns(1):
				print("Exchanged 6 Bits → 1 Sovereign")
		2:  # Sovereigns → Bits (trade down) — use proper validation
			if GameData.sovereigns >= 1:
				GameData.sovereigns -= 1
				GameData.bits += 6
				GameData.save_game()
				print("Exchanged 1 Sovereign → 6 Bits")
			else:
				print("Not enough Sovereigns to trade down")
	
	update_currency_display()
	update_exchange_display()

# === EXCHANGE 3D OBJECTS ===
func create_exchange_marks() -> Node3D:
	var root = Node3D.new()
	root.name = "exchange_marks"
	
	# Bronze/copper colored octahedron for Marks
	var assembly = Node3D.new()
	assembly.name = "MarksAssembly"
	assembly.position = Vector3(0, 0.4, 0)
	root.add_child(assembly)
	
	# Stack of coin-like cylinders
	var coin_mat = StandardMaterial3D.new()
	coin_mat.albedo_color = Color(0.7, 0.5, 0.3)  # Bronze
	coin_mat.metallic = 0.7
	coin_mat.roughness = 0.3
	coin_mat.emission_enabled = true
	coin_mat.emission = Color(0.7, 0.5, 0.3)
	coin_mat.emission_energy_multiplier = 0.3
	
	for i in range(5):
		var coin = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.25 - i * 0.02
		cm.bottom_radius = 0.25 - i * 0.02
		cm.height = 0.05
		coin.mesh = cm
		coin.position.y = i * 0.06
		coin.material_override = coin_mat
		assembly.add_child(coin)
	
	# Platform
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.5
	platm.bottom_radius = 0.6
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.15
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root

func create_exchange_bits() -> Node3D:
	var root = Node3D.new()
	root.name = "exchange_bits"
	
	# Silver colored prism pieces for Bits
	var assembly = Node3D.new()
	assembly.name = "BitsAssembly"
	assembly.position = Vector3(0, 0.4, 0)
	root.add_child(assembly)
	
	var bit_mat = StandardMaterial3D.new()
	bit_mat.albedo_color = Color(0.75, 0.75, 0.8)  # Silver
	bit_mat.metallic = 0.9
	bit_mat.roughness = 0.2
	bit_mat.emission_enabled = true
	bit_mat.emission = Color(0.75, 0.75, 0.8)
	bit_mat.emission_energy_multiplier = 0.4
	
	# 6 triangular bits arranged in a circle
	for i in range(6):
		var bit = MeshInstance3D.new()
		var pm = PrismMesh.new()
		pm.size = Vector3(0.15, 0.04, 0.2)
		bit.mesh = pm
		var angle = i * (TAU / 6.0)
		bit.position = Vector3(cos(angle) * 0.3, 0, sin(angle) * 0.3)
		bit.rotation_degrees.y = rad_to_deg(angle) + 90
		bit.material_override = bit_mat
		assembly.add_child(bit)
	
	# Platform
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.5
	platm.bottom_radius = 0.6
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.15
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root

func create_exchange_sovereigns() -> Node3D:
	var root = Node3D.new()
	root.name = "exchange_sovereigns"
	
	# Gold colored large coin for Sovereigns
	var assembly = Node3D.new()
	assembly.name = "SovereignsAssembly"
	assembly.position = Vector3(0, 0.4, 0)
	root.add_child(assembly)
	
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.8, 0.2)  # Gold
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.1
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.95, 0.8, 0.2)
	gold_mat.emission_energy_multiplier = 0.5
	
	# Large sovereign coin
	var coin = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = 0.08
	coin.mesh = cm
	coin.rotation_degrees.x = 15  # Slight tilt
	coin.material_override = gold_mat
	assembly.add_child(coin)
	
	# Inner ring detail
	var ring = MeshInstance3D.new()
	var rm = TorusMesh.new()
	rm.inner_radius = 0.2
	rm.outer_radius = 0.25
	ring.mesh = rm
	ring.position.y = 0.05
	ring.rotation_degrees.x = 90
	ring.material_override = gold_mat
	assembly.add_child(ring)
	
	# Platform
	var plat = MeshInstance3D.new()
	var platm = CylinderMesh.new()
	platm.top_radius = 0.5
	platm.bottom_radius = 0.6
	platm.height = 0.12
	plat.mesh = platm
	plat.position.y = -0.15
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.18)
	pmat.metallic = 0.6
	plat.material_override = pmat
	root.add_child(plat)
	
	return root
