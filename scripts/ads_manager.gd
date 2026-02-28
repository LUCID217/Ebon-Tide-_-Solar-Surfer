extends Node

# AdsManager - Autoload singleton for AdMob ads
# Add to project.godot autoloads AFTER EbonPass:
#   AdsManager="*res://scripts/ads_manager.gd"
#
# Requires: Godot AdMob Plugin for Android
# Plugin repo: https://github.com/Shin-NiL/Godot-Android-Admob-Plugin
# Place plugin .aar and .gdap in android/plugins/

# ============================================================
# REPLACE THESE WITH YOUR REAL ADMOB IDs FROM ADMOB CONSOLE
# Current values are Google's official test IDs - safe to use during development
const ADMOB_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"        # TEST - replace with real App ID
const BANNER_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/6300978111"   # TEST banner
const INTERSTITIAL_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/1033173712"  # TEST interstitial
const REWARDED_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/5224354917" # TEST rewarded
# ============================================================

const DEATHS_PER_INTERSTITIAL: int = 3

signal rewarded_ad_watched(reward_type: String, reward_amount: int)

var _admob = null
var _plugin_available: bool = false
var _death_count: int = 0
var _interstitial_loaded: bool = false
var _rewarded_loaded: bool = false
var _banner_showing: bool = false

func _ready() -> void:
	_try_connect_plugin()

func _try_connect_plugin() -> void:
	if Engine.has_singleton("AdMob"):
		_admob = Engine.get_singleton("AdMob")
		_plugin_available = true
		_admob.banner_failed_to_load.connect(_on_banner_failed)
		_admob.interstitial_loaded.connect(_on_interstitial_loaded)
		_admob.interstitial_failed_to_load.connect(_on_interstitial_failed)
		_admob.rewarded_video_loaded.connect(_on_rewarded_loaded)
		_admob.rewarded_video_failed_to_load.connect(_on_rewarded_failed)
		_admob.rewarded_video_rewarded.connect(_on_rewarded_earned)
		_load_interstitial()
		_load_rewarded()
		print("AdsManager: AdMob plugin connected")
	else:
		_plugin_available = false
		print("AdsManager: AdMob plugin not available (editor/desktop mode)")

# ============ PUBLIC API ============

func show_banner() -> void:
	if _is_pass_active():
		return
	if not _plugin_available:
		print("AdsManager: [PLACEHOLDER] Banner would show here")
		return
	if _banner_showing:
		return
	_admob.loadBanner(BANNER_AD_UNIT_ID, true, 0)  # true=top, 0=adaptive size
	_banner_showing = true

func hide_banner() -> void:
	if not _plugin_available:
		return
	if _banner_showing:
		_admob.hideBanner()
		_banner_showing = false

func destroy_banner() -> void:
	if not _plugin_available:
		return
	_admob.removeBanner()
	_banner_showing = false

func on_player_death() -> void:
	if _is_pass_active():
		return
	_death_count += 1
	if _death_count >= DEATHS_PER_INTERSTITIAL:
		_death_count = 0
		_show_interstitial()

func show_rewarded() -> void:
	if _is_pass_active():
		# Pass holders get the reward without watching
		emit_signal("rewarded_ad_watched", "bits", 3)
		return
	if not _plugin_available:
		print("AdsManager: [PLACEHOLDER] Rewarded ad would show here")
		emit_signal("rewarded_ad_watched", "bits", 3)
		return
	if _rewarded_loaded:
		_admob.showRewardedVideo()
	else:
		print("AdsManager: Rewarded ad not ready yet")
		_load_rewarded()

func is_rewarded_ready() -> bool:
	if _is_pass_active():
		return true  # Pass holders always have it available
	return _rewarded_loaded

# ============ PRIVATE ============

func _is_pass_active() -> bool:
	# Safe check — EbonPass autoload may not exist in editor
	var ebon_pass = get_node_or_null("/root/EbonPass")
	if ebon_pass and ebon_pass.has_method("is_active"):
		return ebon_pass.is_active()
	if get_node_or_null("/root/GameData"):
		return GameData.ebon_pass_active
	return false

func _show_interstitial() -> void:
	if not _plugin_available:
		print("AdsManager: [PLACEHOLDER] Interstitial would show here")
		return
	if _interstitial_loaded:
		_admob.showInterstitial()
		_interstitial_loaded = false
		_load_interstitial()  # Pre-load next one immediately
	else:
		print("AdsManager: Interstitial not ready, skipping")

func _load_interstitial() -> void:
	if not _plugin_available:
		return
	_admob.loadInterstitial(INTERSTITIAL_AD_UNIT_ID)

func _load_rewarded() -> void:
	if not _plugin_available:
		return
	_admob.loadRewardedVideo(REWARDED_AD_UNIT_ID)

# ============ PLUGIN CALLBACKS ============

func _on_banner_failed(error_code: int) -> void:
	print("AdsManager: Banner failed to load, error: ", error_code)
	_banner_showing = false

func _on_interstitial_loaded() -> void:
	_interstitial_loaded = true
	print("AdsManager: Interstitial loaded")

func _on_interstitial_failed(error_code: int) -> void:
	_interstitial_loaded = false
	print("AdsManager: Interstitial failed, error: ", error_code)

func _on_rewarded_loaded() -> void:
	_rewarded_loaded = true
	print("AdsManager: Rewarded ad loaded")

func _on_rewarded_failed(error_code: int) -> void:
	_rewarded_loaded = false
	print("AdsManager: Rewarded failed, error: ", error_code)

func _on_rewarded_earned(currency: String, amount: int) -> void:
	emit_signal("rewarded_ad_watched", currency, amount)
	_rewarded_loaded = false
	_load_rewarded()  # Pre-load next one
