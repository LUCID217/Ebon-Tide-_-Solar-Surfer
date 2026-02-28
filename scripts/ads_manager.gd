extends Node

# AdsManager - Singleton for all AdMob ad calls
# Add to Project Settings > Autoload as "AdsManager"
#
# ALL ad calls flow through this singleton. Every public method checks
# EbonPass.is_active() before doing anything — if the pass is active,
# all ad calls silently no-op.
#
# Depends on:
#   - Godot AdMob plugin (res://android/plugins/GodotAdMob.gdap)
#   - EbonPass autoload (must load before AdsManager)
#   - GameData autoload
#
# Plugin version dependency: godot-admob-android v3.0.0+
# https://github.com/poing-studios/godot-admob-android

# ============ AD UNIT IDS ============
# REPLACE these with your real AdMob IDs before release.
# Current values are Google's official test IDs.

# REPLACE with your real AdMob App ID in AndroidManifest (see PLUGIN_SETUP.md)
# Test App ID: ca-app-pub-3940256099942544~3347511713

const BANNER_ID: String = "ca-app-pub-3940256099942544/6300978111"         # Test banner
const INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"   # Test interstitial
const REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"       # Test rewarded

# ============ CONFIG ============
const DEATHS_PER_INTERSTITIAL: int = 3  # Show interstitial every N deaths

# ============ SIGNALS ============
signal banner_loaded
signal interstitial_loaded
signal interstitial_closed
signal rewarded_ad_loaded
signal rewarded_ad_earned(reward_type: String, reward_amount: int)
signal rewarded_ad_closed
signal ad_failed(ad_type: String, error: String)

# ============ STATE ============
var _admob_plugin = null
var _banner_loaded: bool = false
var _interstitial_loaded: bool = false
var _rewarded_loaded: bool = false
var _death_count: int = 0
var _banner_visible: bool = false

func _ready() -> void:
	_init_admob()

# ============ PASS GATE ============
## Returns true if ads should be suppressed (Ebon Pass active).
func _is_pass_active() -> bool:
	var ebon_pass = get_node_or_null("/root/EbonPass")
	if ebon_pass:
		return ebon_pass.is_active()
	return false

# ============ PUBLIC API: BANNER ============

## Show a banner ad (main menu only). No-ops if Ebon Pass active.
func show_banner() -> void:
	if _is_pass_active():
		print("[AdsManager] Banner suppressed — Ebon Pass active")
		return
	if _admob_plugin:
		if not _banner_loaded:
			_load_banner()
		else:
			_admob_plugin.show_banner()
			_banner_visible = true
	else:
		print("[AdsManager] AdMob not available — banner skipped")

## Hide the banner ad (called when leaving main menu or entering gameplay).
func hide_banner() -> void:
	if _admob_plugin and _banner_visible:
		_admob_plugin.hide_banner()
		_banner_visible = false

## Destroy the banner (cleanup on scene change).
func destroy_banner() -> void:
	if _admob_plugin:
		_admob_plugin.destroy_banner()
		_banner_loaded = false
		_banner_visible = false

# ============ PUBLIC API: INTERSTITIAL ============

## Register a player death. Shows interstitial every DEATHS_PER_INTERSTITIAL deaths.
## Returns true if an interstitial was shown.
func on_player_death() -> bool:
	if _is_pass_active():
		return false

	_death_count += 1
	if _death_count >= DEATHS_PER_INTERSTITIAL:
		_death_count = 0
		return show_interstitial()
	return false

## Show an interstitial ad immediately. No-ops if Ebon Pass active.
func show_interstitial() -> bool:
	if _is_pass_active():
		print("[AdsManager] Interstitial suppressed — Ebon Pass active")
		return false
	if _admob_plugin and _interstitial_loaded:
		_admob_plugin.show_interstitial()
		_interstitial_loaded = false
		# Pre-load next one
		_load_interstitial()
		return true
	else:
		print("[AdsManager] Interstitial not ready — skipping")
		# Try to load for next time
		_load_interstitial()
		return false

# ============ PUBLIC API: REWARDED ============

## Returns true if a rewarded ad is loaded and ready to show.
func is_rewarded_ready() -> bool:
	if _is_pass_active():
		return false
	return _admob_plugin != null and _rewarded_loaded

## Show a rewarded ad. No-ops if Ebon Pass active.
## Reward is delivered via the rewarded_ad_earned signal.
func show_rewarded() -> bool:
	if _is_pass_active():
		print("[AdsManager] Rewarded suppressed — Ebon Pass active")
		return false
	if _admob_plugin and _rewarded_loaded:
		_admob_plugin.show_rewarded()
		_rewarded_loaded = false
		return true
	else:
		print("[AdsManager] Rewarded ad not ready — loading")
		_load_rewarded()
		return false

# ============ ADMOB INIT ============
func _init_admob() -> void:
	if Engine.has_singleton("AdMob"):
		_admob_plugin = Engine.get_singleton("AdMob")

		# Initialize with test mode based on debug builds
		var is_test = OS.is_debug_build()
		_admob_plugin.initialize(is_test, true)  # (is_test, child_directed)

		# Banner signals
		_admob_plugin.banner_loaded.connect(_on_banner_loaded)
		_admob_plugin.banner_failed_to_load.connect(_on_banner_failed)

		# Interstitial signals
		_admob_plugin.interstitial_loaded.connect(_on_interstitial_loaded)
		_admob_plugin.interstitial_failed_to_load.connect(_on_interstitial_failed)
		_admob_plugin.interstitial_closed.connect(_on_interstitial_closed)

		# Rewarded signals
		_admob_plugin.rewarded_ad_loaded.connect(_on_rewarded_loaded)
		_admob_plugin.rewarded_ad_failed_to_load.connect(_on_rewarded_failed)
		_admob_plugin.rewarded_interstitial_closed.connect(_on_rewarded_closed)
		_admob_plugin.user_earned_reward.connect(_on_user_earned_reward)

		# Pre-load ads
		_load_interstitial()
		_load_rewarded()

		print("[AdsManager] AdMob initialized (test mode: ", is_test, ")")
	else:
		print("[AdsManager] AdMob singleton not available (not on Android or plugin missing)")

# ============ LOAD HELPERS ============
func _load_banner() -> void:
	if _admob_plugin and not _is_pass_active():
		# position: TOP=0, BOTTOM=1; size: BANNER=0, ADAPTIVE=2
		_admob_plugin.load_banner(BANNER_ID, 1, 2)

func _load_interstitial() -> void:
	if _admob_plugin and not _is_pass_active():
		_admob_plugin.load_interstitial(INTERSTITIAL_ID)

func _load_rewarded() -> void:
	if _admob_plugin and not _is_pass_active():
		_admob_plugin.load_rewarded(REWARDED_ID)

# ============ BANNER CALLBACKS ============
func _on_banner_loaded() -> void:
	_banner_loaded = true
	banner_loaded.emit()
	print("[AdsManager] Banner loaded")
	# Auto-show if we were trying to show
	if not _is_pass_active():
		_admob_plugin.show_banner()
		_banner_visible = true

func _on_banner_failed(error_code: int) -> void:
	_banner_loaded = false
	ad_failed.emit("banner", str(error_code))
	print("[AdsManager] Banner failed to load: ", error_code)

# ============ INTERSTITIAL CALLBACKS ============
func _on_interstitial_loaded() -> void:
	_interstitial_loaded = true
	interstitial_loaded.emit()
	print("[AdsManager] Interstitial loaded")

func _on_interstitial_failed(error_code: int) -> void:
	_interstitial_loaded = false
	ad_failed.emit("interstitial", str(error_code))
	print("[AdsManager] Interstitial failed to load: ", error_code)

func _on_interstitial_closed() -> void:
	interstitial_closed.emit()
	_load_interstitial()

# ============ REWARDED CALLBACKS ============
func _on_rewarded_loaded() -> void:
	_rewarded_loaded = true
	rewarded_ad_loaded.emit()
	print("[AdsManager] Rewarded ad loaded")

func _on_rewarded_failed(error_code: int) -> void:
	_rewarded_loaded = false
	ad_failed.emit("rewarded", str(error_code))
	print("[AdsManager] Rewarded ad failed to load: ", error_code)

func _on_rewarded_closed() -> void:
	rewarded_ad_closed.emit()
	_load_rewarded()

func _on_user_earned_reward(currency: String, amount: int) -> void:
	rewarded_ad_earned.emit(currency, amount)
	print("[AdsManager] User earned reward: ", amount, " ", currency)
