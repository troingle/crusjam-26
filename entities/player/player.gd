extends CharacterBody3D

@onready var camera: Camera3D = $Head/Camera3D

var jump_velocity = 6.5
var move_speed = 8.1
var auto_bhop = false

var wish_dir = Vector3.ZERO

const HEADBOB_MOVE_AMOUNT = 0.04
const HEADBOB_FREQUENCY = 1.8
var headbob_time = 0.0

# Air movement
var air_cap := 0.94
var air_accel := 800.0
var air_move_speed := 500.0

# Ground movement
var ground_accel := 11.0
var ground_decel := 7.0
var ground_friction := 3.5

var menu_open = false

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not menu_open:
		rotate_y(-event.relative.x * (Global.sensitivity / 1000))
		camera.rotate_x(-event.relative.y * (Global.sensitivity / 1000))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)


func clip_velocity(normal: Vector3, overbounce : float, _delta : float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change := normal * backoff
	self.velocity -= change
	
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func _handle_air_physics(delta) -> void:
	velocity.y += get_gravity().y * delta
	
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
		
	if is_on_wall():
		var wall_normal = get_wall_normal()

		var is_wall_vertical = abs(wall_normal.dot(Vector3.UP)) < 0.1 

		if is_surface_too_steep(wall_normal) and not is_wall_vertical:
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		
		clip_velocity(wall_normal, 1, delta)
	
func _handle_ground_physics(delta) -> void:
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = move_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * move_speed
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
	
	# Apply friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	_headbob_effect(delta)
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"): menu_open = not menu_open
	$CanvasLayer/Menu.visible = menu_open

	if menu_open: 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	wish_dir = global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	if is_on_floor():
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else: _handle_air_physics(delta)
	
	move_and_slide()
	
	#Global.sensitivity = $CanvasLayer/Menu/VBoxContainer/SensSlider.value
	
	
func _on_return_pressed() -> void:
	menu_open = false
