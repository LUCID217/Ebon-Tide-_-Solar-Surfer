extends Node

# GameData - Singleton for persistent game state
# Add to Project Settings > Autoload as "GameData"

const SAVE_PATH: String = "user://ebon_tide_save.dat"
const SAVE_VERSION: int = 1

# Currency - Three tier system
var marks: int = 0        # Everyday currency (earned from runs, ads)
var bits: int = 0         # Premium fragments (100 Marks = 1 Bit)
var sovereigns: int = 0   # Hard currency (6 Bits = 1 Sovereign)

# Legacy alias for compatibility
var coins: int:
	get: return marks
	set(value): marks = value

# Exchange rates
const MARKS_PER_BIT: int = 100
const BITS_PER_SOVEREIGN: int = 6

# Stats
var total_distance: float = 0.0
var total_coins_collected: int = 0
var total_runs: int = 0
var best_distance: float = 0.0
var best_coins_in_run: int = 0

# Unlocks
var unlocked_riders: Array[String] = ["default"]
var unlocked_boards: Array[String] = ["default"]

# Currently equipped
var current_rider: String = "default"
var current_board: String = "default"

# Settings
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var screen_shake: bool = true
var haptic_feedback: bool = true
var graphics_quality: int = 1  # 0=Low, 1=Medium, 2=High
var last_track_index: int = -1  # Persists music rotation across sessions

# Ebon Pass
var ebon_pass_active: bool = false
var last_cache_claim_time: int = 0  # Unix timestamp of last daily cache claim

# ============ RIDER DATA ============
# Cursed crew members of the Ebon Tide universe
# Prices in Sovereigns (doubling pattern: 3, 6, 12, 24, 48)
const RIDERS: Dictionary = {
	"default": {
		"name": "William Kane",
		"description": "Former Dominion captain. Returned from death on borrowed time.",
		"price": 0,
		"color": Color(0.4, 0.45, 0.5),
		"perk": "revive",
		"perk_desc": "Borrowed Time: Survive one fatal hit per run"
	},
	"korr": {
		"name": "Mary Korr",
		"description": "Cursed navigator. Sees paths others cannot.",
		"price": 3,
		"color": Color(0.6, 0.5, 0.8),
		"perk": "path_sight",
		"perk_desc": "Path Sight: 25% chance to phase through obstacles"
	},
	"jubari": {
		"name": "Jubari Quell",
		"description": "Drowned Man captain. Lives by code and superstition.",
		"price": 6,
		"color": Color(0.2, 0.5, 0.6),
		"perk": "shadow_resist",
		"perk_desc": "Deep Sailor: 50% slower drain in shadow zones"
	},
	"thornveil": {
		"name": "Silas ThorneVeil",
		"description": "Broken Chain gambler. Probability bends around him.",
		"price": 12,
		"color": Color(0.7, 0.3, 0.3),
		"perk": "lucky",
		"perk_desc": "Gambler's Tongue: Coins drawn to you, +25% spawn rate"
	},
	"kresh": {
		"name": "Vol Kresh",
		"description": "The Enforcer. Violence is procedure, not passion.",
		"price": 24,
		"color": Color(0.5, 0.4, 0.35),
		"perk": "armor",
		"perk_desc": "Unstoppable: Shield regenerates every 15s while engine lives"
	},
	"emissary": {
		"name": "The Emissary",
		"description": "Speak not her true name. The debt comes due.",
		"price": 48,
		"color": Color(0.1, 0.3, 0.35),
		"perk": "charge_boost",
		"perk_desc": "Drowned Blessing: +25% charge regeneration"
	}
}

# ============ BOARD DATA ============
# Vessels of the Ebon Tide - spacecraft that sail like ships
# Prices in Sovereigns (doubling pattern: 3, 6, 12, 24, 48)
const BOARDS: Dictionary = {
	"default": {
		"name": "Salvage Skiff",
		"description": "Held together by rust and stubbornness. Gets the job done.",
		"price": 0,
		"board_color": Color(0.5, 0.4, 0.35),
		"sail_color": Color(0.7, 0.65, 0.5),
		"engine_color": Color(0.9, 0.5, 0.2),
		"stats": {"speed": 1.0, "charge": 1.0, "handling": 1.0}
	},
	"light_catcher": {
		"name": "Light Catcher",
		"description": "Broad solar sails. Built for long hauls through the black.",
		"price": 3,
		"board_color": Color(0.6, 0.55, 0.4),
		"sail_color": Color(1.0, 0.95, 0.7),
		"engine_color": Color(1.0, 0.8, 0.3),
		"stats": {"speed": 0.95, "charge": 1.25, "handling": 1.0}
	},
	"void_runner": {
		"name": "Void Runner",
		"description": "Shadow-hulled. Loses less in the dark between stars.",
		"price": 6,
		"board_color": Color(0.15, 0.15, 0.2),
		"sail_color": Color(0.3, 0.3, 0.45),
		"engine_color": Color(0.4, 0.2, 0.6),
		"stats": {"speed": 1.0, "charge": 1.0, "handling": 1.15}
	},
	"dominion_cutter": {
		"name": "Dominion Cutter",
		"description": "Decommissioned naval vessel. Fast, precise, unforgiving.",
		"price": 12,
		"board_color": Color(0.3, 0.35, 0.4),
		"sail_color": Color(0.8, 0.8, 0.85),
		"engine_color": Color(0.5, 0.7, 0.9),
		"stats": {"speed": 1.2, "charge": 0.85, "handling": 0.9}
	},
	"tidebreaker": {
		"name": "Tidebreaker",
		"description": "Drowned Men design. Reinforced for rough passage.",
		"price": 24,
		"board_color": Color(0.35, 0.4, 0.45),
		"sail_color": Color(0.4, 0.55, 0.6),
		"engine_color": Color(0.3, 0.6, 0.65),
		"stats": {"speed": 0.9, "charge": 1.1, "handling": 1.1}
	},
	"harrowed_blessing": {
		"name": "Harrowed Blessing",
		"description": "Golden Age relic. When the Empress walked among men, her light made such things.",
		"price": 48,
		"board_color": Color(0.2, 0.25, 0.3),
		"sail_color": Color(0.5, 0.6, 0.7),
		"engine_color": Color(0.4, 0.5, 0.6),
		"stats": {"speed": 1.15, "charge": 1.15, "handling": 1.1}
	}
}

# ============ SYNERGY SYSTEM ============
const SYNERGIES: Dictionary = {
	"korr+void_runner": {
		"type": "synergy",
		"name": "Path Through Darkness",
		"description": "The navigator finds her element in the void.",
		"bonus": {"handling": 0.1, "path_sight_bonus": 0.05}
	},
	"jubari+tidebreaker": {
		"type": "synergy",
		"name": "Drowned Men's Pride",
		"description": "A captain reunited with his people's craft.",
		"bonus": {"charge": 0.15, "shadow_resist_bonus": 0.15}
	},
	"emissary+harrowed_blessing": {
		"type": "synergy",
		"name": "Golden Age Restored",
		"description": "She remembers when such things were made. It remembers her.",
		"bonus": {"speed": 0.1, "charge": 0.1}
	},
	"thornveil+dominion_cutter": {
		"type": "synergy",
		"name": "Calculated Edge",
		"description": "Precision vessel for a precise man.",
		"bonus": {"speed": 0.05, "lucky_bonus": 0.1}
	},
	"kresh+tidebreaker": {
		"type": "synergy",
		"name": "Unstoppable Force",
		"description": "Reinforced hull. Reinforced will.",
		"bonus": {"shield_duration": 2.0}
	},
	"default+default": {
		"type": "synergy",
		"name": "Survivor's Instinct",
		"description": "Rust and stubbornness. It's enough.",
		"bonus": {"revive_heal": true}
	},
	"jubari+dominion_cutter": {
		"type": "anti_synergy",
		"name": "Bad Blood",
		"description": "A pirate on a Dominion vessel. Neither forgives.",
		"penalty": {"charge": -0.15, "speed": -0.05}
	},
	"default+harrowed_blessing": {
		"type": "anti_synergy",
		"name": "Cursed Conflict",
		"description": "Borrowed time meets blessed relic. The Empress notices.",
		"penalty": {"charge": -0.2}
	},
	"kresh+dominion_cutter": {
		"type": "anti_synergy",
		"name": "Broken Chain's Shame",
		"description": "The enforcer in enemy colors. His masters would not approve.",
		"penalty": {"speed": -0.1}
	},
	"emissary+default": {
		"type": "anti_synergy",
		"name": "Beneath Her",
		"description": "A Golden Age witch on salvaged scraps. Insulting.",
		"penalty": {"charge": -0.1, "speed": -0.1}
	},
	"thornveil+tidebreaker": {
		"type": "anti_synergy",
		"name": "Wrong Table",
		"description": "A gambler doesn't play by pirate rules.",
		"penalty": {"lucky_bonus": -0.15}
	}
}

func get_synergy(rider_id: String, board_id: String) -> Dictionary:
	var key1 = rider_id + "+" + board_id
	var key2 = board_id + "+" + rider_id
	if SYNERGIES.has(key1):
		return SYNERGIES[key1]
	elif SYNERGIES.has(key2):
		return SYNERGIES[key2]
	return {}

func get_current_synergy() -> Dictionary:
	return get_synergy(current_rider, current_board)

func get_effective_stats() -> Dictionary:
	var board = BOARDS.get(current_board, BOARDS["default"])
	var stats = board.stats.duplicate()
	var synergy = get_current_synergy()
	if synergy.size() > 0:
		if synergy.type == "synergy" and synergy.has("bonus"):
			for stat in synergy.bonus.keys():
				if stats.has(stat):
					stats[stat] += synergy.bonus[stat]
		elif synergy.type == "anti_synergy" and synergy.has("penalty"):
			for stat in synergy.penalty.keys():
				if stats.has(stat):
					stats[stat] += synergy.penalty[stat]
	return stats

# ============ CURRENCY EXCHANGE ============
func exchange_marks_to_bits(amount: int) -> bool:
	var marks_needed = amount * MARKS_PER_BIT
	if marks >= marks_needed:
		marks -= marks_needed
		bits += amount
		save_game()
		return true
	return false

func exchange_bits_to_sovereigns(amount: int) -> bool:
	var bits_needed = amount * BITS_PER_SOVEREIGN
	if bits >= bits_needed:
		bits -= bits_needed
		sovereigns += amount
		save_game()
		return true
	return false

func can_afford_marks_to_bits(amount: int) -> bool:
	return marks >= (amount * MARKS_PER_BIT)

func can_afford_bits_to_sovereigns(amount: int) -> bool:
	return bits >= (amount * BITS_PER_SOVEREIGN)

func add_marks(amount: int) -> void:
	marks += amount
	save_game()

func add_bits(amount: int) -> void:
	bits += amount
	save_game()

func add_sovereigns(amount: int) -> void:
	sovereigns += amount
	save_game()

# ============ UNLOCK FUNCTIONS ============
func unlock_rider_with_sovereigns(rider_id: String) -> bool:
	if rider_id in unlocked_riders:
		return false
	if not RIDERS.has(rider_id):
		return false
	var price = RIDERS[rider_id].price
	if sovereigns >= price:
		sovereigns -= price
		unlocked_riders.append(rider_id)
		save_game()
		return true
	return false

func unlock_board_with_sovereigns(board_id: String) -> bool:
	if board_id in unlocked_boards:
		return false
	if not BOARDS.has(board_id):
		return false
	var price = BOARDS[board_id].price
	if sovereigns >= price:
		sovereigns -= price
		unlocked_boards.append(board_id)
		save_game()
		return true
	return false

func can_afford_rider(rider_id: String) -> bool:
	if not RIDERS.has(rider_id):
		return false
	return sovereigns >= RIDERS[rider_id].price

func can_afford_board(board_id: String) -> bool:
	if not BOARDS.has(board_id):
		return false
	return sovereigns >= BOARDS[board_id].price

# ============ SAVE/LOAD ============
func save_game() -> void:
	var save_data = {
		"save_version": SAVE_VERSION,
		"marks": marks,
		"bits": bits,
		"sovereigns": sovereigns,
		"total_distance": total_distance,
		"total_coins_collected": total_coins_collected,
		"total_runs": total_runs,
		"best_distance": best_distance,
		"best_coins_in_run": best_coins_in_run,
		"unlocked_riders": unlocked_riders,
		"unlocked_boards": unlocked_boards,
		"current_rider": current_rider,
		"current_board": current_board,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"screen_shake": screen_shake,
		"haptic_feedback": haptic_feedback,
		"graphics_quality": graphics_quality,
		"last_track_index": last_track_index,
		"ebon_pass_active": ebon_pass_active,
		"last_cache_claim_time": last_cache_claim_time
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("Game saved!")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, using defaults")
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		if save_data is Dictionary:
			# Support old saves (coins) and new saves (marks)
			marks = save_data.get("marks", save_data.get("coins", 0))
			bits = save_data.get("bits", 0)
			sovereigns = save_data.get("sovereigns", 0)
			total_distance = save_data.get("total_distance", 0.0)
			total_coins_collected = save_data.get("total_coins_collected", 0)
			total_runs = save_data.get("total_runs", 0)
			best_distance = save_data.get("best_distance", 0.0)
			best_coins_in_run = save_data.get("best_coins_in_run", 0)
			unlocked_riders = save_data.get("unlocked_riders", ["default"])
			unlocked_boards = save_data.get("unlocked_boards", ["default"])
			current_rider = save_data.get("current_rider", "default")
			current_board = save_data.get("current_board", "default")
			music_volume = save_data.get("music_volume", 1.0)
			sfx_volume = save_data.get("sfx_volume", 1.0)
			screen_shake = save_data.get("screen_shake", true)
			haptic_feedback = save_data.get("haptic_feedback", true)
			graphics_quality = save_data.get("graphics_quality", 1)
			last_track_index = save_data.get("last_track_index", -1)
			# Ebon Pass — defaults to false for old saves
			ebon_pass_active = save_data.get("ebon_pass_active", false)
			last_cache_claim_time = save_data.get("last_cache_claim_time", 0)
			print("Game loaded!")

# ============ CURRENCY ============
func add_coins(amount: int) -> void:
	coins += amount
	total_coins_collected += amount
	save_game()

func spend_marks(amount: int) -> bool:
	if marks >= amount:
		marks -= amount
		save_game()
		return true
	return false

# ============ UNLOCKS ============
func unlock_rider(rider_id: String) -> bool:
	return unlock_rider_with_sovereigns(rider_id)

func unlock_board(board_id: String) -> bool:
	return unlock_board_with_sovereigns(board_id)

func is_rider_unlocked(rider_id: String) -> bool:
	return rider_id in unlocked_riders

func is_board_unlocked(board_id: String) -> bool:
	return board_id in unlocked_boards

func equip_rider(rider_id: String) -> bool:
	if is_rider_unlocked(rider_id):
		current_rider = rider_id
		save_game()
		return true
	return false

func equip_board(board_id: String) -> bool:
	if is_board_unlocked(board_id):
		current_board = board_id
		save_game()
		return true
	return false

# ============ STATS ============
func record_run(distance: float, coins_earned: int) -> void:
	total_runs += 1
	total_distance += distance
	if distance > best_distance:
		best_distance = distance
	if coins_earned > best_coins_in_run:
		best_coins_in_run = coins_earned
	add_coins(coins_earned)

# ============ PERKS ============
func get_current_rider_perk() -> String:
	var rider = RIDERS.get(current_rider)
	if rider:
		return rider.perk
	return "none"

func get_current_board_stats() -> Dictionary:
	var board = BOARDS.get(current_board)
	if board:
		return board.stats
	return {"speed": 1.0, "charge": 1.0, "handling": 1.0}

# ============ INIT ============
func _ready() -> void:
	load_game()
