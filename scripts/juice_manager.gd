extends Node

# Juice Manager - handles all the "game feel" effects

var camera: Camera3D
var player: CharacterBody3D
var player_mesh: Node3D  # Can be SolarSurfer (Node3D) or MeshInstance3D

# Camera shake
var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var shake_offset: Vector3 = Vector3.ZERO

# Camera effects
var base_fov: float = 70.0
var target_fov: float = 70.0
var fov_lerp_speed: float = 8.0

# Player visual state
var target_lane_tilt: float = 0.0  # Z rotation for lane switching
var current_lane_tilt: float = 0.0
var target_pitch_tilt: float = 0.0  # X rotation for jump up/down
var current_pitch_tilt: float = 0.0
var tilt_speed: float = 8.0
var lane_tilt_reset_timer: float = 0.0
const LANE_TILT_RESET_DELAY: float = 0.2

# Track player state for detecting changes
var last_lane: int = 1
var was_on_floor: bool = true
var was_boosting: bool = false
var is_initialized: bool = false

func _ready() -> void:
	pass  # References injected by GameManager via set_player/set_camera

## Called by GameManager to inject references
func set_player(p: CharacterBody3D) -> void:
	player = p
	if player:
		player_mesh = player.get_node_or_null("SolarSurfer")
		if not player_mesh:
			player_mesh = player.get_node_or_null("MeshInstance3D")
	_check_initialized()

func set_camera(c: Camera3D) -> void:
	camera = c
	if camera:
		base_fov = camera.fov
	_check_initialized()

func _check_initialized() -> void:
	is_initialized = camera != null and player != null and player_mesh != null
	if is_initialized:
		print("JuiceManager initialized successfully")

func _process(delta: float) -> void:
	if not is_initialized:
		return
	
	update_shake(delta)
	update_fov(delta)
	update_player_visuals(delta)
	detect_state_changes()

# ============ CAMERA SHAKE ============

func update_shake(delta: float) -> void:
	if shake_intensity > 0:
		shake_offset = Vector3(
			randf_range(-1, 1) * shake_intensity,
			randf_range(-1, 1) * shake_intensity,
			randf_range(-1, 1) * shake_intensity * 0.5
		)
		shake_intensity = max(0, shake_intensity - shake_decay * delta)
	else:
		shake_offset = Vector3.ZERO

func add_shake(intensity: float, decay: float = 5.0) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_decay = decay

func get_shake_offset() -> Vector3:
	return shake_offset

# ============ FOV EFFECTS ============

func update_fov(delta: float) -> void:
	if camera:
		camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)

func set_boost_fov(boosting: bool) -> void:
	target_fov = base_fov + 12.0 if boosting else base_fov

# ============ PLAYER VISUALS ============

func update_player_visuals(delta: float) -> void:
	if not player_mesh:
		return
	
	# Handle lane tilt reset timer
	if lane_tilt_reset_timer > 0:
		lane_tilt_reset_timer -= delta
		if lane_tilt_reset_timer <= 0:
			target_lane_tilt = 0.0  # Reset lane tilt to center
	
	# Smooth lane tilt (Z axis - left/right lean)
	current_lane_tilt = lerp(current_lane_tilt, target_lane_tilt, tilt_speed * delta)
	
	# Smooth pitch tilt (X axis - nose up/down)
	current_pitch_tilt = lerp(current_pitch_tilt, target_pitch_tilt, tilt_speed * delta)
	
	# Apply tilts to mesh (rotation only, no scale for SolarSurfer)
	player_mesh.rotation.z = current_lane_tilt
	player_mesh.rotation.x = current_pitch_tilt

func detect_state_changes() -> void:
	if not player:
		return
	
	# Lane switch detection
	var current_lane = player.current_lane
	if current_lane != last_lane:
		on_lane_switch(current_lane - last_lane)
		last_lane = current_lane
	
	# Landing detection
	var on_floor = player.is_on_floor()
	if on_floor and not was_on_floor:
		on_land()
	elif not on_floor and was_on_floor:
		on_jump()
	was_on_floor = on_floor
	
	# In-air pitch based on vertical velocity
	if not on_floor and player_mesh:
		var vel_y = player.velocity.y
		# Nose UP when rising, nose DOWN when falling
		# Asymmetric: less tilt up (-0.4 max), more tilt down (+0.3 max)
		if vel_y > 0:
			target_pitch_tilt = clamp(vel_y * 0.02, 0.0, 0.4)
		else:
			target_pitch_tilt = clamp(vel_y * 0.025, -0.3, 0.0)
	else:
		# On ground, level out
		target_pitch_tilt = 0.0
	
	# Boost detection
	var boosting = player.is_boosting
	if boosting != was_boosting:
		on_boost_change(boosting)
		was_boosting = boosting

# ============ EVENT RESPONSES ============

func on_lane_switch(direction: int) -> void:
	# Tilt board in direction of movement (Z axis)
	target_lane_tilt = -direction * 0.35  # Lean into the turn
	lane_tilt_reset_timer = LANE_TILT_RESET_DELAY  # Start timer to reset tilt
	
	# Tiny shake
	add_shake(0.08, 10.0)

func on_jump() -> void:
	# Just a small shake on takeoff
	add_shake(0.05, 12.0)

func on_land() -> void:
	# Landing shake
	add_shake(0.12, 12.0)

func on_boost_change(boosting: bool) -> void:
	set_boost_fov(boosting)
	
	if boosting:
		# Boost start shake
		add_shake(0.15, 8.0)

func on_coin_collect() -> void:
	# Tiny satisfying bump
	add_shake(0.04, 18.0)

func on_near_miss() -> void:
	# Close call feedback
	add_shake(0.25, 10.0)

func on_damage(level: int) -> void:
	# Big hit feedback - gets worse with each strike
	match level:
		1:
			add_shake(0.4, 4.0)
		2:
			add_shake(0.5, 3.0)
		3:
			add_shake(0.6, 2.0)

func on_death() -> void:
	# Big impact shake
	add_shake(0.6, 2.0)

func reset() -> void:
	shake_intensity = 0.0
	shake_offset = Vector3.ZERO
	target_fov = base_fov
	target_lane_tilt = 0.0
	current_lane_tilt = 0.0
	target_pitch_tilt = 0.0
	current_pitch_tilt = 0.0
	lane_tilt_reset_timer = 0.0
	last_lane = 1
	was_on_floor = true
	was_boosting = false
	
	if player_mesh:
		player_mesh.rotation.z = 0.0
		player_mesh.rotation.x = 0.0
	
	if camera:
		camera.fov = base_fov
