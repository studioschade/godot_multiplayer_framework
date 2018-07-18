extends KinematicBody2D
var faction = 0
var role = 0
export (int) var speed = 10
export (float) var rotation_speed = 1.5

var linear_velocity = Vector2()
var rotation_dir = 0
var max_velocity = 20

var my_network_id = 1
var is_online = false

func get_input():
    rotation_dir = 0
   # velocity = Vector2()
    if Input.is_action_pressed('rotate_right'):
        rotation_dir += 1
    if Input.is_action_pressed('rotate_left'):
        rotation_dir -= 1
    if Input.is_action_pressed('thrust_backward'):
        linear_velocity += Vector2(-speed, 0).rotated(rotation)
    if Input.is_action_pressed('thrust_forward'):
        linear_velocity += Vector2(speed, 0).rotated(rotation)
        linear_velocity=linear_velocity.clamped(max_velocity)

func _physics_process(delta):
    get_input()
    linear_velocity += Vector2(0,-1).rotated(get_rotation()) * (speed)
    linear_velocity=linear_velocity.clamped(max_velocity)
    rotation += rotation_dir * rotation_speed * delta
    move_and_collide(linear_velocity)