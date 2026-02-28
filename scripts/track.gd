extends Node3D

const LANE_WIDTH: float = 3.0
const TRACK_SEGMENT_LENGTH: float = 50.0
const NUM_SEGMENTS: int = 6
const RAIL_HEIGHT: float = 0.1

# Zone enum
enum Zone { SHADOW, LIGHT, SUPER_LIGHT }

var segments: Array[MeshInstance3D] = []
var rails: Array[MeshInstance3D] = []
var player: CharacterBody3D
var floor_body: StaticBody3D

# Materials for each zone
var shadow_track_material: StandardMaterial3D
var shadow_rail_material: StandardMaterial3D
var light_track_material: StandardMaterial3D
var light_rail_material: StandardMaterial3D
var super_track_material: StandardMaterial3D
var super_rail_material: StandardMaterial3D

func _ready() -> void:
	create_materials()
	create_floor()
	create_track_segments()
	create_lane_rails()
	create_environment()

func set_player(p: CharacterBody3D) -> void:
	player = p

func create_materials() -> void:
	# Shadow zone - deep graphite blue-black
	shadow_track_material = StandardMaterial3D.new()
	shadow_track_material.albedo_color = Color(0.078, 0.1, 0.18)  # Graphite Blue-Black #141A2E
	shadow_track_material.metallic = 0.1
	shadow_track_material.roughness = 0.9
	
	shadow_rail_material = StandardMaterial3D.new()
	shadow_rail_material.albedo_color = Color(0.24, 0.66, 1.0)  # Electric Blue #3DA9FF
	shadow_rail_material.emission_enabled = true
	shadow_rail_material.emission = Color(0.24, 0.66, 1.0)  # Electric Blue glow
	shadow_rail_material.emission_energy_multiplier = 1.2
	
	# Light zone - warm gold lanes on dark track
	light_track_material = StandardMaterial3D.new()
	light_track_material.albedo_color = Color(0.078, 0.1, 0.18)  # Same graphite base
	light_track_material.metallic = 0.15
	light_track_material.roughness = 0.85
	
	light_rail_material = StandardMaterial3D.new()
	light_rail_material.albedo_color = Color(1.0, 0.85, 0.4)  # Solar Gold #FFD966
	light_rail_material.emission_enabled = true
	light_rail_material.emission = Color(1.0, 0.85, 0.4)  # Solar Gold glow
	light_rail_material.emission_energy_multiplier = 1.8
	
	# Super light zone - radiant white-cyan
	super_track_material = StandardMaterial3D.new()
	super_track_material.albedo_color = Color(0.1, 0.12, 0.2)  # Slightly lighter graphite
	super_track_material.metallic = 0.2
	super_track_material.roughness = 0.8
	
	super_rail_material = StandardMaterial3D.new()
	super_rail_material.albedo_color = Color(0.92, 0.965, 1.0)  # Cold Star White #EAF6FF
	super_rail_material.emission_enabled = true
	super_rail_material.emission = Color(0.37, 0.91, 1.0)  # Aurora Cyan #5FE7FF
	super_rail_material.emission_energy_multiplier = 3.8

func create_floor() -> void:
	floor_body = StaticBody3D.new()
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(LANE_WIDTH * 6, 1.0, 10000.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0, -0.5, -5000.0)
	add_child(floor_body)

func create_track_segments() -> void:
	for i in range(NUM_SEGMENTS):
		var segment = create_track_segment()
		segment.position.z = -i * TRACK_SEGMENT_LENGTH
		add_child(segment)
		segments.append(segment)

func create_track_segment() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = BoxMesh.new()
	plane_mesh.size = Vector3(LANE_WIDTH * 4, 0.2, TRACK_SEGMENT_LENGTH)
	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = light_track_material
	return mesh_instance

func create_lane_rails() -> void:
	for lane in [-1, 0, 1]:
		var rail = create_rail(lane * LANE_WIDTH)
		add_child(rail)
		rails.append(rail)

func create_rail(x_pos: float) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, RAIL_HEIGHT, 10000.0)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(x_pos, 0.15, -5000.0)
	mesh_instance.material_override = light_rail_material
	return mesh_instance

func create_environment() -> void:
	# Environment visuals now handled by VoxIgnisEnvironment
	pass

func set_zone(zone: int) -> void:
	var track_mat: StandardMaterial3D
	var rail_mat: StandardMaterial3D
	
	match zone:
		Zone.SHADOW:
			track_mat = shadow_track_material
			rail_mat = shadow_rail_material
		Zone.LIGHT:
			track_mat = light_track_material
			rail_mat = light_rail_material
		Zone.SUPER_LIGHT:
			track_mat = super_track_material
			rail_mat = super_rail_material
	
	for segment in segments:
		segment.material_override = track_mat
	
	for rail in rails:
		rail.material_override = rail_mat

func _process(_delta: float) -> void:
	if player == null or player.is_dead:
		return

	var player_z = player.position.z

	# Keep floor and rails centered on the player so they never outrun the geometry
	if floor_body:
		floor_body.position.z = player_z
	for rail in rails:
		rail.position.z = player_z

	for segment in segments:
		if segment.position.z > player_z + TRACK_SEGMENT_LENGTH:
			var min_z = 0.0
			for s in segments:
				if s.position.z < min_z:
					min_z = s.position.z
			segment.position.z = min_z - TRACK_SEGMENT_LENGTH

func reset_track() -> void:
	for i in range(segments.size()):
		segments[i].position.z = -i * TRACK_SEGMENT_LENGTH
	# Reset floor and rails back to origin
	if floor_body:
		floor_body.position.z = -5000.0
	for rail in rails:
		rail.position.z = -5000.0
	set_zone(Zone.LIGHT)
