extends Node3D

# Micrometeorite Storm - Rotating Environmental Hazard
# "A rotating saw made of sand and glass"
# 
# Physics turned hostile. Control beats speed. Panic kills.

var player: CharacterBody3D
var is_active: bool = false

# Storm configuration
const STORM_LENGTH: float = 80.0  # How long the storm zone is
const STORM_ROTATION_SPEED: float = 0.3  # Radians per second (base)
const BAND_COUNT: int = 5  # Number of particle bands
const GAP_ANGLE: float = 0.8  # Size of safe gaps in radians (~45 degrees)

# Difficulty scaling
var current_rotation_speed: float = STORM_ROTATION_SPEED
var speed_tier_multiplier: float = 1.0

# Storm state
var storm_active: bool = false
var storm_start_z: float = 0.0
var storm_end_z: float = 0.0
var storm_rotation: float = 0.0
var bands: Array[Dictionary] = []

# Visual components
var storm_container: Node3D
var particle_systems: Array[GPUParticles3D] = []

# Near miss tracking
var last_near_miss_time: float = 0.0
const NEAR_MISS_COOLDOWN: float = 0.3

# Signals
signal storm_entered
signal storm_exited
signal storm_hit
signal storm_near_miss

func _ready() -> void:
	call_deferred("initialize")

func initialize() -> void:
	player = get_parent().get_node_or_null("Player")
	if player:
		is_active = true
		# Connect to speed tier changes
		if player.has_signal("speed_tier_changed"):
			player.speed_tier_changed.connect(_on_speed_tier_changed)

func _process(delta: float) -> void:
	if not is_active or not player or player.is_dead:
		return
	
	if storm_active:
		update_storm(delta)
		check_storm_collision()
		check_storm_exit()

func _on_speed_tier_changed(tier: int) -> void:
	# Storm rotates faster at higher speed tiers
	speed_tier_multiplier = 1.0 + (tier * 0.15)

# ============ STORM SPAWNING ============

func spawn_storm(z_position: float, difficulty: float = 1.0) -> void:
	if storm_active:
		return
	
	storm_active = true
	storm_start_z = z_position
	storm_end_z = z_position - STORM_LENGTH
	storm_rotation = 0.0
	current_rotation_speed = STORM_ROTATION_SPEED * difficulty * speed_tier_multiplier
	
	# Create storm container
	storm_container = Node3D.new()
	storm_container.position = Vector3(0, 0, z_position - STORM_LENGTH / 2)
	add_child(storm_container)
	
	# Generate bands with gaps
	bands.clear()
	particle_systems.clear()
	
	for i in range(BAND_COUNT):
		var band = {
			"angle_start": (TAU / BAND_COUNT) * i,
			"angle_end": (TAU / BAND_COUNT) * i + (TAU / BAND_COUNT) - GAP_ANGLE,
			"radius_inner": 1.5,  # Inner edge (close to center lane)
			"radius_outer": 5.0,  # Outer edge (covers all lanes)
			"active": true
		}
		bands.append(band)
		
		# Create particle system for this band
		var particles = create_band_particles(band, i)
		particle_systems.append(particles)
	
	emit_signal("storm_entered")
	print("MICROMETEORITE STORM: Entered at z=", z_position)

func create_band_particles(band: Dictionary, _index: int) -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.amount = 150
	particles.lifetime = 0.6
	particles.explosiveness = 0.0
	particles.randomness = 0.2
	particles.local_coords = false  # World coords so they're visible
	particles.emitting = true
	
	var material = ParticleProcessMaterial.new()
	
	# Fast streaks moving toward player
	material.direction = Vector3(0, 0, 1)  # Toward player (positive Z)
	material.spread = 10.0
	material.initial_velocity_min = 60.0
	material.initial_velocity_max = 100.0
	
	# Emission in wider area
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(4.0, 2.0, 20.0)
	
	# Color: bright ember streaks - VISIBLE
	material.color = Color(1.0, 0.7, 0.4, 1.0)
	
	# Scale: visible streaks, not razor-fine
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	particles.process_material = material
	
	# Mesh: stretched quad for streak effect - BIGGER
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.15, 1.5)  # Visible streaks
	particles.draw_pass_1 = mesh
	
	# Material for the mesh - GLOWING
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(1.0, 0.8, 0.5)
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(1.0, 0.6, 0.3)
	mesh_mat.emission_energy_multiplier = 4.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.material_override = mesh_mat
	
	# Position based on band angle - spread across lanes
	var angle = band.angle_start + (band.angle_end - band.angle_start) / 2
	var radius = (band.radius_inner + band.radius_outer) / 2
	particles.position = Vector3(cos(angle) * radius * 2, 2.0, 0)  # Raised up, spread out
	
	storm_container.add_child(particles)
	return particles

# ============ STORM UPDATE ============

func update_storm(delta: float) -> void:
	# Rotate the entire storm
	storm_rotation += current_rotation_speed * delta
	
	if storm_container:
		storm_container.rotation.z = storm_rotation
		
		# Update particle positions to follow rotation
		for i in range(bands.size()):
			if i < particle_systems.size() and bands[i].active:
				var band = bands[i]
				var angle = band.angle_start + storm_rotation + (band.angle_end - band.angle_start) / 2
				var radius = (band.radius_inner + band.radius_outer) / 2
				particle_systems[i].position = Vector3(cos(angle) * radius, sin(angle) * radius, 0)

# ============ COLLISION ============

func check_storm_collision() -> void:
	var player_pos = player.global_position
	var player_z = player_pos.z
	
	# Only check if player is inside storm zone
	if player_z > storm_start_z or player_z < storm_end_z:
		return
	
	# Convert player X position to angle from center
	var player_x = player_pos.x
	var player_y = player_pos.y
	var player_angle = atan2(player_y, player_x)
	if player_angle < 0:
		player_angle += TAU
	
	var player_radius = sqrt(player_x * player_x + player_y * player_y)
	
	# Check each band
	for i in range(bands.size()):
		var band = bands[i]
		if not band.active:
			continue
		
		# Adjust band angles for current rotation
		var band_start = fmod(band.angle_start + storm_rotation, TAU)
		var band_end = fmod(band.angle_end + storm_rotation, TAU)
		if band_start < 0:
			band_start += TAU
		if band_end < 0:
			band_end += TAU
		
		# Check if player is within band's radius
		if player_radius < band.radius_inner or player_radius > band.radius_outer:
			continue
		
		# Check if player angle is within band (accounting for wraparound)
		var in_band = false
		if band_start < band_end:
			in_band = player_angle >= band_start and player_angle <= band_end
		else:
			# Band wraps around 0
			in_band = player_angle >= band_start or player_angle <= band_end
		
		if in_band:
			handle_storm_hit(i)
			return
		else:
			# Check for near miss
			var dist_to_band = min(
				abs(angle_difference(player_angle, band_start)),
				abs(angle_difference(player_angle, band_end))
			)
			if dist_to_band < 0.15 and Time.get_ticks_msec() / 1000.0 - last_near_miss_time > NEAR_MISS_COOLDOWN:
				handle_near_miss()

func angle_difference(a: float, b: float) -> float:
	var diff = a - b
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff

func handle_storm_hit(band_index: int) -> void:
	# Check for curse interactions first
	
	# Mary Korr - chance to phase through
	if player.rider_perk == "path_sight":
		var phase_chance = 0.15 + player.path_sight_bonus
		if randf() < phase_chance:
			show_phase_effect()
			emit_signal("storm_near_miss")
			print("MARY KORR: Phased through meteorite band!")
			return
	
	# Vol Kresh - shatters the band on impact (still takes hit but destroys threat)
	if player.rider_perk == "armor":
		bands[band_index].active = false
		if band_index < particle_systems.size():
			particle_systems[band_index].emitting = false
		print("VOL KRESH: Shattered meteorite band!")
		# Still takes the hit below
	
	# Silas Thornveil - small chance band vanishes
	if player.rider_perk == "lucky":
		if randf() < 0.1:  # 10% chance
			bands[band_index].active = false
			if band_index < particle_systems.size():
				particle_systems[band_index].emitting = false
			print("THORNVEIL: Luck bends reality - band vanishes!")
			return
	
	# Apply damage
	emit_signal("storm_hit")
	show_impact_effect()
	
	# Get references
	var game_manager = get_parent()
	var pickups = game_manager.get_node_or_null("PickupManager")
	var hud = game_manager.get_node_or_null("HUD")
	var juice = game_manager.get_node_or_null("JuiceManager")
	var particles_mgr = game_manager.get_node_or_null("ParticleManager")
	
	# Check shield first
	if pickups and pickups.is_shielded():
		pickups.deactivate_shield()
		if juice:
			juice.on_damage(0)
		if hud:
			hud.show_shield_break()
		print("STORM: Shield absorbed meteorite impact!")
		return
	
	# Take damage
	player.take_damage()
	if juice:
		juice.on_damage(player.damage_level)
	if hud:
		hud.show_damage(player.damage_level)
	if particles_mgr and particles_mgr.has_method("emit_damage_sparks"):
		particles_mgr.emit_damage_sparks()

func handle_near_miss() -> void:
	last_near_miss_time = Time.get_ticks_msec() / 1000.0
	emit_signal("storm_near_miss")
	
	# Jubari - near misses grant speed burst
	if player.rider_perk == "shadow_resist":
		# Temporary speed boost
		player.forward_speed *= 1.1
		print("JUBARI: Near miss speed burst!")
	
	var juice = get_parent().get_node_or_null("JuiceManager")
	if juice and juice.has_method("on_near_miss"):
		juice.on_near_miss()
	
	show_near_miss_effect()

# ============ EFFECTS ============

func show_impact_effect() -> void:
	# Metallic spark burst
	var sparks = GPUParticles3D.new()
	sparks.amount = 30
	sparks.lifetime = 0.3
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = true
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 90.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -5, 0)
	mat.color = Color(1.0, 0.7, 0.4)
	sparks.process_material = mat
	
	sparks.global_position = player.global_position
	get_parent().add_child(sparks)
	
	# Auto cleanup
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): sparks.queue_free())

func show_near_miss_effect() -> void:
	# Light flash
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		var flash = hud.get_node_or_null("ScreenFlash")
		if flash:
			flash.color = Color(1.0, 0.9, 0.7, 0.15)
			var tween = create_tween()
			tween.tween_property(flash, "color:a", 0.0, 0.2)

func show_phase_effect() -> void:
	# Purple shimmer for Mary's phase
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		var flash = hud.get_node_or_null("ScreenFlash")
		if flash:
			flash.color = Color(0.6, 0.5, 0.8, 0.25)
			var tween = create_tween()
			tween.tween_property(flash, "color:a", 0.0, 0.3)
		if hud.has_method("show_path_sight"):
			hud.show_path_sight()

# ============ STORM EXIT ============

func check_storm_exit() -> void:
	if player.position.z < storm_end_z:
		end_storm()

func end_storm() -> void:
	storm_active = false
	emit_signal("storm_exited")
	
	# Cleanup
	if storm_container:
		storm_container.queue_free()
		storm_container = null
	
	bands.clear()
	particle_systems.clear()
	
	print("MICROMETEORITE STORM: Exited safely!")

# ============ EXTERNAL INTERFACE ============

func is_storm_active() -> bool:
	return storm_active

func get_storm_progress() -> float:
	if not storm_active:
		return 0.0
	var total = storm_start_z - storm_end_z
	var progress = storm_start_z - player.position.z
	return clamp(progress / total, 0.0, 1.0)

func reset() -> void:
	if storm_container:
		storm_container.queue_free()
		storm_container = null
	storm_active = false
	bands.clear()
	particle_systems.clear()
