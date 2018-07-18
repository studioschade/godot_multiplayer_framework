extends Button

var drag_start
#var lobby_scene = load("res://lobby.tscn")

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here.
	pass

func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_window()

func _on_play_pressed():
	print("Play!")
	#var lobby = lobby_scene.instance()
	#call_deferred("add_child", new_game)
	#add_child(lobby)

func _on_settings_pressed():
	print("Settings!")

func _on_quit_pressed():
	get_tree().quit()

func _on_menu_pressed():
	$main_menu.show()

func _on_menu_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			if event.pressed:
				drag_start = true
			else:
				drag_start = false
	if event is InputEventMouseMotion:
		if drag_start:
			self.rect_global_position = get_global_mouse_position() - Vector2(50,15)
			#update()

func _on_connect_toggled(pressed):
	if pressed:
		print("Show connection UI")
	else:
		print("Hide connection UI")

func toggle_window():
	if $main_menu.visible:
		$main_menu.hide()
	else:
		$main_menu.show()

func _on_close_menu_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			if event.pressed:
				toggle_window()

