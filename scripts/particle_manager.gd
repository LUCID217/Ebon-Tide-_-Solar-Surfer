extends Node3D

# Particle Manager - handles all visual effects

var player: CharacterBody3D
var camera: Camera3D

# Particle systems
var boost_trail: GPUParticles3D
var speed_lines: GPUParticles3D
var damage_sparks: GPUParticles3D

## Called by GameManager to inject references
func set_player(p: CharacterBody3D) -> void:
	player = p
	if player:
		create_boost_trail()
		create_damage_sparks()
		print("ParticleManager initialized")

func set_camera(c: Camera3D) -> void:
	camera = c
	if camera:
		create_speed_lines()

func create_boost_trail() -> void:
	boost_trail = GPUParticles3D.new()
	boost_trail.name = "BoostTrail"
	boost_trail.amount = 50
	boost_trail.lifetime = 0.5
	boost_trail.emitting = false
	boost_trail.local_coords = false
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)  # Trail behind
	material.spread = 15.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 12.0
	material.gravity = Vector3(0, -2, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(1.0, 0.6, 0.2, 1.0)  # Orange flame
	
	# Color gradient - orange to transparent
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.7, 0.2, 1.0))
	gradient.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex
	
	boost_trail.process_material = material
	
	# Simple quad mesh for particles
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	boost_trail.draw_pass_1 = mesh
	
	# Bright material
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	
	player.add_child(boost_trail)
	boost_trail.position = Vector3(0, 0, 1.5)  # Behind the engine

func create_speed_lines() -> void:
	speed_lines = GPUParticles3D.new()
	speed_lines.name = "SpeedLines"
	speed_lines.amount = 30
	speed_lines.lifetime = 0.3
	speed_lines.emitting = false
	speed_lines.local_coords = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)
	material.spread = 5.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 30.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.02
	material.scale_max = 0.05
	
	# Emission box around player view
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(3.0, 2.0, 0.5)
	
	material.color = Color(1.0, 1.0, 1.0, 0.6)
	
	speed_lines.process_material = material
	
	# Stretched quad for speed line effect
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.05, 0.8)
	speed_lines.draw_pass_1 = mesh
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mesh.material = draw_mat
	
	# Attach to camera
	if camera:
		camera.add_child(speed_lines)
		speed_lines.position = Vector3(0, 0, -5)

func create_damage_sparks() -> void:
	damage_sparks = GPUParticles3D.new()
	damage_sparks.name = "DamageSparks"
	damage_sparks.amount = 40
	damage_sparks.lifetime = 0.8
	damage_sparks.one_shot = true
	damage_sparks.explosiveness = 0.9
	damage_sparks.emitting = false
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 12.0
	material.gravity = Vector3(0, -15, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15
	
	# Sparky color
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex
	
	damage_sparks.process_material = material
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.15, 0.15)
	damage_sparks.draw_pass_1 = mesh
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	
	player.add_child(damage_sparks)
	damage_sparks.position = Vector3(0, 0.5, 0)

func _process(_delta: float) -> void:
	if not player:
		return
	
	# Boost trail follows boost state
	if boost_trail:
		boost_trail.emitting = player.is_boosting and player.engine_intact
	
	# Speed lines when going fast or boosting
	if speed_lines:
		speed_lines.emitting = player.is_boosting or player.forward_speed > 30

func emit_damage_sparks() -> void:
	if damage_sparks:
		damage_sparks.restart()
		damage_sparks.emitting = true

func emit_coin_collect(pos: Vector3) -> void:
	# Create temporary sparkle at coin position
	var sparkle = GPUParticles3D.new()
	sparkle.amount = 15
	sparkle.lifetime = 0.4
	sparkle.one_shot = true
	sparkle.explosiveness = 0.95
	sparkle.emitting = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -3, 0)
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.color = Color(1.0, 0.9, 0.3, 1.0)
	
	sparkle.process_material = material
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	sparkle.draw_pass_1 = mesh
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	
	get_parent().add_child(sparkle)
	sparkle.global_position = pos
	
	# Auto-cleanup
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(sparkle.queue_free)

func emit_sail_destruction() -> void:
	if not player:
		return
	
	var debris = GPUParticles3D.new()
	debris.amount = 25
	debris.lifetime = 1.2
	debris.one_shot = true
	debris.explosiveness = 0.85
	debris.emitting = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, -1)
	material.spread = 60.0
	material.initial_velocity_min = 4.0
	material.initial_velocity_max = 10.0
	material.gravity = Vector3(0, -8, 5)
	material.angular_velocity_min = -180
	material.angular_velocity_max = 180
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	# Golden sail fragments
	material.color = Color(1.0, 0.85, 0.4, 1.0)
	
	debris.process_material = material
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.25, 0.25)
	debris.draw_pass_1 = mesh
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	
	player.add_child(debris)
	debris.position = Vector3(0, 1.5, 0)  # Where sail was
	
	# Cleanup
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(debris.queue_free)

func emit_engine_destruction() -> void:
	if not player:
		return
	
	var sparks = GPUParticles3D.new()
	sparks.amount = 35
	sparks.lifetime = 0.6
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.emitting = true
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)
	material.spread = 90.0
	material.initial_velocity_min = 6.0
	material.initial_velocity_max = 14.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15
	
	# Electrical sparks - blue/white
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.7, 0.9, 1.0, 1.0))
	gradient.set_color(1, Color(0.3, 0.5, 1.0, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex
	
	sparks.process_material = material
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	sparks.draw_pass_1 = mesh
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat
	
	player.add_child(sparks)
	sparks.position = Vector3(0, 0.1, 1.2)  # At engine
	
	# Cleanup
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(sparks.queue_free)

func reset() -> void:
	if boost_trail:
		boost_trail.emitting = false
	if speed_lines:
		speed_lines.emitting = false
