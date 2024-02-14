extends CharacterBody3D

@onready var camera = $Camera3D
@onready var animplayer = $AnimationPlayer
@onready var raycast = $Camera3D/RayCast3D
@onready var gun = $Camera3D/Rifle

var sensitivity = 0.05
var direction = Vector3()
var wish_jump
var friction = 8
var ads

const MAX_VELOCITY_AIR = 0.6
const MAX_VELOCITY_GROUND = 5.5
const MAX_ACCELERATION = 8 * MAX_VELOCITY_GROUND
const GRAVITY = 9.8
const STOP_SPEED = 1.5
const JUMP_IMPULSE = sqrt(2 * GRAVITY * 0.85)

var RAYS = []
var POINTS = []

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if velocity.y <= 0 and not is_on_floor() and not ["shoot", "ads_shoot", "ads_idle", "ads"].any(func(anim): return anim == animplayer.current_animation):
		animplayer.play("fall")
	_shoot()
	process_input()
	process_movement(delta)
	move_and_slide()
	_delete_objects(delta)
	if not Input.is_action_pressed("shoot"):
		_recoil_reset(delta)

func process_input():
	direction = Vector3()
	
	if Input.is_action_pressed("forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("right"):
		direction += transform.basis.x
		
	# Jumping
	wish_jump = Input.is_action_just_pressed("jump")
	
	ads = Input.is_action_pressed("ads")
	if ads and not ["ads_idle", "ads_shoot"].any(func(anim): return anim == animplayer.current_animation):
		animplayer.play("ads")

func process_movement(delta):
	var wish_dir = direction.normalized()
	if not ["shoot", "fall", "ads_shoot"].any(func(anim): return anim == animplayer.current_animation):
		if not wish_dir.is_zero_approx():
			animplayer.play("run")
		else:
			if ads:
				animplayer.play("ads_idle")
			else:
				animplayer.play("idle")

	if is_on_floor():
		if wish_jump:
			velocity.y = JUMP_IMPULSE
			velocity = update_velocity_air(wish_dir, delta)
			wish_jump = false
		else:
			velocity = update_velocity_ground(wish_dir, delta)
	else:
		velocity.y -= GRAVITY * delta
		velocity = update_velocity_air(wish_dir, delta)

	move_and_slide()

func accelerate(wish_dir: Vector3, max_velocity: float, delta):
	var current_speed = velocity.dot(wish_dir)
	var add_speed = clamp(max_velocity - current_speed, 0, MAX_ACCELERATION * delta)
	
	return velocity + add_speed * wish_dir
	
func update_velocity_ground(wish_dir: Vector3, delta):
	var speed = velocity.length()
	
	if speed != 0:
		var control = max(STOP_SPEED, speed)
		var drop = control * friction * delta
		
		velocity *= max(speed - drop, 0) / speed
	
	return accelerate(wish_dir, MAX_VELOCITY_GROUND, delta)
	
func update_velocity_air(wish_dir: Vector3, delta):
	return accelerate(wish_dir, MAX_VELOCITY_AIR, delta)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		camera.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _delete_objects(delta):
	for i in RAYS:
		i[1] = i[1] - delta
		if i[1] < 0:
			i[0].queue_free()
			RAYS.erase(i)
	for i in POINTS:
		i[1] = i[1] - delta
		if i[1] < 0:
			i[0].queue_free()
			POINTS.erase(i)

func _recoil_reset(delta):
	var a = Quaternion(raycast.transform.basis)
	var b = Quaternion()
	var c = a.slerp(b, delta*5)
	raycast.transform.basis = Basis(c)
	
func _shoot():
	if Input.is_action_pressed("shoot") and animplayer.current_animation != "shoot" and animplayer.current_animation != "ads_shoot":
		play_shoot_effect()
			
func play_shoot_effect():
	animplayer.stop()
	if ads:
		animplayer.play("ads_shoot")
	else:
		animplayer.play("shoot")
	_debug_raycast()
	_recoil()
	
func _recoil():
	if not ads:
		raycast.rotate_y(randf_range(-0.02, 0.02))
		raycast.rotate_x(randf_range(0, 0.05))
	else:
		rotate_y(randf_range(-0.02, 0.02))
		camera.rotate_x(randf_range(0, 0.05))
		
func _debug_raycast():
	var point = raycast.get_collision_point()
	RAYS.append([Draw3d.line(to_global(camera.position), point), 5.0])
	POINTS.append([Draw3d.point(point), 5.0])
