extends CharacterBody3D

# Lane configuration
const LANE_WIDTH: float = 3.0
const LANES: Array[int] = [-1, 0, 1]
var current_lane: int = 1

# Movement
var forward_speed: float = 20.0
var target_speed: float = 20.0  # Speed lerps to this
const SPEED_LERP_RATE: float = 3.0  # How fast speed changes (lower = smoother)

const BASE_SPEED: float = 20.0
const SHADOW_SPEED_MULT: float = 0.75
const BOOST_SPEED_MULT: float = 1.5
const SUPER_LIGHT_SPEED_MULT: float = 1.3
const LANE_SWITCH_SPEED: float = 12.0

# Speed ramping
const SPEED_RAMP_DISTANCE: float = 500.0
const SPEED_RAMP_AMOUNT: float = 3.0
const MAX_SPEED: float = 60.0

# Jump
const BASE_JUMP_FORCE: float = 12.0
const BOOSTED_JUMP_FORCE: float = 20.0
const BASE_GRAVITY: float = 40.0
const BOOSTED_GRAVITY: float = 35.0
var is_jumping: bool = false
var used_boost_jump: bool = false

# Airborne boost thrust — hold boost mid-air for extra forward distance
const AIR_BOOST_Z_MULT: float = 1.6  # 60% more forward speed while airborne + boosting
const AIR_BOOST_LERP_UP: float = 4.0  # How fast thrust kicks in
const AIR_BOOST_LERP_DOWN: float = 8.0  # How fast it drops off on landing
const AIR_BOOST_LIFT: float = 18.0  # Upward force while boosting mid-air (counters gravity)
var air_boost_factor: float = 1.0  # Current multiplier, smoothly interpolated

# Boost / Solar Charge
var solar_charge: float = 100.0
const MAX_SOLAR_CHARGE: float = 100.0
const CHARGE_DRAIN_RATE: float = 30.0
const CHARGE_FILL_RATE_LIGHT: float = 20.0
const CHARGE_FILL_RATE_SUPER: float = 50.0
const BOOST_JUMP_COST: float = 12.0
var is_boosting: bool = false

# Board/Rider stat modifiers (applied from GameData)
var speed_modifier: float = 1.0
var charge_modifier: float = 1.0
var handling_modifier: float = 1.0
var rider_perk: String = "none"
var phoenix_revive_available: bool = false

# Synergy bonus variables
var revive_heals_sail: bool = false
var path_sight_bonus: float = 0.0
var lucky_bonus: float = 0.0
var shadow_resist_bonus: float = 0.0

# Touch controls - state machine approach
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_current_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false
var touch_id: int = -1  # Track single finger only
var is_touch_boosting: bool = false
var swipe_cooldown: float = 0.0

# Touch thresholds (tuned for real devices)
const SWIPE_PX: float = 60.0  # Minimum pixels for swipe
const TAP_MAX_TIME: float = 0.18  # Max seconds for tap
const HOLD_TIME: float = 0.22  # Min seconds to start boost
const HOLD_MOVE_TOLERANCE_PX: float = 14.0  # Must stay still for hold
const SWIPE_COOLDOWN_TIME: float = 0.10  # Prevents double-lane

# Zone states
enum Zone { SHADOW, LIGHT, SUPER_LIGHT }
var current_zone: int = Zone.LIGHT

# Damage system - 3 strikes and you're out
var damage_level: int = 0  # 0=pristine, 1=sail gone, 2=engine dead, 3=destroyed
var sail_intact: bool = true
var engine_intact: bool = true

# Stats
var is_dead: bool = false
var target_x: float = 0.0
var distance_traveled: float = 0.0
var start_z: float = 0.0
var coins_collected: int = 0
var current_speed_tier: int = 0

# Signals
signal died
signal charge_changed(value: float)
signal distance_updated(value: float)
signal coins_updated(value: int)
signal speed_tier_changed(tier: int)
signal zone_changed(zone: int)
signal damage_taken(level: int)
signal sail_destroyed
signal engine_destroyed
signal phoenix_revived

func _ready() -> void:
	target_x = LANES[current_lane] * LANE_WIDTH
	position.x = target_x
	start_z = position.z
	apply_loadout()

func apply_loadout() -> void:
	# Apply board stats if GameData exists
	if Engine.has_singleton("GameData") or get_node_or_null("/root/GameData"):
		# Get effective stats (includes synergy bonuses/penalties)
		var effective_stats = GameData.get_effective_stats()
		speed_modifier = effective_stats.get("speed", 1.0)
		charge_modifier = effective_stats.get("charge", 1.0)
		handling_modifier = effective_stats.get("handling", 1.0)
		
		rider_perk = GameData.get_current_rider_perk()
		
		# Get synergy for special bonuses
		var synergy = GameData.get_current_synergy()
		
		# Apply rider-specific perks
		match rider_perk:
			"revive":
				# Kane's Borrowed Time
				phoenix_revive_available = true
				revive_heals_sail = _get_synergy_flag(synergy, "bonus", "revive_heal")
			"armor":
				# Vol Kresh - Start with free shield (handled by pickup_manager)
				pass
			"path_sight":
				# Mary Korr - Chance to phase through (handled by game_manager collision)
				path_sight_bonus = _get_synergy_value(synergy, "path_sight_bonus")
			"lucky":
				# Thornveil - More coins (handled by obstacle_spawner)
				lucky_bonus = _get_synergy_value(synergy, "lucky_bonus")
			"shadow_resist":
				# Jubari - Slower shadow drain (handled in update_boost)
				shadow_resist_bonus = _get_synergy_value(synergy, "shadow_resist_bonus")
			"charge_boost":
				# The Emissary - Faster charge (handled in update_boost)
				pass
		
		# Apply board colors to surfer
		var surfer = get_node_or_null("SolarSurfer")
		if surfer and surfer.has_method("apply_board_colors"):
			var board_data = GameData.BOARDS.get(GameData.current_board, {})
			surfer.apply_board_colors(
				board_data.get("board_color", Color(0.6, 0.45, 0.25)),
				board_data.get("sail_color", Color(1.0, 0.85, 0.5)),
				board_data.get("engine_color", Color(1.0, 0.6, 0.2))
			)
		
		# Log synergy status
		if synergy.size() > 0:
			print("SYNERGY: ", synergy.name, " - ", synergy.description)
		print("Loadout applied - Speed: ", speed_modifier, " Charge: ", charge_modifier, " Perk: ", rider_perk)

## Synergy helpers — single source of truth for bonus/penalty extraction
func _get_synergy_value(synergy: Dictionary, key: String, default_val: float = 0.0) -> float:
	if synergy.has("bonus") and synergy.bonus.has(key):
		return synergy.bonus[key]
	elif synergy.has("penalty") and synergy.penalty.has(key):
		return synergy.penalty[key]
	return default_val

func _get_synergy_flag(synergy: Dictionary, pool: String, key: String) -> bool:
	return synergy.has(pool) and synergy[pool].has(key) and synergy[pool][key]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	is_boosting = (Input.is_action_pressed("boost") or get_touch_boosting()) and solar_charge > 0
	
	_process_touch(delta)
	handle_input()
	update_boost(delta)
	update_speed(delta)
	
	var vel = velocity
	
	# Airborne boost thrust — holding boost mid-air surges you forward
	var target_air_factor: float = 1.0
	if not is_on_floor() and is_boosting and solar_charge > 0:
		target_air_factor = AIR_BOOST_Z_MULT
		air_boost_factor = lerp(air_boost_factor, target_air_factor, AIR_BOOST_LERP_UP * delta)
	else:
		air_boost_factor = lerp(air_boost_factor, 1.0, AIR_BOOST_LERP_DOWN * delta)
	
	# Forward movement — air boost multiplier applies on top of base speed
	vel.z = -forward_speed * air_boost_factor
	
	distance_traveled = abs(position.z - start_z)
	emit_signal("distance_updated", distance_traveled)
	check_speed_tier()
	
	# Lateral movement
	var x_diff = target_x - position.x
	if abs(x_diff) > 0.1:
		vel.x = sign(x_diff) * LANE_SWITCH_SPEED
	else:
		position.x = target_x
		vel.x = 0.0
	
	# Vertical movement
	if not is_on_floor():
		var current_gravity = BOOSTED_GRAVITY if used_boost_jump else BASE_GRAVITY
		vel.y -= current_gravity * delta
		
		# Airborne boost lift — holding boost mid-air fights gravity
		if is_boosting and solar_charge > 0:
			vel.y += AIR_BOOST_LIFT * delta
	
	if is_on_floor() and vel.y < 0:
		vel.y = 0.0
		is_jumping = false
		used_boost_jump = false
		air_boost_factor = 1.0
	
	velocity = vel
	move_and_slide()

func handle_input() -> void:
	if Input.is_action_just_pressed("move_left") and current_lane > 0:
		current_lane -= 1
		target_x = LANES[current_lane] * LANE_WIDTH
	
	if Input.is_action_just_pressed("move_right") and current_lane < 2:
		current_lane += 1
		target_x = LANES[current_lane] * LANE_WIDTH
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		do_jump()

func do_jump() -> void:
	if not is_on_floor():
		return
	if is_boosting and solar_charge >= BOOST_JUMP_COST:
		velocity.y = BOOSTED_JUMP_FORCE
		used_boost_jump = true
		if current_zone != Zone.SUPER_LIGHT:
			solar_charge -= BOOST_JUMP_COST
			emit_signal("charge_changed", solar_charge)
	else:
		velocity.y = BASE_JUMP_FORCE
		used_boost_jump = false
	is_jumping = true

func _input(event: InputEvent) -> void:
	if is_dead:
		return
	
	# Handle touch input - single finger only
	if event is InputEventScreenTouch:
		if event.pressed:
			# Only track first finger
			if touch_id == -1:
				touch_id = event.index
				touch_start_pos = event.position
				touch_current_pos = event.position
				touch_start_time = Time.get_ticks_msec() / 1000.0
				is_touching = true
				is_touch_boosting = false
		else:
			# Finger released - only respond to tracked finger
			if event.index == touch_id:
				var touch_duration = Time.get_ticks_msec() / 1000.0 - touch_start_time
				var total_movement = touch_current_pos.distance_to(touch_start_pos)
				
				# Capture boost state BEFORE clearing it
				var was_boosting = is_touch_boosting
				
				# End boost on any release
				is_touch_boosting = false
				is_touching = false
				touch_id = -1
				
				# TAP: quick release, minimal movement, wasn't boosting
				if touch_duration < TAP_MAX_TIME and total_movement < HOLD_MOVE_TOLERANCE_PX and not was_boosting:
					do_jump()
	
	# Handle touch drag
	if event is InputEventScreenDrag:
		if event.index == touch_id and is_touching:
			touch_current_pos = event.position
			var swipe_delta = touch_current_pos - touch_start_pos
			var touch_duration = Time.get_ticks_msec() / 1000.0 - touch_start_time
			var total_movement = touch_current_pos.distance_to(touch_start_pos)
			
			# SWIPE: horizontal movement exceeds threshold
			if abs(swipe_delta.x) > SWIPE_PX and abs(swipe_delta.x) > abs(swipe_delta.y) * 1.5:
				if swipe_cooldown <= 0:
					if swipe_delta.x < 0 and current_lane > 0:
						# Swipe left
						current_lane -= 1
						target_x = LANES[current_lane] * LANE_WIDTH
						swipe_cooldown = SWIPE_COOLDOWN_TIME
					elif swipe_delta.x > 0 and current_lane < 2:
						# Swipe right
						current_lane += 1
						target_x = LANES[current_lane] * LANE_WIDTH
						swipe_cooldown = SWIPE_COOLDOWN_TIME
					
					# Swipe cancels boost and resets start position for potential second swipe
					is_touch_boosting = false
					touch_start_pos = touch_current_pos
			
			# SWIPE UP: jump (works during boost hold for boost jumps)
			elif swipe_delta.y < -SWIPE_PX and abs(swipe_delta.y) > abs(swipe_delta.x) * 1.5:
				if swipe_cooldown <= 0:
					do_jump()
					swipe_cooldown = SWIPE_COOLDOWN_TIME
					touch_start_pos = touch_current_pos
			
			# HOLD: steady finger, enough time passed
			elif total_movement < HOLD_MOVE_TOLERANCE_PX and touch_duration >= HOLD_TIME:
				is_touch_boosting = true

func _process_touch(delta: float) -> void:
	# Update swipe cooldown
	if swipe_cooldown > 0:
		swipe_cooldown -= delta
	
	# Check for hold boost while touching (in case no drag events)
	if is_touching and touch_id != -1:
		var touch_duration = Time.get_ticks_msec() / 1000.0 - touch_start_time
		var total_movement = touch_current_pos.distance_to(touch_start_pos)
		
		if total_movement < HOLD_MOVE_TOLERANCE_PX and touch_duration >= HOLD_TIME:
			is_touch_boosting = true

func get_touch_boosting() -> bool:
	return is_touch_boosting

func update_boost(delta: float) -> void:
	# If engine is dead, no boosting at all
	if not engine_intact:
		is_boosting = false
		# Charge still displayed but unusable
		emit_signal("charge_changed", solar_charge)
		return
	
	# Calculate charge rates with modifiers
	var fill_rate_light = CHARGE_FILL_RATE_LIGHT * charge_modifier
	var fill_rate_super = CHARGE_FILL_RATE_SUPER * charge_modifier
	var drain_rate = CHARGE_DRAIN_RATE
	
	# Apply rider perks
	if rider_perk == "charge_boost":
		# The Emissary's Drowned Blessing
		fill_rate_light *= 1.25
		fill_rate_super *= 1.25
	elif rider_perk == "shadow_resist" and current_zone == Zone.SHADOW:
		# Jubari's Deep Sailor - base 50% slower + synergy bonus
		var total_resist = 0.5 + shadow_resist_bonus  # e.g. 0.5 + 0.15 = 0.65 resist
		drain_rate *= (1.0 - total_resist)  # Lower drain
	
	# Charge only regenerates if sail is intact
	if sail_intact:
		match current_zone:
			Zone.SUPER_LIGHT:
				if not is_boosting:
					solar_charge += fill_rate_super * delta
			Zone.LIGHT:
				if is_boosting:
					solar_charge -= drain_rate * delta
				else:
					solar_charge += fill_rate_light * delta
			Zone.SHADOW:
				if is_boosting:
					solar_charge -= drain_rate * delta
				# No passive change in shadow
	else:
		# Sail destroyed - can still USE charge but can't regenerate
		if is_boosting:
			solar_charge -= drain_rate * delta
	
	solar_charge = clamp(solar_charge, 0, MAX_SOLAR_CHARGE)
	emit_signal("charge_changed", solar_charge)
	
	# Update surfer engine visuals
	var surfer = get_node_or_null("SolarSurfer")
	if surfer and surfer.has_method("set_boost"):
		surfer.set_boost(is_boosting and engine_intact)

func update_speed(delta: float) -> void:
	# Calculate what speed SHOULD be (with board modifier)
	var tier_bonus = current_speed_tier * SPEED_RAMP_AMOUNT
	var base = min(BASE_SPEED + tier_bonus, MAX_SPEED) * speed_modifier
	
	# Zone affects base speed
	if current_zone == Zone.SUPER_LIGHT:
		base *= SUPER_LIGHT_SPEED_MULT
	elif current_zone == Zone.SHADOW:
		base *= SHADOW_SPEED_MULT
	
	# Boost multiplier
	if is_boosting and solar_charge > 0:
		target_speed = base * BOOST_SPEED_MULT
	else:
		target_speed = base
	
	# SMOOTH transition to target speed (no jarring jumps)
	forward_speed = lerp(forward_speed, target_speed, SPEED_LERP_RATE * delta)

func check_speed_tier() -> void:
	var new_tier = int(distance_traveled / SPEED_RAMP_DISTANCE)
	if new_tier > current_speed_tier:
		current_speed_tier = new_tier
		emit_signal("speed_tier_changed", current_speed_tier)

func set_zone(zone: int) -> void:
	if zone != current_zone:
		current_zone = zone
		emit_signal("zone_changed", zone)
		# Update surfer visuals
		var surfer = get_node_or_null("SolarSurfer")
		if surfer and surfer.has_method("set_zone"):
			surfer.set_zone(zone)

func collect_coin() -> void:
	coins_collected += 1
	emit_signal("coins_updated", coins_collected)

func take_damage() -> void:
	damage_level += 1
	emit_signal("damage_taken", damage_level)
	
	var surfer = get_node_or_null("SolarSurfer")
	
	match damage_level:
		1:
			# Strike 1: Sail destroyed - no more charging
			sail_intact = false
			emit_signal("sail_destroyed")
			if surfer and surfer.has_method("destroy_sail"):
				surfer.destroy_sail()
			print("STRIKE 1: Sail destroyed! No more charge regen!")
		2:
			# Strike 2: Engine destroyed - no more boost
			engine_intact = false
			is_boosting = false
			emit_signal("engine_destroyed")
			if surfer and surfer.has_method("destroy_engine"):
				surfer.destroy_engine()
			print("STRIKE 2: Engine destroyed! No more boost!")
		3:
			# Strike 3: Would be game over, but check phoenix revive
			if phoenix_revive_available:
				phoenix_revive_available = false
				damage_level = 1  # Reset to sail-only damage
				
				# Restore engine functionality
				engine_intact = true
				sail_intact = false  # Sail stays damaged
				
				emit_signal("phoenix_revived")
				print("BORROWED TIME! Survived fatal hit - engine restored!")
				
				# Repair visuals
				if surfer and surfer.has_method("repair_engine"):
					surfer.repair_engine()
				
				# Synergy bonus: Survivor's Instinct repairs sail too
				if revive_heals_sail:
					damage_level = 0
					sail_intact = true
					if surfer and surfer.has_method("repair"):
						surfer.repair()
					print("SURVIVOR'S INSTINCT! Fully restored!")
			else:
				print("STRIKE 3: You're out!")
				die()

func _notification(what: int) -> void:
	# Clear touch state when app loses focus (prevents stuck boost on Android)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		is_touching = false
		is_touch_boosting = false
		touch_id = -1

func die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("died")

func get_forward_position() -> float:
	return position.z

func reset() -> void:
	is_dead = false
	current_lane = 1
	target_x = LANES[current_lane] * LANE_WIDTH
	position = Vector3(target_x, 1.0, 0.0)
	velocity = Vector3.ZERO
	forward_speed = BASE_SPEED
	target_speed = BASE_SPEED
	solar_charge = MAX_SOLAR_CHARGE
	distance_traveled = 0.0
	start_z = position.z
	coins_collected = 0
	current_speed_tier = 0
	is_jumping = false
	is_boosting = false
	used_boost_jump = false
	air_boost_factor = 1.0
	current_zone = Zone.LIGHT
	
	# Reset damage state
	damage_level = 0
	sail_intact = true
	engine_intact = true
	
	# Clear touch state (prevents phantom boost on restart)
	is_touching = false
	is_touch_boosting = false
	touch_id = -1
	swipe_cooldown = 0.0
	
	# Reset surfer visuals
	var surfer = get_node_or_null("SolarSurfer")
	if surfer and surfer.has_method("repair"):
		surfer.repair()
	
	# Re-apply loadout so phoenix revive, synergy bonuses, and board colors reset
	apply_loadout()
	
	emit_signal("charge_changed", solar_charge)
	emit_signal("coins_updated", 0)
	emit_signal("speed_tier_changed", 0)
	emit_signal("zone_changed", Zone.LIGHT)
