extends Node

# EbonPass - Autoload singleton for Ebon Pass IAP
# Add to project.godot autoloads BEFORE AdsManager:
#   EbonPass="*res://scripts/ebon_pass.gd"
#
# Requires: Google Play Billing plugin for Godot 4
# Plugin repo: https://github.com/godotengine/godot-google-play-billing
# Place plugin .aar and .gdap in android/plugins/

# ============================================================
# REPLACE THIS WITH YOUR REAL PRODUCT ID FROM GOOGLE PLAY CONSOLE
const PRODUCT_ID: String = "ebon_pass_monthly"
# ============================================================

const CACHE_GRANT_MARKS: int = 100
const CACHE_INTERVAL_SECONDS: int = 86400  # 24 hours

signal pass_activated
signal pass_restore_failed
signal cache_collected(marks: int)

var _billing_plugin = null
var _plugin_available: bool = false

func _ready() -> void:
	_try_connect_plugin()
	if _plugin_available:
		_billing_plugin.startConnection()

func _try_connect_plugin() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing_plugin = Engine.get_singleton("GodotGooglePlayBilling")
		_plugin_available = true
		_billing_plugin.connected.connect(_on_connected)
		_billing_plugin.disconnected.connect(_on_disconnected)
		_billing_plugin.purchases_updated.connect(_on_purchases_updated)
		_billing_plugin.query_purchases_response.connect(_on_query_purchases_response)
		print("EbonPass: Google Play Billing plugin connected")
	else:
		_plugin_available = false
		print("EbonPass: Billing plugin not available (editor/desktop mode)")

# ============ PUBLIC API ============

func is_active() -> bool:
	return GameData.ebon_pass_active

func purchase() -> void:
	if is_active():
		print("EbonPass: Already active")
		return
	if not _plugin_available:
		print("EbonPass: [PLACEHOLDER] Purchase flow not available in editor")
		return
	_billing_plugin.purchase(PRODUCT_ID)

func restore() -> void:
	if not _plugin_available:
		print("EbonPass: [PLACEHOLDER] Restore not available in editor")
		return
	_billing_plugin.queryPurchases("inapp")

func can_claim_cache() -> bool:
	if not is_active():
		return false
	var now = Time.get_unix_time_from_system()
	return (now - GameData.last_cache_claim_time) >= CACHE_INTERVAL_SECONDS

func claim_cache() -> bool:
	if not can_claim_cache():
		return false
	GameData.add_marks(CACHE_GRANT_MARKS)
	GameData.last_cache_claim_time = int(Time.get_unix_time_from_system())
	GameData.save_game()
	emit_signal("cache_collected", CACHE_GRANT_MARKS)
	print("EbonPass: Claimed daily cache — +%d Marks" % CACHE_GRANT_MARKS)
	return true

func get_cache_seconds_remaining() -> int:
	if not is_active():
		return -1
	var now = Time.get_unix_time_from_system()
	var elapsed = now - GameData.last_cache_claim_time
	var remaining = CACHE_INTERVAL_SECONDS - elapsed
	return max(0, int(remaining))

# ============ PLUGIN CALLBACKS ============

func _on_connected() -> void:
	print("EbonPass: Billing connected — querying purchases")
	_billing_plugin.queryPurchases("inapp")

func _on_disconnected() -> void:
	print("EbonPass: Billing disconnected")

func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		_process_purchase(purchase)

func _on_query_purchases_response(query_result: Dictionary) -> void:
	if query_result.get("status", -1) == 0:
		var purchases = query_result.get("purchases", [])
		for purchase in purchases:
			_process_purchase(purchase)
	else:
		print("EbonPass: Query purchases failed: ", query_result)

func _process_purchase(purchase: Dictionary) -> void:
	var product_id = purchase.get("productId", "")
	if product_id != PRODUCT_ID:
		return
	var purchase_state = purchase.get("purchaseState", -1)
	# purchaseState: 1 = purchased, 4 = pending
	if purchase_state == 1:
		_activate_pass()
		# Acknowledge if not already acknowledged
		if not purchase.get("isAcknowledged", false):
			_billing_plugin.acknowledgePurchase(purchase.get("purchaseToken", ""))
	elif purchase_state == 4:
		print("EbonPass: Purchase pending")

func _activate_pass() -> void:
	if not GameData.ebon_pass_active:
		GameData.ebon_pass_active = true
		GameData.save_game()
		emit_signal("pass_activated")
		print("EbonPass: Pass activated!")
	# Auto-check cache on activation
	_check_daily_cache()

func _check_daily_cache() -> void:
	if can_claim_cache():
		claim_cache()
