extends Node3D

const LANE_WIDTH: float = 3.0
const LANES: Array[int] = [-1, 0, 1]

@export var spawn_ahead_distance: float = 100.0
@export var despawn_behind_distance: float = 20.0

# Zone enum matching player
enum Zone { SHADOW, LIGHT, SUPER_LIGHT }

# CONSISTENT spacing per zone
const SHADOW_SPACING: float = 25.0
const LIGHT_SPACING: float = 18.0
const SUPER_SPACING: float = 12.0

# CONSISTENT zone lengths
const SHADOW_LENGTH: float = 150.0
const LIGHT_LENGTH: float = 150.0
const SUPER_LIGHT_LENGTH: float = 150.0  # Extended from 100 - about 5-7 seconds

# Warning before super light
const SUPER_WARNING_DISTANCE: float = 50.0

var current_zone: int = Zone.LIGHT
var zone_start_distance: float = 0.0  # Distance at which current zone started
var super_light_warning_sent: bool = false
var next_zone_is_super: bool = false

var obstacles: Array[Node3D] = []
var coins: Array[Node3D] = []
var player: CharacterBody3D
var next_spawn_z: float = -40.0
var is_active: bool = true
var spawns_since_last_double: int = 0  # Cooldown tracker for doubles

# Obstacle types
enum ObstacleType { LOW, MEDIUM, TALL }

# Shared materials — created once, reused by all obstacles
var mat_rock: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_iron: StandardMaterial3D
var mat_sail: StandardMaterial3D
var mat_coin: StandardMaterial3D

# Difficulty tiers based on distance
enum Tier { TUTORIAL, WARMUP, INTRO, CORE, SKILLED, EXPERT }

# Tier settings: max_size, doubles_enabled, spacing_multiplier, spawn_chance
const TIER_SETTINGS = {
	0: { "max_size": 0, "doubles": false, "spacing_mult": 1.5, "spawn_chance": 0.5 },   # TUTORIAL: LOW only, wide, sparse
	1: { "max_size": 1, "doubles": false, "spacing_mult": 1.3, "spawn_chance": 0.6 },   # WARMUP: +MEDIUM, no doubles
	2: { "max_size": 2, "doubles": false, "spacing_mult": 1.15, "spawn_chance": 0.7 },  # INTRO: +TALL, no doubles
	3: { "max_size": 2, "doubles": true, "spacing_mult": 1.0, "spawn_chance": 0.75 },   # CORE: doubles allowed
	4: { "max_size": 2, "doubles": true, "spacing_mult": 0.95, "spawn_chance": 0.75 },  # SKILLED: slightly tighter
	5: { "max_size": 2, "doubles": true, "spacing_mult": 0.85, "spawn_chance": 0.80 },  # EXPERT: challenging but readable
}

func get_difficulty_tier(distance: float) -> int:
	if distance < 500.0:
		return Tier.TUTORIAL
	elif distance < 1000.0:
		return Tier.WARMUP
	elif distance < 1500.0:
		return Tier.INTRO
	elif distance < 2500.0:
		return Tier.CORE
	elif distance < 4000.0:
		return Tier.SKILLED
	else:
		return Tier.EXPERT

const TIER_THRESHOLDS = [0.0, 500.0, 1000.0, 1500.0, 2500.0, 4000.0, 99999.0]
const BLEND_ZONE = 150.0  # 150m smooth transition between tiers

func get_interpolated_settings(distance: float) -> Dictionary:
	var tier = get_difficulty_tier(distance)
	var tier_settings = TIER_SETTINGS[tier]
	
	# Don't blend at max tier
	if tier >= Tier.EXPERT:
		return tier_settings
	
	# Check if we're near the next tier boundary
	var tier_end = TIER_THRESHOLDS[tier + 1]
	var distance_to_next = tier_end - distance
	
	if distance_to_next < BLEND_ZONE:
		var next_tier = tier + 1
		var next_settings = TIER_SETTINGS[next_tier]
		var blend = 1.0 - (distance_to_next / BLEND_ZONE)  # 0 at boundary-150m, 1 at boundary
		
		# Interpolate numeric values
		return {
			"max_size": next_settings["max_size"] if blend > 0.5 else tier_settings["max_size"],
			"doubles": next_settings["doubles"] if blend > 0.7 else tier_settings["doubles"],  # Doubles kick in late
			"spacing_mult": lerp(tier_settings["spacing_mult"], next_settings["spacing_mult"], blend),
			"spawn_chance": lerp(tier_settings["spawn_chance"], next_settings["spawn_chance"], blend),
		}
	
	return tier_settings

# Fair obstacle rotation
var obstacle_pattern: Array = []
var pattern_index: int = 0

# Double spawn cooldown - ensures breathing room
const DOUBLE_COOLDOWN: int = 3  # Minimum spawns between doubles

# Safe lane tracking - last spawn's blocked lanes
var last_spawn_blocked_lanes: Array[int] = []

# Micrometeorite storm
var storm_hazard: Node3D
var distance_since_last_storm: float = 0.0
const STORM_INTERVAL_MIN: float = 400.0  # Minimum distance between storms
const STORM_INTERVAL_MAX: float = 600.0  # Maximum distance between storms
var next_storm_distance: float = 500.0   # First storm after ~500m

# Signal for warning
signal super_light_incoming
signal storm_warning

func set_player(p: CharacterBody3D) -> void:
	player = p

func set_storm_hazard(s: Node3D) -> void:
	storm_hazard = s

var hud: CanvasLayer

func set_hud(h: CanvasLayer) -> void:
	hud = h

func _ready() -> void:
	_create_shared_materials()
	generate_obstacle_pattern()

func _create_shared_materials() -> void:
	mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.15, 0.12, 0.18)  # Cool charcoal
	mat_rock.roughness = 0.9
	mat_rock.metallic = 0.1
	
	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.2, 0.16, 0.12)  # Dark timber
	mat_wood.roughness = 0.85
	
	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.18, 0.2, 0.25)  # Blue-steel
	mat_metal.metallic = 0.7
	mat_metal.roughness = 0.5
	
	mat_iron = StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.14, 0.16, 0.2)  # Dark iron-blue
	mat_iron.metallic = 0.8
	mat_iron.roughness = 0.5
	
	mat_sail = StandardMaterial3D.new()
	mat_sail.albedo_color = Color(0.4, 0.45, 0.55)  # Faded blue-grey sail
	mat_sail.roughness = 0.9
	
	mat_coin = StandardMaterial3D.new()
	mat_coin.albedo_color = Color(0.12, 0.79, 0.83)  # Teal Ion
	mat_coin.metallic = 1.0
	mat_coin.roughness = 0.3
	mat_coin.emission_enabled = true
	mat_coin.emission = Color(0.37, 0.91, 1.0)  # Aurora Cyan
	mat_coin.emission_energy_multiplier = 2.5

func generate_obstacle_pattern() -> void:
	obstacle_pattern = []
	var base_pattern = [
		ObstacleType.LOW, ObstacleType.LOW, ObstacleType.LOW,
		ObstacleType.MEDIUM, ObstacleType.MEDIUM,
		ObstacleType.TALL
	]
	base_pattern.shuffle()
	obstacle_pattern = base_pattern
	pattern_index = 0

func get_next_obstacle_type() -> int:
	var obs_type = obstacle_pattern[pattern_index]
	pattern_index += 1
	if pattern_index >= obstacle_pattern.size():
		generate_obstacle_pattern()
	return obs_type

func _process(delta: float) -> void:
	if not is_active or player == null or player.is_dead:
		return
	
	var player_z = player.position.z
	
	check_zone_transition(delta)
	# DISABLED: Storm system needs redesign - adds complexity without meaningful gameplay
	# check_storm_spawn()
	
	# Base spacing per zone
	var base_spacing: float
	match current_zone:
		Zone.SHADOW:
			base_spacing = SHADOW_SPACING
		Zone.LIGHT:
			base_spacing = LIGHT_SPACING
		Zone.SUPER_LIGHT:
			base_spacing = SUPER_SPACING
		_:
			base_spacing = LIGHT_SPACING  # P1 fix: safe default
	
	# Apply tier-based spacing multiplier (smooth interpolation)
	var tier_settings = get_interpolated_settings(player.distance_traveled)
	var spacing = base_spacing * tier_settings["spacing_mult"]
	
	# DISABLED: Storm check - kept for future implementation
	#if storm_hazard and storm_hazard.is_storm_active():
	#	cleanup_behind(player_z)
	#	return
	
	while next_spawn_z > player_z - spawn_ahead_distance:
		spawn_obstacle_at_z(next_spawn_z)
		spawn_coins_at_z(next_spawn_z)  # Same Z as obstacle for proper arc alignment
		next_spawn_z -= spacing
	
	cleanup_behind(player_z)

func check_storm_spawn() -> void:
	if not storm_hazard:
		return
	
	# Don't spawn new storm if one is active
	if storm_hazard.is_storm_active():
		return
	
	# Check if it's time for a storm
	if player.distance_traveled >= next_storm_distance:
		# Spawn storm ahead of player
		var storm_z = player.position.z - 150.0
		var difficulty = 1.0 + (player.distance_traveled / 1000.0) * 0.5  # Gets harder over distance
		storm_hazard.spawn_storm(storm_z, difficulty)
		
		# Set next storm distance
		next_storm_distance = player.distance_traveled + randf_range(STORM_INTERVAL_MIN, STORM_INTERVAL_MAX)
		
		# HUD warning
		if hud and hud.has_method("show_storm_warning"):
			hud.show_storm_warning()
		
		emit_signal("storm_warning")
		print("STORM SPAWNED! Next storm at: ", next_storm_distance, "m")

func check_zone_transition(_delta: float) -> void:
	if player == null:
		return
	
	# Use player's actual distance traveled, not speed-based calculation
	# This ensures zones are consistent regardless of board selection
	var distance_in_zone = player.distance_traveled - zone_start_distance
	
	# Send warning before super light zone
	if current_zone == Zone.LIGHT and next_zone_is_super:
		var current_zone_length = LIGHT_LENGTH
		if distance_in_zone >= current_zone_length - SUPER_WARNING_DISTANCE and not super_light_warning_sent:
			super_light_warning_sent = true
			emit_signal("super_light_incoming")
	
	var zone_length: float
	match current_zone:
		Zone.SHADOW:
			zone_length = SHADOW_LENGTH
		Zone.LIGHT:
			zone_length = LIGHT_LENGTH
		Zone.SUPER_LIGHT:
			zone_length = SUPER_LIGHT_LENGTH
		_:
			zone_length = LIGHT_LENGTH  # P1 fix: safe default
	
	if distance_in_zone >= zone_length:
		transition_to_next_zone()

func transition_to_next_zone() -> void:
	# Record where this new zone starts
	zone_start_distance = player.distance_traveled
	
	match current_zone:
		Zone.SHADOW:
			# Shadow ALWAYS goes to Light (never directly to Super)
			current_zone = Zone.LIGHT
			generate_light_pattern()
			
			# Decide NOW if the NEXT transition will be Super Light
			next_zone_is_super = randf() < 0.4  # 40% chance
			super_light_warning_sent = false
			
		Zone.LIGHT:
			if next_zone_is_super:
				# Go to Super Light
				current_zone = Zone.SUPER_LIGHT
				generate_super_pattern()
				print(">>> SUPER LIGHT ZONE! <<<")
			else:
				# Go to Shadow
				current_zone = Zone.SHADOW
				generate_shadow_pattern()
			
			next_zone_is_super = false
			super_light_warning_sent = false
			
		Zone.SUPER_LIGHT:
			# Super Light ALWAYS goes to Shadow (recovery)
			current_zone = Zone.SHADOW
			generate_shadow_pattern()
			next_zone_is_super = false
			super_light_warning_sent = false
	
	player.set_zone(current_zone)

func generate_shadow_pattern() -> void:
	obstacle_pattern = [
		ObstacleType.LOW, ObstacleType.LOW, ObstacleType.LOW,
		ObstacleType.LOW, ObstacleType.MEDIUM, ObstacleType.MEDIUM
	]
	obstacle_pattern.shuffle()
	pattern_index = 0

func generate_light_pattern() -> void:
	obstacle_pattern = [
		ObstacleType.LOW, ObstacleType.LOW,
		ObstacleType.MEDIUM, ObstacleType.MEDIUM,
		ObstacleType.TALL, ObstacleType.LOW
	]
	obstacle_pattern.shuffle()
	pattern_index = 0

func generate_super_pattern() -> void:
	obstacle_pattern = [
		ObstacleType.LOW,
		ObstacleType.MEDIUM, ObstacleType.MEDIUM,
		ObstacleType.TALL, ObstacleType.TALL, ObstacleType.TALL
	]
	obstacle_pattern.shuffle()
	pattern_index = 0

func spawn_obstacle_at_z(z_pos: float) -> void:
	# Get smoothly interpolated tier settings
	var tier_settings = get_interpolated_settings(player.distance_traveled)
	var tier = get_difficulty_tier(player.distance_traveled)
	
	# Use tier-based spawn chance
	var spawn_chance: float = tier_settings["spawn_chance"]
	
	if randf() > spawn_chance:
		spawns_since_last_double += 1
		last_spawn_blocked_lanes.clear()
		return
	
	# Track which lanes we block this spawn
	var blocked_lanes: Array[int] = []
	
	# Pick first lane randomly
	var lane_index = randi() % 3
	var lane_x = LANES[lane_index] * LANE_WIDTH
	blocked_lanes.append(lane_index)
	
	var obs_type = get_next_obstacle_type()
	
	# TIER GATING: Clamp obstacle size to tier's max allowed
	var max_size = tier_settings["max_size"]
	if obs_type > max_size:
		obs_type = max_size
	
	# Pre-determine if this obstacle will likely have a coin arc
	var coin_chance: float
	match current_zone:
		Zone.SHADOW:
			coin_chance = 0.4
		Zone.LIGHT:
			coin_chance = 0.65
		Zone.SUPER_LIGHT:
			coin_chance = 0.85
		_:
			coin_chance = 0.5  # P1 fix: safe default
	var will_have_coins = randf() < coin_chance
	
	# Create obstacle - make it WIDE if coins will arc over it (for visibility)
	var obstacle = create_obstacle(obs_type, will_have_coins)
	obstacle.position = Vector3(lane_x, get_obstacle_y(obs_type), z_pos)
	obstacle.set_meta("will_have_coins", will_have_coins)
	add_child(obstacle)
	obstacles.append(obstacle)
	
	# TIER GATING: Only allow doubles if tier permits AND cooldown passed
	if not tier_settings["doubles"]:
		spawns_since_last_double += 1
		last_spawn_blocked_lanes = blocked_lanes
		return
	
	if spawns_since_last_double < DOUBLE_COOLDOWN:
		spawns_since_last_double += 1
		last_spawn_blocked_lanes = blocked_lanes
		return
	
	# Tier-based double chance (much lower than before)
	var double_chance: float
	match tier:
		Tier.CORE:
			double_chance = 0.10  # 10% in CORE
		Tier.SKILLED:
			double_chance = 0.15  # 15% in SKILLED
		Tier.EXPERT:
			double_chance = 0.20  # 20% in EXPERT
		_:
			double_chance = 0.0
	
	if randf() < double_chance:
		# SAFE LANE GUARANTEE: Only block ONE additional lane, leaving one safe
		var available_lanes: Array[int] = []
		for i in range(3):
			if i != lane_index:
				available_lanes.append(i)
		
		# Pick one of the two remaining lanes (never both!)
		var other_lane = available_lanes[randi() % available_lanes.size()]
		var other_x = LANES[other_lane] * LANE_WIDTH
		blocked_lanes.append(other_lane)
		
		var obstacle2 = create_obstacle(obs_type, false)
		obstacle2.position = Vector3(other_x, get_obstacle_y(obs_type), z_pos)
		add_child(obstacle2)
		obstacles.append(obstacle2)
		
		spawns_since_last_double = 0  # Reset cooldown
	else:
		spawns_since_last_double += 1
	
	last_spawn_blocked_lanes = blocked_lanes

func get_obstacle_y(obs_type: int) -> float:
	match obs_type:
		ObstacleType.LOW:
			return 0.75
		ObstacleType.MEDIUM:
			return 1.25
		ObstacleType.TALL:
			return 2.0
	return 1.0

func create_obstacle(obs_type: int, wide: bool = false) -> Area3D:
	var obstacle = Area3D.new()
	obstacle.add_to_group("obstacles")
	
	var height: float
	match obs_type:
		ObstacleType.LOW:
			height = 1.0
		ObstacleType.MEDIUM:
			height = 1.8
		ObstacleType.TALL:
			height = 3.0
	
	obstacle.set_meta("obstacle_height", height)
	obstacle.set_meta("is_wide", wide)
	
	# Pick a random obstacle type based on size
	var obstacle_variant = randi() % 5
	
	match obs_type:
		ObstacleType.LOW:
			# Small debris: small asteroids, cargo crates, barrels
			match obstacle_variant % 3:
				0: create_small_asteroid(obstacle)
				1: create_cargo_crate(obstacle)
				2: create_barrel_cluster(obstacle)
		ObstacleType.MEDIUM:
			# Medium obstacles: asteroids, broken cannons, anchors
			match obstacle_variant % 4:
				0: create_medium_asteroid(obstacle)
				1: create_broken_cannon(obstacle)
				2: create_anchor(obstacle)
				3: create_ship_debris(obstacle)
		ObstacleType.TALL:
			# Tall obstacles: large asteroids, mast sections, hull pieces
			match obstacle_variant % 3:
				0: create_large_asteroid(obstacle)
				1: create_broken_mast(obstacle)
				2: create_hull_section(obstacle)
	
	# Add collision based on height - WIDER if coin arc obstacle
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	var width = 2.4 if wide else 1.4  # Wide obstacles are more visible
	box_shape.size = Vector3(width, height * 0.9, 0.6)
	collision.shape = box_shape
	obstacle.add_child(collision)
	
	# Scale the obstacle mesh wider if needed
	if wide:
		for child in obstacle.get_children():
			if child is MeshInstance3D:
				child.scale.x *= 1.6  # Make visually wider
	
	return obstacle

# ============ LOW OBSTACLES ============
func create_small_asteroid(parent: Node3D) -> void:
	# Lumpy asteroid - scaled up 30%
	var core = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.2
	core.mesh = sm
	core.position.y = 0.6
	core.material_override = mat_rock
	parent.add_child(core)
	
	# Extra chunks for lumpiness
	for i in range(2):
		var chunk = MeshInstance3D.new()
		var cm = SphereMesh.new()
		cm.radius = 0.4
		cm.height = 0.7
		chunk.mesh = cm
		chunk.position = Vector3(0.45 if i == 0 else -0.45, 0.5, 0.15)
		chunk.material_override = mat_rock
		parent.add_child(chunk)

func create_cargo_crate(parent: Node3D) -> void:
	# Crate scaled up 30%
	var crate = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(1.3, 1.2, 1.0)
	crate.mesh = bm
	crate.position.y = 0.6
	crate.rotation_degrees.y = randf() * 15
	crate.material_override = mat_wood
	parent.add_child(crate)
	
	# Metal bands
	for i in range(2):
		var band = MeshInstance3D.new()
		var bandm = BoxMesh.new()
		bandm.size = Vector3(1.35, 0.12, 1.05)
		band.mesh = bandm
		band.position.y = 0.3 + i * 0.6
		band.material_override = mat_metal
		parent.add_child(band)

func create_barrel_cluster(parent: Node3D) -> void:
	# Barrels scaled up 30%
	for i in range(2):
		var barrel = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.5
		cm.height = 1.2
		barrel.mesh = cm
		barrel.position = Vector3(i * 0.65 - 0.32, 0.6, 0)
		barrel.rotation_degrees.z = (randf() * 10 - 5) if i == 1 else 0.0
		barrel.material_override = mat_wood
		parent.add_child(barrel)
		
		# Metal rings
		for j in range(2):
			var ring = MeshInstance3D.new()
			var rm = TorusMesh.new()
			rm.inner_radius = 0.42
			rm.outer_radius = 0.52
			ring.mesh = rm
			ring.position = Vector3(i * 0.65 - 0.32, 0.25 + j * 0.7, 0)
			ring.rotation_degrees.x = 90
			ring.material_override = mat_metal
			parent.add_child(ring)

# ============ MEDIUM OBSTACLES ============
func create_medium_asteroid(parent: Node3D) -> void:
	# Medium asteroid - fills 0 to 1.8 height
	var core = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	core.mesh = sm
	core.position.y = 0.9
	core.material_override = mat_rock
	parent.add_child(core)
	
	# Extra chunks for lumpiness
	for i in range(3):
		var chunk = MeshInstance3D.new()
		var cm = SphereMesh.new()
		cm.radius = 0.35
		cm.height = 0.6
		chunk.mesh = cm
		var angle = i * TAU / 3
		chunk.position = Vector3(cos(angle) * 0.5, 0.5 + i * 0.4, sin(angle) * 0.3)
		chunk.material_override = mat_rock
		parent.add_child(chunk)

func create_broken_cannon(parent: Node3D) -> void:
	# Cannon barrel - angled to reach 1.8 height
	var barrel = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.25
	cm.height = 1.6
	barrel.mesh = cm
	barrel.position.y = 0.9
	barrel.rotation_degrees.z = 50
	barrel.material_override = mat_iron
	parent.add_child(barrel)
	
	# Cannon base
	var base = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.8, 0.5, 0.6)
	base.mesh = bm
	base.position.y = 0.25
	base.material_override = mat_iron
	parent.add_child(base)
	
	# Wheels
	for i in range(2):
		var wheel = MeshInstance3D.new()
		var wm = TorusMesh.new()
		wm.inner_radius = 0.2
		wm.outer_radius = 0.35
		wheel.mesh = wm
		wheel.position = Vector3(0.5 if i == 0 else -0.5, 0.35, 0)
		wheel.rotation_degrees.y = 90
		wheel.material_override = mat_iron
		parent.add_child(wheel)

func create_anchor(parent: Node3D) -> void:
	# Anchor shaft - fills 0 to 1.8 height
	var shaft = MeshInstance3D.new()
	var sm = CylinderMesh.new()
	sm.top_radius = 0.1
	sm.bottom_radius = 0.1
	sm.height = 1.5
	shaft.mesh = sm
	shaft.position.y = 0.75
	shaft.material_override = mat_iron
	parent.add_child(shaft)
	
	# Anchor ring at top
	var ring = MeshInstance3D.new()
	var rm = TorusMesh.new()
	rm.inner_radius = 0.15
	rm.outer_radius = 0.25
	ring.mesh = rm
	ring.position.y = 1.6
	ring.rotation_degrees.x = 90
	ring.material_override = mat_iron
	parent.add_child(ring)
	
	# Anchor arms (flukes) - bigger
	for i in range(2):
		var arm = MeshInstance3D.new()
		var am = PrismMesh.new()
		am.size = Vector3(0.7, 0.15, 0.3)
		arm.mesh = am
		arm.position = Vector3(0.35 if i == 0 else -0.35, 0.2, 0)
		arm.rotation_degrees.z = 40 if i == 0 else -40
		arm.material_override = mat_iron
		parent.add_child(arm)
	
	# Cross bar
	var cross = MeshInstance3D.new()
	var crossm = CylinderMesh.new()
	crossm.top_radius = 0.06
	crossm.bottom_radius = 0.06
	crossm.height = 0.8
	cross.mesh = crossm
	cross.position.y = 1.2
	cross.rotation_degrees.z = 90
	cross.material_override = mat_iron
	parent.add_child(cross)

func create_ship_debris(parent: Node3D) -> void:
	# Broken planks filling 0 to 1.8 height
	for i in range(5):
		var plank = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(0.2, 1.0 + randf() * 0.5, 0.1)
		plank.mesh = pm
		plank.position = Vector3(randf() * 0.8 - 0.4, 0.6 + randf() * 0.4, randf() * 0.3 - 0.15)
		plank.rotation_degrees = Vector3(randf() * 25, randf() * 30, randf() * 15)
		plank.material_override = mat_wood
		parent.add_child(plank)

# ============ TALL OBSTACLES ============
func create_large_asteroid(parent: Node3D) -> void:
	# Large asteroid - fills 0 to 3.0 height
	var core = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 1.2
	sm.height = 2.4
	core.mesh = sm
	core.position.y = 1.5
	core.material_override = mat_rock
	parent.add_child(core)
	
	# Jagged chunks around core
	for i in range(5):
		var chunk = MeshInstance3D.new()
		var cm = SphereMesh.new()
		cm.radius = 0.4 + randf() * 0.3
		cm.height = cm.radius * 1.8
		chunk.mesh = cm
		var angle = i * TAU / 5
		chunk.position = Vector3(cos(angle) * 0.8, 0.6 + i * 0.5, sin(angle) * 0.5)
		chunk.material_override = mat_rock
		parent.add_child(chunk)

func create_broken_mast(parent: Node3D) -> void:
	# Broken mast pole - fills 0 to 3.0 height
	var mast = MeshInstance3D.new()
	var mm = CylinderMesh.new()
	mm.top_radius = 0.12
	mm.bottom_radius = 0.2
	mm.height = 3.0
	mast.mesh = mm
	mast.position.y = 1.5
	mast.rotation_degrees.z = 8
	mast.material_override = mat_wood
	parent.add_child(mast)
	
	# Tattered sail fragment
	var sail = MeshInstance3D.new()
	var sm = BoxMesh.new()
	sm.size = Vector3(0.08, 1.8, 1.2)
	sail.mesh = sm
	sail.position = Vector3(0.4, 1.8, 0)
	sail.rotation_degrees = Vector3(0, 0, 15)
	sail.material_override = mat_sail
	parent.add_child(sail)
	
	# Cross beam
	var beam = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.08
	bm.bottom_radius = 0.08
	bm.height = 1.4
	beam.mesh = bm
	beam.position.y = 2.5
	beam.rotation_degrees.z = 90
	beam.material_override = mat_wood
	parent.add_child(beam)

func create_hull_section(parent: Node3D) -> void:
	# Hull section - fills 0 to 3.0 height
	for i in range(6):
		var plank = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(1.4, 0.2, 0.15)
		plank.mesh = pm
		plank.position.y = 0.25 + i * 0.5
		plank.rotation_degrees.x = -8 + i * 3
		plank.material_override = mat_wood
		parent.add_child(plank)
	
	# Metal reinforcement bands
	for i in range(2):
		var band = MeshInstance3D.new()
		var bandm = BoxMesh.new()
		bandm.size = Vector3(1.5, 0.12, 0.2)
		band.mesh = bandm
		band.position.y = 0.8 + i * 1.2
		band.material_override = mat_metal
		parent.add_child(band)
	
	# Broken porthole
	var port = MeshInstance3D.new()
	var portm = TorusMesh.new()
	portm.inner_radius = 0.18
	portm.outer_radius = 0.28
	port.mesh = portm
	port.position = Vector3(0, 2.2, 0.15)
	port.material_override = mat_metal
	parent.add_child(port)

func spawn_coins_at_z(z_pos: float) -> void:
	# ZONE-BASED COIN DISTRIBUTION
	# SHADOW: 70% - reward for surviving the dark
	# LIGHT: 40% - already busy enough
	# SUPER_LIGHT: Ground coins only in safe lane (no arcs, no distractions)
	
	match current_zone:
		Zone.SUPER_LIGHT:
			# Super light = survival mode. Only safe-lane ground coins as bonus
			if randf() < 0.25:  # 25% chance
				spawn_safe_lane_coins(z_pos)
			return
		Zone.LIGHT:
			if randf() > 0.40:  # 40% chance to spawn
				return
		Zone.SHADOW:
			if randf() > 0.70:  # 70% chance to spawn
				return
		_:
			return  # P1 fix: unknown zone, skip coin spawn
	
	# Check if there's a nearby obstacle marked for coin arc
	var nearby_obstacle: Node3D = null
	var obstacle_height: float = 0.0
	var obstacle_lane: int = -1
	
	for obs in obstacles:
		var z_dist = abs(obs.position.z - z_pos)
		if z_dist < 2.0:  # Tighter range - must be very close to obstacle
			# Only spawn coins over obstacles that were marked for it
			if obs.get_meta("will_have_coins", false):
				nearby_obstacle = obs
				obstacle_height = obs.get_meta("obstacle_height", 2.0)
				# Figure out which lane the obstacle is in
				var obs_x = obs.position.x
				for i in range(3):
					if abs(LANES[i] * LANE_WIDTH - obs_x) < 1.0:
						obstacle_lane = i
						break
				# Clear the flag so we don't spawn twice
				obs.set_meta("will_have_coins", false)
			break
	
	if nearby_obstacle and obstacle_lane >= 0:
		# Spawn arc over obstacle - reward for jumping!
		spawn_coin_arc(obstacle_lane, nearby_obstacle.position.z, obstacle_height)
	else:
		# No marked obstacle nearby - spawn ground-level coins
		spawn_ground_coins(z_pos)

func spawn_safe_lane_coins(z_pos: float) -> void:
	# Find the safe lane (lane without obstacle at this z)
	var blocked_lanes: Array[int] = []
	
	for obs in obstacles:
		var z_dist = abs(obs.position.z - z_pos)
		if z_dist < 5.0:
			var obs_x = obs.position.x
			for i in range(3):
				if abs(LANES[i] * LANE_WIDTH - obs_x) < 1.5:
					if i not in blocked_lanes:
						blocked_lanes.append(i)
	
	# Find a safe lane
	var safe_lane: int = -1
	for i in range(3):
		if i not in blocked_lanes:
			safe_lane = i
			break
	
	if safe_lane < 0:
		return  # No safe lane found, skip coins
	
	# Spawn a small trail of ground coins in safe lane
	var lane_x = LANES[safe_lane] * LANE_WIDTH
	for i in range(3):
		var coin = create_coin()
		coin.position = Vector3(lane_x, 1.5, z_pos - i * 1.5)
		add_child(coin)
		coins.append(coin)

func spawn_coin_arc(lane_index: int, z_pos: float, obstacle_height: float) -> void:
	var lane_x = LANES[lane_index] * LANE_WIDTH
	
	# Arc should trace a collectible path matching a BASE JUMP trajectory
	# Base jump: force=12, gravity=40 → peak = v²/(2g) = 144/80 = 1.8m above launch
	# Player launches from y≈1.0, so peak y ≈ 2.8
	# Boost jump goes higher, so base-jump arcs reward normal play,
	# boost-jump players scoop them easily
	
	# Coin arc peak = just above the obstacle top, capped to base jump reach
	var base_jump_peak: float = 2.8  # What a normal jump actually reaches
	var min_clearance: float = 0.3  # Coins sit just above obstacle top
	var peak_height: float = min(obstacle_height + min_clearance + 0.8, base_jump_peak)
	
	# Arc length scales with forward speed — player is moving ~20 units/s,
	# jump duration ≈ 2*v/g = 24/40 = 0.6s, so Z travel ≈ 12m
	var arc_length = 8.0 + obstacle_height * 1.5
	var arc_coins = 5 + int(obstacle_height * 2.0)
	
	# Thornveil bonus
	if player and player.rider_perk == "lucky":
		arc_coins += 3
	
	# Create arc of coins
	for i in range(arc_coins):
		var t = float(i) / float(arc_coins - 1) if arc_coins > 1 else 0.5
		
		# Parabolic arc: y = peak * (1 - (2t-1)^2) = peak * (4t - 4t^2)
		var arc_y = peak_height * 4.0 * t * (1.0 - t)
		var arc_z = z_pos - (t - 0.5) * arc_length
		
		# Minimum height so coins aren't underground
		arc_y = max(arc_y, 1.5)
		
		var coin = create_coin()
		coin.position = Vector3(lane_x, arc_y, arc_z)
		add_child(coin)
		coins.append(coin)

func spawn_ground_coins(z_pos: float) -> void:
	# Simple ground-level coins for areas without obstacles
	var lane_index = randi() % 3
	var lane_x = LANES[lane_index] * LANE_WIDTH
	
	var num_coins: int
	match current_zone:
		Zone.SHADOW:
			num_coins = randi_range(1, 2)
		Zone.LIGHT:
			num_coins = randi_range(2, 3)
		Zone.SUPER_LIGHT:
			num_coins = randi_range(2, 4)
		_:
			num_coins = 2  # P1 fix: safe default
	
	if player and player.rider_perk == "lucky":
		num_coins += 1
	
	for i in range(num_coins):
		var coin = create_coin()
		coin.position = Vector3(lane_x, 1.5, z_pos - i * 2.0)
		add_child(coin)
		coins.append(coin)

func create_coin() -> Area3D:
	var coin = Area3D.new()
	coin.add_to_group("coins")
	
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision.shape = sphere_shape
	coin.add_child(collision)
	
	var mesh_instance = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.4
	cylinder_mesh.bottom_radius = 0.4
	cylinder_mesh.height = 0.1
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.rotation_degrees = Vector3(90, 0, 0)
	mesh_instance.material_override = mat_coin
	
	coin.add_child(mesh_instance)
	return coin

func cleanup_behind(player_z: float) -> void:
	var to_remove_obs: Array[Node3D] = []
	for obstacle in obstacles:
		if obstacle.position.z > player_z + despawn_behind_distance:
			to_remove_obs.append(obstacle)
	for obs in to_remove_obs:
		obstacles.erase(obs)
		obs.queue_free()
	
	var to_remove_coins: Array[Node3D] = []
	for coin in coins:
		if coin.position.z > player_z + despawn_behind_distance:
			to_remove_coins.append(coin)
	for c in to_remove_coins:
		coins.erase(c)
		c.queue_free()

func remove_coin(coin: Node3D) -> void:
	if coin in coins:
		coins.erase(coin)
		coin.queue_free()

func clear_all() -> void:
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	for coin in coins:
		coin.queue_free()
	coins.clear()
	next_spawn_z = -40.0
	current_zone = Zone.LIGHT
	zone_start_distance = 0.0
	next_zone_is_super = false
	super_light_warning_sent = false
	generate_light_pattern()
	
	# Reset storm
	distance_since_last_storm = 0.0
	next_storm_distance = 500.0
	if storm_hazard and storm_hazard.has_method("reset"):
		storm_hazard.reset()

func stop() -> void:
	is_active = false

func start() -> void:
	is_active = true
