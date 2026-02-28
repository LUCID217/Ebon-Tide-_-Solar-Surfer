extends Node

# AudioManager - Autoload singleton for music and SFX
# Handles: track rotation on login, persistence during runs, crossfade transitions

# Music tracks - paths to audio files
const TRACKS: Array[String] = [
	"res://audio/music/The_Birds.mp3",
	"res://audio/music/The_Brink.mp3",
	"res://audio/music/The_Energy.mp3",
	"res://audio/music/The_Engine.mp3",
	"res://audio/music/The_Maelstrom.mp3",
	"res://audio/music/The_Ride.mp3",
]

# Two players for crossfading
var player_a: AudioStreamPlayer
var player_b: AudioStreamPlayer
var active_player: AudioStreamPlayer
var inactive_player: AudioStreamPlayer

# State
var current_track_index: int = -1
var is_fading: bool = false
var fade_duration: float = 2.0  # Seconds for crossfade
var fade_timer: float = 0.0
var fade_direction: String = ""  # "down", "up", "cross"
var target_volume_db: float = 0.0
var paused_position: float = 0.0

# Session tracking - rotate on login, persist during gameplay
var session_track_set: bool = false

func _ready() -> void:
	# Create two audio players on the Music bus
	player_a = AudioStreamPlayer.new()
	player_a.bus = "Music"
	add_child(player_a)
	
	player_b = AudioStreamPlayer.new()
	player_b.bus = "Music"
	add_child(player_b)
	
	active_player = player_a
	inactive_player = player_b
	
	# Set initial volumes
	player_a.volume_db = 0.0
	player_b.volume_db = -80.0
	
	# Connect finished signals for looping
	player_a.finished.connect(_on_track_finished.bind(player_a))
	player_b.finished.connect(_on_track_finished.bind(player_b))
	
	# Pick a track for this session
	_pick_session_track()
	
	# Apply saved volume
	apply_music_volume(GameData.music_volume)
	apply_sfx_volume(GameData.sfx_volume)

func _process(delta: float) -> void:
	if not is_fading:
		return
	
	fade_timer += delta
	var t = clamp(fade_timer / fade_duration, 0.0, 1.0)
	
	match fade_direction:
		"down":
			# Fade active player down (death/wipe) — lerp all the way to -80dB to avoid pop
			active_player.volume_db = lerp(target_volume_db, -80.0, t)
			if t >= 1.0:
				paused_position = active_player.get_playback_position()
				active_player.volume_db = -80.0
				is_fading = false
		"up":
			# Fade active player up (restart/resume)
			active_player.volume_db = lerp(-80.0, target_volume_db, t)
			if t >= 1.0:
				active_player.volume_db = target_volume_db
				is_fading = false
		"cross":
			# Crossfade between players
			active_player.volume_db = lerp(-80.0, target_volume_db, t)
			inactive_player.volume_db = lerp(target_volume_db, -80.0, t)
			if t >= 1.0:
				inactive_player.stop()
				active_player.volume_db = target_volume_db
				is_fading = false

func _pick_session_track() -> void:
	if TRACKS.is_empty():
		return
	
	# Load last played index from GameData, rotate to next
	var last_index = GameData.last_track_index
	if last_index < 0 or last_index >= TRACKS.size():
		# First ever play — randomize
		current_track_index = randi() % TRACKS.size()
	else:
		# Rotate to next track
		current_track_index = (last_index + 1) % TRACKS.size()
	
	# Save the new index so next session rotates again
	GameData.last_track_index = current_track_index
	GameData.save_game()
	
	session_track_set = true
	print("AudioManager: Session track [", current_track_index, "] ", TRACKS[current_track_index])

func play_music() -> void:
	if TRACKS.is_empty() or current_track_index < 0:
		return
	
	var stream = load(TRACKS[current_track_index])
	if not stream:
		push_warning("AudioManager: Failed to load track: " + TRACKS[current_track_index])
		return
	
	active_player.stream = stream
	active_player.volume_db = _get_music_db()
	active_player.play()
	print("AudioManager: Playing '", TRACKS[current_track_index].get_file(), "'")

func stop_music() -> void:
	active_player.stop()
	inactive_player.stop()
	is_fading = false

## Fade music down (e.g., player dies/wipes)
func fade_down(duration: float = 1.5) -> void:
	if not active_player.playing:
		return
	target_volume_db = _get_music_db()
	fade_duration = duration
	fade_timer = 0.0
	fade_direction = "down"
	is_fading = true

## Fade music back up (e.g., player restarts run)
## Resumes from where it left off - same track, same position
func fade_up(duration: float = 1.5) -> void:
	if TRACKS.is_empty() or current_track_index < 0:
		return
	
	target_volume_db = _get_music_db()
	
	# If not playing, resume from saved position
	if not active_player.playing:
		var stream = load(TRACKS[current_track_index])
		if stream:
			active_player.stream = stream
			active_player.volume_db = -40.0
			active_player.play(paused_position)
	else:
		active_player.volume_db = -40.0
	
	fade_duration = duration
	fade_timer = 0.0
	fade_direction = "up"
	is_fading = true

## Crossfade to a different track
func crossfade_to(track_index: int, duration: float = 2.0) -> void:
	if track_index < 0 or track_index >= TRACKS.size():
		return
	if track_index == current_track_index and active_player.playing:
		return
	
	current_track_index = track_index
	var stream = load(TRACKS[track_index])
	if not stream:
		return
	
	# Swap active/inactive
	var temp = active_player
	active_player = inactive_player
	inactive_player = temp
	
	# Start new track on the now-active player
	active_player.stream = stream
	active_player.volume_db = -80.0
	active_player.play()
	
	target_volume_db = _get_music_db()
	fade_duration = duration
	fade_timer = 0.0
	fade_direction = "cross"
	is_fading = true

## Rotate to next track with crossfade (for session start / menu use)
func rotate_track(duration: float = 2.0) -> void:
	var next = (current_track_index + 1) % TRACKS.size()
	crossfade_to(next, duration)

func _on_track_finished(player: AudioStreamPlayer) -> void:
	# Loop the track
	if player == active_player and not is_fading:
		player.play()

## Volume control - takes 0.0 to 1.0 range
func apply_music_volume(vol: float) -> void:
	var db = linear_to_db(clamp(vol, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)

func apply_sfx_volume(vol: float) -> void:
	var db = linear_to_db(clamp(vol, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)

func _get_music_db() -> float:
	# Returns the target dB for the active player (0 dB = full, bus handles actual volume)
	return 0.0

## Utility: get track name without extension for display
func get_current_track_name() -> String:
	if current_track_index >= 0 and current_track_index < TRACKS.size():
		return TRACKS[current_track_index].get_file().get_basename().replace("_", " ")
	return "None"

func get_track_count() -> int:
	return TRACKS.size()
