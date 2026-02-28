extends CanvasLayer

# Dev Kit - Press F1 to toggle
# Test all characters, boards, perks, and game states

var panel_visible: bool = false
var panel: PanelContainer
var player: CharacterBody3D
var game_manager: Node3D

# Secret tap zone for mobile - rapid taps in top-left corner
var corner_tap_count: int = 0
var corner_tap_timer: float = 0.0
const CORNER_TAP_ZONE: float = 80.0  # Pixels from top-left corner
const CORNER_TAPS_NEEDED: int = 5
const CORNER_TAP_WINDOW: float = 2.0  # Seconds to complete all taps

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Work even when paused
	call_deferred("setup")

func setup() -> void:
	player = get_parent().get_node_or_null("Player")
	game_manager = get_parent()
	build_ui()
	panel.visible = false

func _process(delta: float) -> void:
	if corner_tap_timer > 0:
		corner_tap_timer -= delta
		if corner_tap_timer <= 0:
			corner_tap_count = 0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				toggle_panel()
			KEY_F2:
				if panel_visible:
					give_coins(1000)
			KEY_F3:
				if panel_visible:
					trigger_damage()
			KEY_F4:
				if panel_visible:
					trigger_shield()
			KEY_F5:
				if panel_visible:
					unlock_all()
	
	# Secret tap zone - tap top-left corner 5 times to toggle dev kit
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		if event.position.x < CORNER_TAP_ZONE and event.position.y < CORNER_TAP_ZONE:
			if corner_tap_timer > 0:
				corner_tap_count += 1
			else:
				corner_tap_count = 1
			corner_tap_timer = CORNER_TAP_WINDOW
			if corner_tap_count >= CORNER_TAPS_NEEDED:
				toggle_panel()
				corner_tap_count = 0
				corner_tap_timer = 0.0

func toggle_panel() -> void:
	panel_visible = not panel_visible
	panel.visible = panel_visible
	
	# Pause game when dev kit is open
	get_tree().paused = panel_visible

func build_ui() -> void:
	panel = PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS  # Work when paused
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -250
	panel.offset_bottom = 250
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 480)
	panel.add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(main_vbox)
	
	# Title bar with close button
	var title_bar = HBoxContainer.new()
	main_vbox.add_child(title_bar)
	
	var title = Label.new()
	title.text = "⚙ DEV KIT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "✕ CLOSE"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.pressed.connect(toggle_panel)
	title_bar.add_child(close_btn)
	
	# Hotkeys hint
	var hotkeys = Label.new()
	hotkeys.text = "F1 or tap top-left corner 5x to toggle"
	hotkeys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys.modulate = Color(0.6, 0.6, 0.6)
	main_vbox.add_child(hotkeys)
	
	add_separator(main_vbox)
	
	# === CURRENT STATE ===
	var state_label = Label.new()
	state_label.text = "CURRENT STATE"
	state_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(state_label)
	
	var state_info = Label.new()
	state_info.name = "StateInfo"
	state_info.text = "Loading..."
	main_vbox.add_child(state_info)
	
	add_separator(main_vbox)
	
	# === CREW SELECTION ===
	var crew_label = Label.new()
	crew_label.text = "CREW (instant equip)"
	crew_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(crew_label)
	
	var crew_grid = GridContainer.new()
	crew_grid.columns = 3
	crew_grid.add_theme_constant_override("h_separation", 5)
	crew_grid.add_theme_constant_override("v_separation", 5)
	main_vbox.add_child(crew_grid)
	
	for rider_id in GameData.RIDERS.keys():
		var rider = GameData.RIDERS[rider_id]
		var btn = Button.new()
		btn.text = rider.name
		btn.custom_minimum_size = Vector2(180, 35)
		btn.tooltip_text = rider.perk_desc
		btn.pressed.connect(equip_rider.bind(rider_id))
		crew_grid.add_child(btn)
	
	add_separator(main_vbox)
	
	# === VESSEL SELECTION ===
	var vessel_label = Label.new()
	vessel_label.text = "VESSELS (instant equip)"
	vessel_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(vessel_label)
	
	var vessel_grid = GridContainer.new()
	vessel_grid.columns = 3
	vessel_grid.add_theme_constant_override("h_separation", 5)
	vessel_grid.add_theme_constant_override("v_separation", 5)
	main_vbox.add_child(vessel_grid)
	
	for board_id in GameData.BOARDS.keys():
		var board = GameData.BOARDS[board_id]
		var btn = Button.new()
		btn.text = board.name
		btn.custom_minimum_size = Vector2(180, 35)
		var stats = board.stats
		btn.tooltip_text = "SPD: %.0f%% CHG: %.0f%% HDL: %.0f%%" % [stats.speed * 100, stats.charge * 100, stats.handling * 100]
		btn.pressed.connect(equip_board.bind(board_id))
		vessel_grid.add_child(btn)
	
	add_separator(main_vbox)
	
	# === GAME ACTIONS ===
	var actions_label = Label.new()
	actions_label.text = "GAME ACTIONS"
	actions_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(actions_label)
	
	var actions_grid = GridContainer.new()
	actions_grid.columns = 3
	actions_grid.add_theme_constant_override("h_separation", 5)
	actions_grid.add_theme_constant_override("v_separation", 5)
	main_vbox.add_child(actions_grid)
	
	var action_buttons = [
		["+ 100 Coins", give_coins.bind(100)],
		["+ 1000 Coins", give_coins.bind(1000)],
		["+ 10000 Coins", give_coins.bind(10000)],
		["Take Damage", trigger_damage],
		["Give Shield", trigger_shield],
		["Give Magnet", trigger_magnet],
		["Full Charge", full_charge],
		["Empty Charge", empty_charge],
		["Repair All", repair_all],
		["Kill Player", kill_player],
		["Set Shadow Zone", set_zone_shadow],
		["Set Light Zone", set_zone_light],
		["Set Super Light", set_zone_super],
		["Spawn Storm", trigger_storm],
		["Unlock All", unlock_all],
		["Reset Save", reset_save],
	]
	
	for action in action_buttons:
		var btn = Button.new()
		btn.text = action[0]
		btn.custom_minimum_size = Vector2(180, 30)
		btn.pressed.connect(action[1])
		actions_grid.add_child(btn)
	
	add_child(panel)
	
	# Update state display
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(update_state_display)
	timer.autostart = true
	add_child(timer)

func add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	sep.modulate = Color(0.4, 0.4, 0.5)
	parent.add_child(sep)

func update_state_display() -> void:
	if not panel_visible:
		return
	
	var state_info = panel.get_node_or_null("ScrollContainer/VBoxContainer/StateInfo")
	if not state_info:
		return
	
	var text = ""
	text += "Crew: %s (%s)\n" % [GameData.RIDERS[GameData.current_rider].name, GameData.current_rider]
	text += "Vessel: %s (%s)\n" % [GameData.BOARDS[GameData.current_board].name, GameData.current_board]
	
	# Synergy status
	var synergy = GameData.get_current_synergy()
	if synergy.size() > 0:
		if synergy.type == "synergy":
			text += "✦ SYNERGY: %s\n" % synergy.name
		else:
			text += "⚠ ANTI-SYNERGY: %s\n" % synergy.name
	else:
		text += "No synergy active\n"
	
	text += "Coins: %d\n" % GameData.coins
	
	if player:
		text += "Perk Active: %s\n" % player.rider_perk
		text += "Damage Level: %d/3\n" % player.damage_level
		text += "Sail: %s | Engine: %s\n" % ["OK" if player.sail_intact else "GONE", "OK" if player.engine_intact else "DEAD"]
		text += "Charge: %.1f%%\n" % player.solar_charge
		text += "Speed: %.1f (mod: %.2f)\n" % [player.forward_speed, player.speed_modifier]
		text += "Charge Mod: %.2f\n" % player.charge_modifier
		text += "Phoenix Revive: %s\n" % ("Ready" if player.phoenix_revive_available else "Used/None")
		if player.rider_perk == "path_sight":
			text += "Phase Chance: %.0f%%\n" % ((0.15 + player.path_sight_bonus) * 100)
		if player.rider_perk == "lucky":
			text += "Luck Bonus: %.0f%%\n" % (player.lucky_bonus * 100)
		text += "Distance: %.0fm\n" % player.distance_traveled
	
	state_info.text = text

func equip_rider(rider_id: String) -> void:
	# Force unlock and equip
	if rider_id not in GameData.unlocked_riders:
		GameData.unlocked_riders.append(rider_id)
	GameData.current_rider = rider_id
	GameData.save_game()
	
	# Apply to current player
	if player:
		player.apply_loadout()
	
	print("DEV: Equipped rider - ", rider_id)

func equip_board(board_id: String) -> void:
	# Force unlock and equip
	if board_id not in GameData.unlocked_boards:
		GameData.unlocked_boards.append(board_id)
	GameData.current_board = board_id
	GameData.save_game()
	
	# Apply to current player
	if player:
		player.apply_loadout()
	
	print("DEV: Equipped board - ", board_id)

func give_coins(amount: int) -> void:
	GameData.add_coins(amount)
	print("DEV: Added ", amount, " coins. Total: ", GameData.coins)

func trigger_damage() -> void:
	if player and not player.is_dead:
		player.take_damage()
		print("DEV: Triggered damage. Level: ", player.damage_level)

func trigger_shield() -> void:
	var pickups = get_parent().get_node_or_null("PickupManager")
	if pickups:
		pickups.activate_shield()
		print("DEV: Shield activated")

func trigger_magnet() -> void:
	var pickups = get_parent().get_node_or_null("PickupManager")
	if pickups:
		pickups.activate_magnet()
		print("DEV: Magnet activated")

func full_charge() -> void:
	if player:
		player.solar_charge = 100.0
		player.emit_signal("charge_changed", 100.0)
		print("DEV: Charge set to 100%")

func empty_charge() -> void:
	if player:
		player.solar_charge = 0.0
		player.emit_signal("charge_changed", 0.0)
		print("DEV: Charge set to 0%")

func repair_all() -> void:
	if player:
		player.damage_level = 0
		player.sail_intact = true
		player.engine_intact = true
		var surfer = player.get_node_or_null("SolarSurfer")
		if surfer and surfer.has_method("repair"):
			surfer.repair()
		print("DEV: Fully repaired")

func kill_player() -> void:
	if player and not player.is_dead:
		player.die()
		print("DEV: Player killed")

func set_zone_shadow() -> void:
	if player:
		player.set_zone(0)
		var track = get_parent().get_node_or_null("Track")
		if track:
			track.set_zone(0)
		print("DEV: Set to Shadow zone")

func set_zone_light() -> void:
	if player:
		player.set_zone(1)
		var track = get_parent().get_node_or_null("Track")
		if track:
			track.set_zone(1)
		print("DEV: Set to Light zone")

func set_zone_super() -> void:
	if player:
		player.set_zone(2)
		var track = get_parent().get_node_or_null("Track")
		if track:
			track.set_zone(2)
		print("DEV: Set to Super Light zone")

func trigger_storm() -> void:
	var storm = get_parent().get_node_or_null("StormHazard")
	if storm and player:
		var storm_z = player.position.z - 50.0  # Spawn close for testing
		storm.spawn_storm(storm_z, 1.0)
		print("DEV: Storm spawned!")

func unlock_all() -> void:
	for rider_id in GameData.RIDERS.keys():
		if rider_id not in GameData.unlocked_riders:
			GameData.unlocked_riders.append(rider_id)
	for board_id in GameData.BOARDS.keys():
		if board_id not in GameData.unlocked_boards:
			GameData.unlocked_boards.append(board_id)
	GameData.save_game()
	print("DEV: Unlocked all crew and vessels")

func reset_save() -> void:
	GameData.marks = 0
	GameData.bits = 0
	GameData.sovereigns = 0
	GameData.total_distance = 0.0
	GameData.total_coins_collected = 0
	GameData.total_runs = 0
	GameData.best_distance = 0.0
	GameData.best_coins_in_run = 0
	GameData.unlocked_riders = ["default"]
	GameData.unlocked_boards = ["default"]
	GameData.current_rider = "default"
	GameData.current_board = "default"
	GameData.save_game()
	print("DEV: Save data reset")
