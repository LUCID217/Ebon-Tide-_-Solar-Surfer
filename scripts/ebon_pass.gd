extends Node

# EbonPass - Singleton for Ebon Pass IAP (ad-free + Sovereign Cache)
# Add to Project Settings > Autoload as "EbonPass"
#
# Depends on:
#   - Godot Google Play Billing plugin (res://android/plugins/GodotGooglePlayBilling.gdap)
#   - GameData autoload (must load before EbonPass)
#
# Plugin version dependency: godot-google-play-billing v2.1.0+
# https://github.com/godotengine/godot-google-play-billing

# ============ PRODUCT CONFIG ============
# REPLACE with your real product ID from Google Play Console
const PRODUCT_ID: String = "ebon_pass_monthly"

# Sovereign Cache: bonus currency grant for active Ebon Pass holders
# 2 Sovereigns every 8 hours — meaningful but not economy-breaking
# (A full-price rider costs 48 Sovereigns, so ~8 days of caches = 1 rider)
const CACHE_GRANT_SOVEREIGNS: int = 2
const CACHE_INTERVAL_SECONDS: int = 28800  # 8 hours

# ============ SIGNALS ============
signal purchase_completed(success: bool)
signal purchase_restored(success: bool)
signal cache_collected(sovereigns: int)

# ============ STATE ============
var _billing_plugin = null  # Reference to GodotGooglePlayBilling singleton
var _connected: bool = false

func _ready() -> void:
	_init_billing()
	_check_sovereign_cache()

# ============ PUBLIC API ============

## Returns true if Ebon Pass is currently active (purchased and persisted).
func is_active() -> bool:
	return GameData.ebon_pass_active

## Initiate an Ebon Pass purchase flow via Google Play Billing.
func purchase() -> void:
	if is_active():
		print("[EbonPass] Already active, skipping purchase")
		purchase_completed.emit(true)
		return

	if _billing_plugin and _connected:
		print("[EbonPass] Launching purchase flow for: ", PRODUCT_ID)
		_billing_plugin.purchase(PRODUCT_ID)
	else:
		print("[EbonPass] Billing not available — granting pass for testing")
		_grant_pass()

## Restore previous purchases (e.g. after reinstall).
func restore() -> void:
	if _billing_plugin and _connected:
		print("[EbonPass] Querying purchases for restore...")
		_billing_plugin.queryPurchases("inapp")  # non-consumable
	else:
		print("[EbonPass] Billing not available — cannot restore")
		purchase_restored.emit(false)

# ============ BILLING INIT ============
func _init_billing() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing_plugin = Engine.get_singleton("GodotGooglePlayBilling")

		# Connection signals
		_billing_plugin.connected.connect(_on_connected)
		_billing_plugin.disconnected.connect(_on_disconnected)
		_billing_plugin.connect_error.connect(_on_connect_error)

		# Purchase signals
		_billing_plugin.purchases_updated.connect(_on_purchases_updated)
		_billing_plugin.purchase_error.connect(_on_purchase_error)

		# Query signals (for restore)
		_billing_plugin.query_purchases_response.connect(_on_query_purchases_response)

		_billing_plugin.startConnection()
		print("[EbonPass] Billing plugin found, connecting...")
	else:
		print("[EbonPass] GodotGooglePlayBilling not available (not on Android or plugin missing)")

# ============ CONNECTION CALLBACKS ============
func _on_connected() -> void:
	_connected = true
	print("[EbonPass] Billing connected")
	# Query existing purchases on connect (handles restore-on-launch)
	_billing_plugin.queryPurchases("inapp")

func _on_disconnected() -> void:
	_connected = false
	print("[EbonPass] Billing disconnected")

func _on_connect_error(response_id: int, message: String) -> void:
	_connected = false
	print("[EbonPass] Billing connect error: ", response_id, " - ", message)

# ============ PURCHASE CALLBACKS ============
func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		if purchase.sku == PRODUCT_ID:
			if not purchase.is_acknowledged:
				_billing_plugin.acknowledgePurchase(purchase.purchase_token)
			_grant_pass()
			return
	# Purchase list didn't contain our product
	print("[EbonPass] Purchase updated but product not found in list")

func _on_purchase_error(response_id: int, message: String) -> void:
	print("[EbonPass] Purchase error: ", response_id, " - ", message)
	purchase_completed.emit(false)

# ============ QUERY (RESTORE) CALLBACKS ============
func _on_query_purchases_response(query_result) -> void:
	if query_result.status == OK:
		for purchase in query_result.purchases:
			if purchase.sku == PRODUCT_ID:
				_grant_pass()
				purchase_restored.emit(true)
				print("[EbonPass] Restored Ebon Pass from previous purchase")
				return
	print("[EbonPass] No previous Ebon Pass purchase found")
	purchase_restored.emit(false)

# ============ GRANT / REVOKE ============
func _grant_pass() -> void:
	if not GameData.ebon_pass_active:
		GameData.ebon_pass_active = true
		# Initialize cache timer on first activation
		GameData.last_cache_claim_time = int(Time.get_unix_time_from_system())
		GameData.save_game()
		print("[EbonPass] Ebon Pass ACTIVATED")
	purchase_completed.emit(true)

# ============ SOVEREIGN CACHE ============
## Periodic free currency grant for Ebon Pass holders.
## Called on startup and can be called from UI to collect.
func _check_sovereign_cache() -> void:
	if not is_active():
		return

	var now = int(Time.get_unix_time_from_system())
	var elapsed = now - GameData.last_cache_claim_time

	if elapsed >= CACHE_INTERVAL_SECONDS:
		# Calculate how many intervals have passed (cap at 3 to prevent abuse)
		var intervals = mini(elapsed / CACHE_INTERVAL_SECONDS, 3)
		var total_grant = CACHE_GRANT_SOVEREIGNS * intervals
		GameData.add_sovereigns(total_grant)
		GameData.last_cache_claim_time = now
		GameData.save_game()
		cache_collected.emit(total_grant)
		print("[EbonPass] Sovereign Cache collected: ", total_grant, " Sovereigns (", intervals, " intervals)")

## Returns seconds until next cache is available, or 0 if ready now.
func get_cache_time_remaining() -> int:
	if not is_active():
		return -1
	var now = int(Time.get_unix_time_from_system())
	var elapsed = now - GameData.last_cache_claim_time
	var remaining = CACHE_INTERVAL_SECONDS - elapsed
	return maxi(remaining, 0)

## Manually collect cache (called from UI button).
func collect_cache() -> bool:
	if not is_active():
		return false
	if get_cache_time_remaining() > 0:
		return false
	_check_sovereign_cache()
	return true
