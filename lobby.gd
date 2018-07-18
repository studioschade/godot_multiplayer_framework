extends Control
var BUILD_VERSION

const DEFAULT_PORT = 8910 # some random number, pick your port properly
const SERVER_IP = "127.0.0.1"
const LOCAL_IP = "127.0.0.1"
var ip_address = SERVER_IP
var port = DEFAULT_PORT

enum {CLIENT, DEBUG_CLIENT, SERVER, SPECTATE}
enum {CLOUD, LOCAL, CUSTOM}
enum {PLAYER, BOT, SLAVE}
enum {TERRAN, CONSTRUCT, ZARKAVAN}
enum {USERNAME,PASSWORD,SCORE,FACTION,ISOTOPES,CONTROLS}

var players = {}
var player_database = {}
var client_username = ''
var client_password = ''
var server_choice = CLOUD
var launch_options = CLIENT

var game = load("res://game.tscn")

func _ready():
	print("Hi")
	#settings.lobby = self
	_setup_network_callbacks()
	_process_flags(OS.get_cmdline_args())
	#player.version = BUILD_VERSION
	launch_game()

func launch_game():
	match(launch_options):
		SERVER:
			print("Launching a server...")
			Engine.target_fps = 60
			_on_host_pressed()
			player_database = load_file()
			$panel.hide()
		DEBUG_CLIENT:
			print("Launching a debug client connected to localhost...")
			server_choice = LOCAL
			_on_join_pressed()
		CLIENT:
			print("Launching a standard client.")
		SPECTATE:
			pass

slave func join_game():
	#var new_game = load("res://scenes/game.tscn").instance()
	#settings.my_network_id = get_tree().get_network_unique_id()
	var new_game = game.instance()
	#call_deferred("add_child", new_game)
	add_child(new_game)

func _connected_ok(): #Only clients run this.
	rpc_id(1, "register_user", get_tree().get_network_unique_id(), client_username, client_password, BUILD_VERSION)

master func register_user(network_id, username, password, client_version):
	if user_authenticated(network_id, username, password, client_version):
		players[network_id] = {}
		players[network_id]["username"] = username
		players[network_id]["controls"] = PLAYER
		players[network_id]["faction"] = int(player_database[username]["data"]["faction"])
#		player.faction = int(player_database[username]["data"]["faction"])
		players[network_id]["isotopes"] = int(player_database[username]["data"]["isotopes"])
		players[network_id]["score"] = int(player_database[username]["data"]["score"])
		print("Server registered " + str(network_id))
		rpc_id(network_id, "update_players", players)
		rpc("update_players", players) #Update all players with new player list
		rpc_id(network_id, "join_game")

master func register_npc(network_id, username, faction):
	players[network_id] = {
		"username": username, "faction": faction, "isotopes":0, "score": 0, "controls": BOT}
	rpc("update_players", players) #Update all players with new player list

slave func update_players(current_players):
	players = current_players
	#$game.update_playerlist()
	#print("Client " + str(get_tree().get_network_unique_id()) + " playerlist: " + str(current_players))

master func remove_user(network_id):
	save_user_data()
	$game.explode_ship(network_id) #Delete the all instances the players ship
	players.erase(network_id)
	print("Server removed " + str(network_id))
	rpc("update_players", players) #Update all players with new player list

slave func kick_user(reason):
	_end_game(reason)

master func change_factions(network_id, faction):
	players[network_id]["faction"] = faction
	#player.faction = faction
	rpc("update_players", players) #Update all players with new faction information

func _player_connected(id):
	pass

func _player_disconnected(id):
	if id == 1:
		_end_game("Server disconnected")
	if (get_tree().is_network_server()):
		remove_user(id)

func _connected_fail(): #Only clients call this
	_set_status("Couldn't connect",false)
	get_tree().set_network_peer(null) #remove peer
	get_node("panel/join").set_disabled(false)
	get_node("advanced/host").set_disabled(false)

func _server_disconnected():
	_end_game("Server disconnected")

func _end_game(with_error=""):
	$panel.show()
	if (has_node("game")):
		#erase game scene
		get_node("game").free() # erase immediately, otherwise network might show errors (this is why we connected deferred above)
	get_tree().set_network_peer(null) #remove peer
	get_node("panel/join").set_disabled(false)
	get_node("advanced/host").set_disabled(false)
	_set_status(with_error,false)

func _set_status(text,isok): #Simple way to show status
	if (isok):
		get_node("panel/status_ok").set_text(text)
		get_node("panel/status_fail").set_text("")
	else:
		get_node("panel/status_ok").set_text("")
		get_node("panel/status_fail").set_text(text)


func _on_host_pressed(): #Start a server
	var host = NetworkedMultiplayerENet.new()
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	var err = host.create_server(port,30)
	if (err!=OK):
		_set_status("Can't host, address in use.",false)
		return
	get_tree().set_network_peer(host)
	OS.set_window_size(Vector2(240,350))
	#get_node("panel/join").set_disabled(true)
	#get_node("panel/host").set_disabled(true)
	hide()
	join_game()




func _on_connect_to_local_pressed():
	server_choice = LOCAL
	_on_join_pressed()

func _on_connect_to_cloud_pressed():
	server_choice = CLOUD
	_on_join_pressed()

func _on_join_pressed(): #Start a client
	if server_choice == CLOUD:
		ip_address = SERVER_IP
	elif server_choice == LOCAL:
		ip_address = LOCAL_IP
	elif server_choice == CUSTOM:
		print("Trying to connect to custom server")
	if launch_options == DEBUG_CLIENT:
		client_username = "debug_client"
		client_password = "foomanchu"
		ip_address = LOCAL_IP
	else:
		client_username = get_node("panel/username").get_text()
		client_password = get_node("panel/password").get_text()
	if client_username == "" or client_password ==  "":
		_set_status("You must enter a username and password to continue!",false)
		return
	if (not ip_address.is_valid_ip_address()):
		_set_status("IP address is invalid",false)
		return
	var host = NetworkedMultiplayerENet.new()
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	host.create_client(ip_address,port)
	get_tree().set_network_peer(host)
	_set_status("Connecting..",true)

func _on_server_selector_item_selected( ID ):
	server_choice = ID
	$panel/address.show()

func _setup_network_callbacks():
	get_tree().connect("network_peer_connected",self,"_player_connected")
	get_tree().connect("network_peer_disconnected",self,"_player_disconnected")
	get_tree().connect("connected_to_server",self,"_connected_ok")
	get_tree().connect("connection_failed",self,"_connected_fail")
	get_tree().connect("server_disconnected",self,"_server_disconnected")


func _process_flags(flags):
	for flag in flags:
		match(flag):
			"-server":
				launch_options = SERVER
			"-debug_client":
				launch_options = DEBUG_CLIENT
			"-spectate":
				launch_options = SPECTATE

func _on_advanced_toggled(button_pressed):
	if button_pressed:
		$advanced.show()
	else:
		$advanced.hide()

func _on_port_text_entered(new_text):
	if typeof(new_text) == TYPE_INT:
		port = new_text

func _on_ip_address_text_entered(new_text):
	ip_address = new_text

func _on_connect_to_ip_pressed():
	server_choice = CUSTOM
