extends Node

enum {CLIENT, DEBUG_CLIENT, SERVER, SPECTATE}
enum {CLOUD, LOCAL, CUSTOM}
enum {PLAYER, BOT, SLAVE}
enum {TERRAN, CONSTRUCT, ZARKAVAN}
enum {USERNAME,PASSWORD,SCORE,FACTION,ISOTOPES,CONTROLS}

const BUILD_VERSION = "1.0"
var player_database = {}
var players = {}

func _ready():
	print("Basic Authentication Module Loaded")



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

func user_authenticated(network_id, username, password, client_version):
	if client_is_obsolete(client_version):
		print(username + " tried to log on with an obsolete client!")
		rpc_id(network_id, "kick_user", "Authentication failed: Client needs update to connect to this server!!!")
		return false
	if user_exists(username):
		if password_is_correct(username,password):
			if not user_is_online(username):
				print(username + " was succesfully authenticated")
				return true
			else:
				rpc_id(network_id, "kick_user", "Authentication failed: User is already logged in!")
				print(username + " tried to log on twice! ")
				return false
		else:
			rpc_id(network_id, "kick_user", "Authentication failed: Incorrect Password!")
			print(username + " tried to log on with the wrong password!")
			return false
	else:
		create_user(username, password)
		return true

func client_is_obsolete(client_version):
	if client_version != BUILD_VERSION:
		return true
	return false

func create_user(username, password):
	player_database[username] = {}
	player_database[username]["password"] = password
	player_database[username]["data"] = {"username": username, "faction": 0, "isotopes":0, "score": 0}
	print("A new user was created: " + username)
	save_user_data()

func user_exists(username):
	if player_database.has(username):
		return true
	return false

func password_is_correct(username, password):
	if player_database[username]["password"] == password:
		return true
	return false

func user_is_online(username):
	for player in players:
		if players[player]["username"] == username:
			return true
	return false

master func save_user_data():
	#var player_database = {}
	for player in players:
		if players[player]["controls"] != BOT:
			player_database[players[player]["username"]]["data"] = players[player]
	print("Backing up user data...")
	save_file(to_json(player_database))

func save_file(content, filename = "user://player_database.json"):
	var file = File.new()
	file.open(filename, file.WRITE)
	file.store_string(content)
	file.close()

func load_file(filename = "user://player_database.json"):
	var file = File.new()
	file.open(filename, file.READ)
	var database = JSON.parse((file.get_as_text()))
	if typeof(database.result) == TYPE_DICTIONARY:
		print(filename, " successfully loaded!")
		file.close()
		return database.result
	else:
		print(filename, " is not a properly formatted json file!!!")
		return {}