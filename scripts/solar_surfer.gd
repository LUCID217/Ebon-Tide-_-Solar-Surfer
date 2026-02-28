extends Node3D

# Solar Surfer visual components
# Attach to Player node, will create the surfer mesh

var board: MeshInstance3D
var engine: MeshInstance3D
var engine_glow: MeshInstance3D
var sail: MeshInstance3D
var sail_frame: MeshInstance3D
var rider: Node3D
var vessel_model: Node3D
var vessel_base_material: StandardMaterial3D

# Materials for dynamic effects
var engine_material: StandardMaterial3D
var sail_material: StandardMaterial3D

# Animation state
var target_sail_scale: float = 1.0
var current_sail_scale: float = 1.0
var target_engine_glow: float = 1.0
var current_engine_glow: float = 1.0

func _ready() -> void:
	build_surfer()

func build_surfer() -> void:
	# === VESSEL (imported 3D model, replaces procedural board/sail/engine) ===
	# Map vessel IDs to GLB paths
	var vessel_models: Dictionary = {
		"default": "res://models/vessel_default.glb",
	}
	
	# Get current vessel from GameData
	var current_vessel = "default"
	if get_node_or_null("/root/GameData"):
		current_vessel = GameData.current_board
	
	var model_path = vessel_models.get(current_vessel, "")
	var vessel_scene = load(model_path) if model_path != "" else null
	
	if vessel_scene:
		vessel_model = vessel_scene.instantiate()
		# Scale vessel to match board collision box (2.2L x 0.8W x 0.15H)
		# Model is ~2.5 units long, scale to ~2.2
		var v_scale = 2.5
		vessel_model.scale = Vector3(v_scale, v_scale, v_scale)
		vessel_model.position = Vector3(0, 2.1, 0)
		# Face forward in gameplay — motors face player (90 degree rotation)
		vessel_model.rotation_degrees.y = 270.0
		
		# Apply vessel material — dieselpunk palette
		# Dark weathered hull with metallic sheen
		var hull_material = StandardMaterial3D.new()
		hull_material.albedo_color = Color(0.18, 0.16, 0.22)  # Dark blue-steel
		hull_material.metallic = 0.6
		hull_material.roughness = 0.4
		hull_material.emission_enabled = true
		hull_material.emission = Color(0.08, 0.1, 0.18)  # Faint cool edge glow
		hull_material.emission_energy_multiplier = 0.3
		hull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive(vessel_model, hull_material)
		vessel_base_material = hull_material  # Store for damage state changes
		add_child(vessel_model)
		print("Vessel model loaded: ", model_path)
	else:
		# Fallback: procedural board if no model found
		board = MeshInstance3D.new()
		var board_mesh = BoxMesh.new()
		board_mesh.size = Vector3(0.8, 0.15, 2.2)
		board.mesh = board_mesh
		board.position = Vector3(0, 0, 0)
		var board_material = StandardMaterial3D.new()
		board_material.albedo_color = Color(0.6, 0.45, 0.25)
		board_material.metallic = 0.4
		board_material.roughness = 0.6
		board.material_override = board_material
		add_child(board)
		
		var nose = MeshInstance3D.new()
		var nose_mesh = PrismMesh.new()
		nose_mesh.size = Vector3(0.8, 0.15, 0.6)
		nose.mesh = nose_mesh
		nose.position = Vector3(0, 0, -1.4)
		nose.rotation_degrees = Vector3(0, 180, 0)
		nose.material_override = board_material
		add_child(nose)
		
		# Engine
		engine = MeshInstance3D.new()
		var engine_mesh = CylinderMesh.new()
		engine_mesh.top_radius = 0.2
		engine_mesh.bottom_radius = 0.25
		engine_mesh.height = 0.5
		engine.mesh = engine_mesh
		engine.position = Vector3(0, 0.1, 1.2)
		engine.rotation_degrees = Vector3(90, 0, 0)
		var engine_body_material = StandardMaterial3D.new()
		engine_body_material.albedo_color = Color(0.3, 0.25, 0.2)
		engine_body_material.metallic = 0.8
		engine_body_material.roughness = 0.3
		engine.material_override = engine_body_material
		add_child(engine)
		
		# Engine glow
		engine_glow = MeshInstance3D.new()
		var glow_mesh = CylinderMesh.new()
		glow_mesh.top_radius = 0.12
		glow_mesh.bottom_radius = 0.18
		glow_mesh.height = 0.4
		engine_glow.mesh = glow_mesh
		engine_glow.position = Vector3(0, 0.1, 1.35)
		engine_glow.rotation_degrees = Vector3(90, 0, 0)
		engine_material = StandardMaterial3D.new()
		engine_material.albedo_color = Color(1.0, 0.6, 0.2)
		engine_material.emission_enabled = true
		engine_material.emission = Color(1.0, 0.5, 0.1)
		engine_material.emission_energy_multiplier = 2.0
		engine_glow.material_override = engine_material
		add_child(engine_glow)
		
		# Sail mast
		sail_frame = MeshInstance3D.new()
		var mast_mesh = CylinderMesh.new()
		mast_mesh.top_radius = 0.03
		mast_mesh.bottom_radius = 0.04
		mast_mesh.height = 1.8
		sail_frame.mesh = mast_mesh
		sail_frame.position = Vector3(0, 0.9, -0.3)
		sail_frame.rotation_degrees = Vector3(0, 25, 0)
		var mast_material = StandardMaterial3D.new()
		mast_material.albedo_color = Color(0.5, 0.4, 0.3)
		mast_material.metallic = 0.7
		mast_material.roughness = 0.4
		sail_frame.material_override = mast_material
		add_child(sail_frame)
		
		# Sail
		sail = MeshInstance3D.new()
		var sail_mesh = PrismMesh.new()
		sail_mesh.size = Vector3(0.05, 1.5, 1.2)
		sail.mesh = sail_mesh
		sail.position = Vector3(0, 1.0, 0.3)
		sail.rotation_degrees = Vector3(0, 25, 0)
		sail_material = StandardMaterial3D.new()
		sail_material.albedo_color = Color(1.0, 0.85, 0.5)
		sail_material.emission_enabled = true
		sail_material.emission = Color(1.0, 0.7, 0.3)
		sail_material.emission_energy_multiplier = 0.5
		sail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sail_material.albedo_color.a = 0.85
		sail.material_override = sail_material
		add_child(sail)
	
	# === RIDER (imported 3D model) ===
	var rider_scene = load("res://models/rider_base.glb")
	if rider_scene:
		rider = rider_scene.instantiate()
		# Model is 1.8 units tall, feet at Y=0. Place on top of board (board is 0.15 tall)
		rider.position = Vector3(0, 0.075, -0.2)  # Slightly forward on board
		rider.scale = Vector3(1.0, 1.0, 1.0)
		# Surfing stance: sideways on board, back toward left side of screen
		# 90° = fully sideways, +25° extra = slight turn toward forward direction
		rider.rotation_degrees.y = 115.0
		# Apply a visible material to ALL MeshInstance3D nodes (recursive)
		var rider_material = StandardMaterial3D.new()
		rider_material.albedo_color = Color(0.4, 0.35, 0.3)
		rider_material.roughness = 0.7
		rider_material.metallic = 0.1
		rider_material.emission_enabled = true
		rider_material.emission = Color(0.2, 0.18, 0.15)
		rider_material.emission_energy_multiplier = 0.3
		rider_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive(rider, rider_material)
		add_child(rider)
		print("Rider model loaded successfully. Children: ", rider.get_child_count())
	else:
		push_warning("Rider model not found at res://models/rider_base.glb")

func _apply_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)

func _process(delta: float) -> void:
	# Smooth sail scaling
	current_sail_scale = lerp(current_sail_scale, target_sail_scale, 5.0 * delta)
	if sail:
		sail.scale.y = current_sail_scale
		sail.scale.z = current_sail_scale
	
	# Smooth engine glow
	current_engine_glow = lerp(current_engine_glow, target_engine_glow, 8.0 * delta)
	if engine_material:
		engine_material.emission_energy_multiplier = current_engine_glow
	if engine_glow:
		engine_glow.scale = Vector3(1, 1, 0.5 + current_engine_glow * 0.5)

func set_zone(zone: int) -> void:
	# Zone enum: 0=SHADOW, 1=LIGHT, 2=SUPER_LIGHT
	# Only update sail if it's still intact
	if sail and sail.visible:
		match zone:
			0:  # Shadow - sail shrinks, engine dims
				target_sail_scale = 0.4
				if sail_material:
					sail_material.emission = Color(0.3, 0.3, 0.5)
			1:  # Light - normal
				target_sail_scale = 1.0
				if sail_material:
					sail_material.emission = Color(1.0, 0.7, 0.3)
			2:  # Super Light - sail expands, engine blazes
				target_sail_scale = 1.4
				if sail_material:
					sail_material.emission = Color(1.0, 1.0, 0.5)
	
	# Only update engine if it's still intact
	if engine_glow and engine_glow.visible:
		match zone:
			0:
				target_engine_glow = 0.5
			1:
				target_engine_glow = 2.0
			2:
				target_engine_glow = 4.0

func set_boost(is_boosting: bool) -> void:
	if is_boosting and engine_glow and engine_glow.visible:
		target_engine_glow = max(target_engine_glow, 3.5)
	# Engine glow will return to zone default when not boosting

func destroy_sail() -> void:
	# === GLB VESSEL: tint darker + kill emission to show sail damage ===
	if vessel_model:
		var damaged_material = StandardMaterial3D.new()
		damaged_material.albedo_color = Color(0.2, 0.12, 0.1)  # Warm-dark, scorched look
		damaged_material.metallic = 0.4
		damaged_material.roughness = 0.7
		damaged_material.emission_enabled = true
		damaged_material.emission = Color(0.15, 0.06, 0.02)  # Faint ember — damaged but alive
		damaged_material.emission_energy_multiplier = 0.2
		damaged_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive(vessel_model, damaged_material)
		# Brief flash tween
		var tween = create_tween()
		tween.tween_property(vessel_model, "scale", vessel_model.scale * 0.9, 0.08)
		tween.tween_property(vessel_model, "scale", vessel_model.scale, 0.15)
		return
	
	# Fallback: procedural sail
	if sail:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sail, "position:y", sail.position.y + 3.0, 0.5)
		tween.tween_property(sail, "position:z", sail.position.z + 5.0, 0.5)
		tween.tween_property(sail, "rotation_degrees:x", 45.0, 0.5)
		tween.tween_property(sail, "rotation_degrees:z", 90.0, 0.5)
		if sail.get("modulate"):
			tween.tween_property(sail, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(func(): sail.visible = false)
	
	if sail_frame:
		var tween2 = create_tween()
		tween2.tween_property(sail_frame, "rotation_degrees:x", -30.0, 0.3)
		tween2.chain().tween_callback(func(): sail_frame.visible = false)
	
	target_sail_scale = 0.0

func destroy_engine() -> void:
	# === GLB VESSEL: go full dark — dead in the water ===
	if vessel_model:
		var dead_material = StandardMaterial3D.new()
		dead_material.albedo_color = Color(0.12, 0.1, 0.1)  # Near-black charcoal
		dead_material.metallic = 0.2
		dead_material.roughness = 0.9
		dead_material.emission_enabled = false  # No glow at all — dead
		dead_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive(vessel_model, dead_material)
		# Sputter effect
		var tween = create_tween()
		tween.tween_property(vessel_model, "scale", vessel_model.scale * 1.05, 0.05)
		tween.tween_property(vessel_model, "scale", vessel_model.scale * 0.95, 0.05)
		tween.tween_property(vessel_model, "scale", vessel_model.scale, 0.1)
		return
	
	# Fallback: procedural engine
	if engine_glow:
		var tween = create_tween()
		tween.tween_property(engine_material, "emission_energy_multiplier", 5.0, 0.1)
		tween.tween_property(engine_material, "emission_energy_multiplier", 0.5, 0.1)
		tween.tween_property(engine_material, "emission_energy_multiplier", 3.0, 0.1)
		tween.tween_property(engine_material, "emission_energy_multiplier", 0.0, 0.2)
		tween.chain().tween_callback(func(): engine_glow.visible = false)
	
	target_engine_glow = 0.0
	
	if engine:
		var dead_material = StandardMaterial3D.new()
		dead_material.albedo_color = Color(0.2, 0.2, 0.2)
		dead_material.metallic = 0.3
		dead_material.roughness = 0.8
		engine.material_override = dead_material

func repair_engine() -> void:
	# === GLB VESSEL: restore to sail-damaged state (not fully pristine) ===
	if vessel_model and vessel_base_material:
		var damaged_material = StandardMaterial3D.new()
		damaged_material.albedo_color = Color(0.2, 0.12, 0.1)
		damaged_material.metallic = 0.4
		damaged_material.roughness = 0.7
		damaged_material.emission_enabled = true
		damaged_material.emission = Color(0.15, 0.06, 0.02)
		damaged_material.emission_energy_multiplier = 0.2
		damaged_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apply_material_recursive(vessel_model, damaged_material)
		return
	
	# Fallback: procedural
	if engine_glow:
		engine_glow.visible = true
	
	if engine:
		var engine_body_material = StandardMaterial3D.new()
		engine_body_material.albedo_color = Color(0.3, 0.25, 0.2)
		engine_body_material.metallic = 0.8
		engine_body_material.roughness = 0.3
		engine.material_override = engine_body_material
	
	if engine_material:
		engine_material.emission_energy_multiplier = 2.0
	
	target_engine_glow = 2.0
	current_engine_glow = 2.0

func repair() -> void:
	# === GLB VESSEL: full restore to pristine ===
	if vessel_model and vessel_base_material:
		_apply_material_recursive(vessel_model, vessel_base_material)
		return
	
	# Fallback: procedural reset
	if sail:
		sail.visible = true
		sail.position = Vector3(0, 1.0, 0.3)
		sail.rotation_degrees = Vector3(0, 25, 0)
		sail.scale = Vector3.ONE
	
	if sail_frame:
		sail_frame.visible = true
		sail_frame.rotation_degrees = Vector3(0, 25, 0)
	
	if engine_glow:
		engine_glow.visible = true
	
	if engine:
		var engine_body_material = StandardMaterial3D.new()
		engine_body_material.albedo_color = Color(0.3, 0.25, 0.2)
		engine_body_material.metallic = 0.8
		engine_body_material.roughness = 0.3
		engine.material_override = engine_body_material
	
	if engine_material:
		engine_material.emission_energy_multiplier = 2.0
	
	target_sail_scale = 1.0
	current_sail_scale = 1.0
	target_engine_glow = 2.0
	current_engine_glow = 2.0

func apply_board_colors(board_color: Color, sail_color: Color, engine_color: Color) -> void:
	# Apply custom colors to board components
	if board:
		var mat = board.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = board_color
	
	if sail:
		if sail_material:
			sail_material.albedo_color = sail_color
			sail_material.albedo_color.a = 0.85
			sail_material.emission = sail_color * 0.7
	
	if engine_glow:
		if engine_material:
			engine_material.albedo_color = engine_color
			engine_material.emission = engine_color * 0.8
