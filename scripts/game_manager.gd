extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $GameCamera
@onready var obstacle_spawner: Node3D = $ObstacleSpawner
@onready var hud: CanvasLayer = $HUD
@onready var track: Node3D = $Track
@onready var juice: Node = $JuiceManager
@onready var particles: Node3D = $ParticleManager
@onready var pickups: Node3D = $PickupManager

const CAMERA_OFFSET: Vector3 = Vector3(0, 5, 10)
const CAMERA_LOOK_AHEAD: float = 15.0
const DEATH_CAMERA_OFFSET: Vector3 = Vector3(0, 8, 16)
const DEATH_CAMERA_LERP: float = 2.0

var is_game_over: bool = false
var death_timer: float = 0.0
const DEATH_PAUSE_TIME: float = 2.0

func _ready() -> void:
	player.died.connect(_on_player_died)
	player.charge_changed.connect(_on_charge_changed)
	player.distance_updated.connect(_on_distance_updated)
	player.coins_updated.connect(_on_coins_updated)
	player.speed_tier_changed.connect(_on_speed_tier_changed)
	player.zone_changed.connect(_on_zone_changed)
	player.sail_destroyed.connect(_on_sail_destroyed)
	player.engine_destroyed.connect(_on_engine_destroyed)
	player.phoenix_revived.connect(_on_phoenix_revived)
	
	# Connect warning signal
	obstacle_spawner.super_light_incoming.connect(_on_super_light_incoming)
	
	# Connect death menu touch buttons
	hud.restart_requested.connect(restart_game)
	hud.menu_requested.connect(return_to_menu)
	
	obstacle_spawner.set_player(player)
	obstacle_spawner.set_hud(hud)
	var storm_node = get_node_or_null("StormHazard")
	if storm_node:
		obstacle_spawner.set_storm_hazard(storm_node)
	pickups.set_player(player)
	pickups.set_hud(hud)
	particles.set_player(player)
	particles.set_camera(camera)
	juice.set_player(player)
	juice.set_camera(camera)
	track.set_player(player)
	update_camera_instant()
	
	_on_charge_changed(player.solar_charge)
	_on_coins_updated(0)
	_on_zone_changed(1)

func _process(delta: float) -> void:
	if is_game_over:
		death_timer += delta
		update_death_camera(delta)
		
		if death_timer >= DEATH_PAUSE_TIME:
			hud.show_restart_prompt()
			if Input.is_action_just_pressed("restart"):
				restart_game()
			elif Input.is_action_just_pressed("menu"):
				return_to_menu()
	else:
		update_camera(delta)
		check_collisions()
		check_coin_pickups()
		
		# Update HUD boost indicator
		if hud.has_method("set_boost_active"):
			hud.set_boost_active(player.is_boosting)

func update_camera(delta: float) -> void:
	var target_pos = player.global_position + CAMERA_OFFSET
	
	var shake_offset = Vector3.ZERO
	if juice and juice.has_method("get_shake_offset"):
		shake_offset = juice.get_shake_offset()
	
	camera.global_position = camera.global_position.lerp(target_pos, 8.0 * delta) + shake_offset
	var look_target = player.global_position + Vector3(0, 0, -CAMERA_LOOK_AHEAD)
	camera.look_at(look_target)

func update_camera_instant() -> void:
	camera.global_position = player.global_position + CAMERA_OFFSET
	var look_target = player.global_position + Vector3(0, 0, -CAMERA_LOOK_AHEAD)
	camera.look_at(look_target)

func update_death_camera(delta: float) -> void:
	var target_pos = player.global_position + DEATH_CAMERA_OFFSET
	
	var shake_offset = Vector3.ZERO
	if juice and juice.has_method("get_shake_offset"):
		shake_offset = juice.get_shake_offset()
	
	camera.global_position = camera.global_position.lerp(target_pos, DEATH_CAMERA_LERP * delta) + shake_offset
	camera.look_at(player.global_position)

func check_collisions() -> void:
	var player_pos = player.global_position
	var player_bottom = player_pos.y - 0.25
	
	for obstacle in obstacle_spawner.obstacles:
		if not is_instance_valid(obstacle):
			continue
		var obs_pos = obstacle.global_position
		
		# Z-distance early-out — obstacles far away can't possibly collide
		var z_dist = abs(player_pos.z - obs_pos.z)
		if z_dist > 15.0:
			continue
		
		var obs_height = obstacle.get_meta("obstacle_height", 2.0)
		var x_dist = abs(player_pos.x - obs_pos.x)
		var obstacle_top = obs_pos.y + (obs_height * 0.45)
		
		var horizontally_overlapping = x_dist < 1.1 and z_dist < 0.6
		var vertically_overlapping = player_bottom < obstacle_top
		
		if horizontally_overlapping and vertically_overlapping:
			if not obstacle.has_meta("already_hit"):
				obstacle.set_meta("already_hit", true)
				_resolve_hit(obstacle)
			break
		
		# Near miss detection
		var near_miss_x = x_dist < 1.8 and x_dist > 1.0
		var near_miss_z = z_dist < 1.2
		var cleared_vertically = player_bottom >= obstacle_top - 0.5
		
		if near_miss_x and near_miss_z and cleared_vertically:
			if not obstacle.has_meta("near_missed"):
				obstacle.set_meta("near_missed", true)
				if juice and juice.has_method("on_near_miss"):
					juice.on_near_miss()
				hud.show_near_miss()

## Collision resolution — separated from detection so each half can be tuned independently
func _resolve_hit(obstacle: Node3D) -> void:
	# Mary Korr's Path Sight — 25% base + synergy bonus chance to phase through
	var phase_chance = 0.25 + player.path_sight_bonus
	if player.rider_perk == "path_sight" and randf() < phase_chance:
		show_phase_effect(obstacle)
		hud.show_path_sight()
		if juice and juice.has_method("on_near_miss"):
			juice.on_near_miss()
		return  # She just... wasn't there
	
	# Shield absorbs hit
	if pickups and pickups.is_shielded():
		pickups.deactivate_shield()
		if juice and juice.has_method("on_damage"):
			juice.on_damage(0)  # Light shake
		hud.show_shield_break()
		destroy_obstacle(obstacle)
		return
	
	# Take actual damage
	player.take_damage()
	if juice and juice.has_method("on_damage"):
		juice.on_damage(player.damage_level)
	hud.show_damage(player.damage_level)
	destroy_obstacle(obstacle)

func check_coin_pickups() -> void:
	var player_pos = player.global_position
	
	# P1 fix: collect into a removal list instead of calling .duplicate() per frame
	var to_remove = []
	for coin in obstacle_spawner.coins:
		if not is_instance_valid(coin):
			continue
		var coin_pos = coin.global_position
		var dist = player_pos.distance_to(coin_pos)
		if dist < 1.5:
			to_remove.append(coin)
	
	for coin in to_remove:
		player.collect_coin()
		if particles and particles.has_method("emit_coin_collect"):
			particles.emit_coin_collect(coin.global_position)
		obstacle_spawner.remove_coin(coin)
		if juice and juice.has_method("on_coin_collect"):
			juice.on_coin_collect()

func _on_player_died() -> void:
	is_game_over = true
	death_timer = 0.0
	obstacle_spawner.stop()
	hud.show_death_message()
	
	# Fade music down on death
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.fade_down(1.5)
	
	# Record run stats to GameData
	if Engine.has_singleton("GameData") or get_node_or_null("/root/GameData"):
		GameData.record_run(player.distance_traveled, player.coins_collected)
	
	# Trigger interstitial ad every 3rd death
	var ads_mgr = get_node_or_null("/root/AdsManager")
	if ads_mgr:
		ads_mgr.on_player_death()

func _on_charge_changed(value: float) -> void:
	hud.update_charge(value)

func _on_distance_updated(value: float) -> void:
	hud.update_distance(value)

func _on_coins_updated(value: int) -> void:
	hud.update_coins(value)

func _on_speed_tier_changed(tier: int) -> void:
	hud.show_speed_up(tier)

func _on_zone_changed(zone: int) -> void:
	hud.update_zone(zone)
	track.set_zone(zone)

func _on_super_light_incoming() -> void:
	hud.show_super_warning()

func _on_sail_destroyed() -> void:
	if particles and particles.has_method("emit_sail_destruction"):
		particles.emit_sail_destruction()

func _on_engine_destroyed() -> void:
	if particles and particles.has_method("emit_engine_destruction"):
		particles.emit_engine_destruction()

func _on_phoenix_revived() -> void:
	# Kane's Borrowed Time triggered — give the player feedback
	if juice and juice.has_method("on_damage"):
		juice.on_damage(0)  # Shake to sell the hit
	# HUD feedback — reuse damage label with a distinct message
	hud.show_repair(player.damage_level)

func restart_game() -> void:
	is_game_over = false
	player.reset()
	obstacle_spawner.clear_all()
	obstacle_spawner.start()
	track.reset_track()
	
	# Fade music back up on restart (same track, resumes where it left off)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.fade_up(1.5)
	
	if juice and juice.has_method("reset"):
		juice.reset()
	
	if particles and particles.has_method("reset"):
		particles.reset()
	
	if pickups and pickups.has_method("reset"):
		pickups.reset()
	
	update_camera_instant()
	hud.hide_death_ui()

func return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Destroy obstacle with particle explosion
func destroy_obstacle(obstacle: Node3D) -> void:
	var obs_pos = obstacle.global_position
	
	# Spawn destruction particles
	var debris = GPUParticles3D.new()
	debris.amount = 25
	debris.lifetime = 0.8
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.emitting = true
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 1)  # Explode up and forward
	mat.spread = 60.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -15, 0)
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	
	# Match obstacle color roughly
	mat.color = Color(0.4, 0.35, 0.3)
	
	debris.process_material = mat
	
	# Chunk mesh
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.3)
	debris.draw_pass_1 = mesh
	
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.35, 0.3, 0.25)
	debris.material_override = mesh_mat
	
	add_child(debris)
	debris.global_position = obs_pos + Vector3(0, 1, 0)
	
	# Also emit sparks
	if particles and particles.has_method("emit_damage_sparks"):
		particles.emit_damage_sparks()
	
	# Hide the obstacle (don't delete, spawner manages it)
	obstacle.visible = false
	
	# Cleanup debris after animation — use finished signal as primary, timer as backup
	debris.finished.connect(func():
		if is_instance_valid(debris):
			debris.queue_free()
	)
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(debris) and debris.is_inside_tree():
			debris.queue_free()
	)

# Mary Korr's cinematic phase effect
func show_phase_effect(obstacle: Node3D) -> void:
	var obs_pos = obstacle.global_position
	
	# Ghost afterimage of Mary passing through
	var ghost = GPUParticles3D.new()
	ghost.amount = 40
	ghost.lifetime = 0.5
	ghost.one_shot = true
	ghost.explosiveness = 0.8
	ghost.emitting = true
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)  # Trail behind
	mat.spread = 20.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 0.5, 0)  # Float up slightly
	mat.scale_min = 0.1
	mat.scale_max = 0.4
	
	# Ethereal purple/blue - Mary's signature color
	mat.color = Color(0.6, 0.4, 0.9, 0.7)
	
	ghost.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	ghost.draw_pass_1 = mesh
	
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.5, 0.3, 0.8, 0.5)
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(0.6, 0.4, 0.9)
	mesh_mat.emission_energy_multiplier = 3.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override = mesh_mat
	
	ghost.global_position = obs_pos
	add_child(ghost)
	
	# Make obstacle flicker/ghost briefly
	if obstacle is MeshInstance3D:
		var original_mat = obstacle.material_override
		
		# Briefly turn obstacle ghostly
		var ghost_mat = StandardMaterial3D.new()
		ghost_mat.albedo_color = Color(0.5, 0.4, 0.8, 0.3)
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.emission_enabled = true
		ghost_mat.emission = Color(0.6, 0.4, 0.9)
		ghost_mat.emission_energy_multiplier = 2.0
		
		obstacle.material_override = ghost_mat
		
		# Restore after brief moment
		var tween = create_tween()
		tween.tween_interval(0.15)
		tween.tween_callback(func(): obstacle.material_override = original_mat)
	
	# Screen effect
	var flash = hud.get_node_or_null("ScreenFlash")
	if flash:
		flash.color = Color(0.6, 0.4, 0.9, 0.25)
		var flash_tween = create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, 0.3)
	
	# Cleanup
	ghost.finished.connect(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
	)
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): ghost.queue_free())
