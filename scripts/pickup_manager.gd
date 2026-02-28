extends Node3D

# Pickup Manager - spawns and manages powerups

var player: CharacterBody3D
var hud: CanvasLayer

enum PickupType { REPAIR, SHIELD, COIN_MAGNET }

# Pickup settings
const PICKUP_SPAWN_CHANCE: float = 0.08  # 8% chance per spawn check
const SPAWN_CHECK_DISTANCE: float = 80.0  # Check every 80m
const PICKUP_LANES: Array[int] = [-1, 0, 1]
const LANE_WIDTH: float = 3.0

# Active powerup states
var shield_active: bool = false
var shield_timer: float = 0.0
const SHIELD_DURATION: float = 5.0

var magnet_active: bool = false
var magnet_timer: float = 0.0
const MAGNET_DURATION: float = 8.0
const MAGNET_RANGE: float = 4.0

# Vol Kresh's shield regeneration
var kresh_shield_regen_timer: float = 0.0
const KRESH_SHIELD_REGEN_TIME: float = 15.0

# Coin magnet constants
const PASSIVE_MAGNET_BASE_RANGE: float = 6.0
const PASSIVE_MAGNET_BASE_SPEED: float = 20.0

# Spawning
var next_spawn_check_z: float = 100.0
var is_active: bool = false

# Signals
signal shield_activated
signal shield_deactivated
signal magnet_activated
signal magnet_deactivated
signal repair_collected

## Called by GameManager to inject references — no more get_parent() chains
func set_player(p: CharacterBody3D) -> void:
	player = p
	if player:
		is_active = true
		print("PickupManager initialized")
		
		# Vol Kresh's Unstoppable perk - start with free shield
		if player.rider_perk == "armor":
			call_deferred("activate_shield")
			print("Vol Kresh: Starting with free shield!")

func set_hud(h: CanvasLayer) -> void:
	hud = h

func _process(delta: float) -> void:
	if not is_active or not player or player.is_dead:
		return
	
	_update_shield_timer(delta)
	_update_magnet_timer(delta)
	check_spawn_pickup()
	check_pickup_collisions()
	
	# Coin attraction — active magnet powerup or Thornveil's passive
	if magnet_active:
		_attract_coins(MAGNET_RANGE, 15.0, 1.0, false)
	if player.rider_perk == "lucky":
		_attract_coins_thornveil()

# ============ POWERUP TIMERS ============
# Split into clear, single-purpose functions per audit recommendation

func _update_shield_timer(delta: float) -> void:
	if shield_active:
		# Vol Kresh's shield doesn't time out — only breaks on hit
		if player.rider_perk != "armor":
			shield_timer -= delta
			if shield_timer <= 0:
				deactivate_shield()
	else:
		# Vol Kresh's shield regenerates if engine is alive
		if player.rider_perk == "armor" and player.engine_intact:
			kresh_shield_regen_timer -= delta
			if kresh_shield_regen_timer <= 0:
				activate_shield()
				kresh_shield_regen_timer = KRESH_SHIELD_REGEN_TIME
				print("KRESH: Shield regenerated!")

func _update_magnet_timer(delta: float) -> void:
	if magnet_active:
		magnet_timer -= delta
		if magnet_timer <= 0:
			deactivate_magnet()

# ============ SPAWNING ============

func check_spawn_pickup() -> void:
	var player_z = player.position.z
	
	if player_z < next_spawn_check_z:
		return
	
	next_spawn_check_z -= SPAWN_CHECK_DISTANCE
	
	# Random chance to spawn
	if randf() < PICKUP_SPAWN_CHANCE:
		var spawn_z = player_z - 120.0  # Spawn ahead
		var lane = PICKUP_LANES[randi() % PICKUP_LANES.size()]
		var spawn_x = lane * LANE_WIDTH
		
		# Pick random pickup type, weighted by usefulness
		var pickup_type = choose_pickup_type()
		spawn_pickup(Vector3(spawn_x, 1.0, spawn_z), pickup_type)

func choose_pickup_type() -> int:
	var roll = randf()
	
	# If damaged, higher chance of repair
	if player.damage_level > 0:
		if roll < 0.5:
			return PickupType.REPAIR
		elif roll < 0.75:
			return PickupType.SHIELD
		else:
			return PickupType.COIN_MAGNET
	else:
		# Not damaged - no repair needed
		if roll < 0.5:
			return PickupType.SHIELD
		else:
			return PickupType.COIN_MAGNET

func spawn_pickup(pos: Vector3, type: int) -> void:
	var pickup = Node3D.new()
	pickup.position = pos
	pickup.add_to_group("pickups")
	pickup.set_meta("pickup_type", type)
	
	# Visual based on type
	var mesh_instance = MeshInstance3D.new()
	var mesh: Mesh
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.metallic = 0.8
	material.roughness = 0.2
	
	match type:
		PickupType.REPAIR:
			mesh = create_repair_mesh()
			material.albedo_color = Color(0.2, 1.0, 0.3)
			material.emission = Color(0.2, 1.0, 0.3)
			material.emission_energy_multiplier = 2.0
		PickupType.SHIELD:
			mesh = SphereMesh.new()
			mesh.radius = 0.5
			mesh.height = 1.0
			material.albedo_color = Color(0.3, 0.7, 1.0)
			material.emission = Color(0.3, 0.7, 1.0)
			material.emission_energy_multiplier = 2.0
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.7
		PickupType.COIN_MAGNET:
			mesh = TorusMesh.new()
			mesh.inner_radius = 0.2
			mesh.outer_radius = 0.5
			material.albedo_color = Color(1.0, 0.3, 1.0)
			material.emission = Color(1.0, 0.3, 1.0)
			material.emission_energy_multiplier = 2.0
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	pickup.add_child(mesh_instance)
	
	# Add rotation animation
	var spinner = Node3D.new()
	spinner.name = "Spinner"
	pickup.add_child(spinner)
	mesh_instance.reparent(spinner)
	
	add_child(pickup)
	
	# Animate rotation — tweens created on pickup so they die with it
	var spin_tween = pickup.create_tween().set_loops()
	spin_tween.tween_property(spinner, "rotation_degrees:y", 360.0, 2.0).from(0.0)
	
	# Bobbing animation — also owned by pickup
	var bob_tween = pickup.create_tween().set_loops()
	bob_tween.tween_property(mesh_instance, "position:y", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(mesh_instance, "position:y", -0.3, 0.5).set_trans(Tween.TRANS_SINE)

func create_repair_mesh() -> Mesh:
	# Create a "+" shape for repair using a box
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.8, 0.8, 0.2)
	return mesh

# ============ COLLECTION ============

func check_pickup_collisions() -> void:
	var player_pos = player.global_position
	
	for pickup in get_tree().get_nodes_in_group("pickups"):
		var pickup_pos = pickup.global_position
		var distance = player_pos.distance_to(pickup_pos)
		
		if distance < 1.5:
			collect_pickup(pickup)

func collect_pickup(pickup: Node3D) -> void:
	var type = pickup.get_meta("pickup_type", 0)
	
	match type:
		PickupType.REPAIR:
			apply_repair()
		PickupType.SHIELD:
			activate_shield()
		PickupType.COIN_MAGNET:
			activate_magnet()
	
	# Particle effect and remove
	emit_collect_effect(pickup.global_position, type)
	pickup.queue_free()

func apply_repair() -> void:
	if player.damage_level <= 0:
		return
	
	player.damage_level -= 1
	emit_signal("repair_collected")
	
	var surfer = player.get_node_or_null("SolarSurfer")
	
	if player.damage_level == 0:
		# Fully repaired
		player.sail_intact = true
		player.engine_intact = true
		if surfer and surfer.has_method("repair"):
			surfer.repair()
		print("FULLY REPAIRED!")
	elif player.damage_level == 1:
		# Engine repaired, sail still broken
		player.engine_intact = true
		if surfer and surfer.has_method("repair_engine"):
			surfer.repair_engine()
		print("ENGINE REPAIRED!")
	
	# Update HUD
	if hud and hud.has_method("show_repair"):
		hud.show_repair(player.damage_level)

# ============ SHIELD ============

func activate_shield() -> void:
	shield_active = true
	shield_timer = SHIELD_DURATION
	emit_signal("shield_activated")
	
	# Visual feedback
	var surfer = player.get_node_or_null("SolarSurfer")
	if surfer:
		create_shield_visual(surfer)
	
	print("SHIELD ACTIVE for ", SHIELD_DURATION, " seconds!")
	
	if hud and hud.has_method("show_powerup"):
		hud.show_powerup("SHIELD", SHIELD_DURATION, Color(0.3, 0.7, 1.0))

func deactivate_shield() -> void:
	shield_active = false
	shield_timer = 0.0
	emit_signal("shield_deactivated")
	
	# Remove visual
	_remove_shield_visual()
	
	# Start Kresh's regen timer
	if player.rider_perk == "armor":
		kresh_shield_regen_timer = KRESH_SHIELD_REGEN_TIME
		print("KRESH: Shield broken! Regenerating in ", KRESH_SHIELD_REGEN_TIME, "s...")
	else:
		print("Shield expired!")

func create_shield_visual(parent: Node3D) -> void:
	# Remove existing shield if any
	var existing = parent.get_node_or_null("ShieldBubble")
	if existing:
		existing.queue_free()
	
	var shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "ShieldBubble"
	
	var sphere = SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	shield_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = mat
	
	parent.add_child(shield_mesh)
	shield_mesh.position = Vector3(0, 0.5, 0)

func _remove_shield_visual() -> void:
	if not player:
		return
	var surfer = player.get_node_or_null("SolarSurfer")
	if surfer:
		var shield_mesh = surfer.get_node_or_null("ShieldBubble")
		if shield_mesh:
			shield_mesh.queue_free()

# ============ MAGNET ============

func activate_magnet() -> void:
	magnet_active = true
	magnet_timer = MAGNET_DURATION
	emit_signal("magnet_activated")
	
	print("COIN MAGNET ACTIVE for ", MAGNET_DURATION, " seconds!")
	
	if hud and hud.has_method("show_powerup"):
		hud.show_powerup("MAGNET", MAGNET_DURATION, Color(1.0, 0.3, 1.0))

func deactivate_magnet() -> void:
	magnet_active = false
	magnet_timer = 0.0
	emit_signal("magnet_deactivated")
	print("Magnet expired!")

# ============ COIN ATTRACTION ============
# Unified magnet logic — powerup and Thornveil's passive use the same core

func _attract_coins(attract_range: float, pull_speed: float, pull_factor_mult: float, offset_y: bool) -> void:
	var player_pos = player.global_position
	if offset_y:
		player_pos.y += 1.0  # Account for coin height in passive mode
	
	var dt = get_process_delta_time()
	
	for coin in get_tree().get_nodes_in_group("coins"):
		var coin_pos = coin.global_position
		var distance = player_pos.distance_to(coin_pos)
		
		if distance < attract_range and distance > 0.01:
			var pull_factor = 1.0 + (1.0 - distance / attract_range) * 2.0 * pull_factor_mult
			var direction = (player_pos - coin_pos).normalized()
			coin.global_position += direction * pull_speed * pull_factor * dt

## Thornveil's Gambler's Tongue — passive attraction that scales with speed
func _attract_coins_thornveil() -> void:
	var speed_multiplier = player.forward_speed / 30.0
	var effective_range = PASSIVE_MAGNET_BASE_RANGE * (1.0 + speed_multiplier * 0.5)
	var effective_speed = PASSIVE_MAGNET_BASE_SPEED * (1.0 + speed_multiplier * 0.8)
	_attract_coins(effective_range, effective_speed, 1.0, true)

func is_shielded() -> bool:
	return shield_active

# ============ EFFECTS ============

func emit_collect_effect(pos: Vector3, type: int) -> void:
	var particles_node = GPUParticles3D.new()
	particles_node.amount = 20
	particles_node.lifetime = 0.5
	particles_node.one_shot = true
	particles_node.explosiveness = 0.9
	particles_node.emitting = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 6.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 0.1
	material.scale_max = 0.25
	
	match type:
		PickupType.REPAIR:
			material.color = Color(0.2, 1.0, 0.3)
		PickupType.SHIELD:
			material.color = Color(0.3, 0.7, 1.0)
		PickupType.COIN_MAGNET:
			material.color = Color(1.0, 0.3, 1.0)
	
	particles_node.process_material = material
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	particles_node.draw_pass_1 = mesh
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	
	get_parent().add_child(particles_node)
	particles_node.global_position = pos
	
	# Cleanup
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(particles_node.queue_free)

# ============ RESET ============

func reset() -> void:
	# Clear powerup state
	shield_active = false
	shield_timer = 0.0
	magnet_active = false
	magnet_timer = 0.0
	kresh_shield_regen_timer = 0.0
	next_spawn_check_z = 100.0
	
	# Remove shield visual if lingering from previous run
	_remove_shield_visual()
	
	# Clear all pickups
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	
	# Vol Kresh starts each run with a free shield
	if player and player.rider_perk == "armor":
		call_deferred("activate_shield")
