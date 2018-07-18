extends Node2D

enum {PLAYER, BOT, SLAVE} # Ship Owner
enum {TERRAN, CONSTRUCT, ZARKAVAN, HIVE} # Factions
enum {FIGHTER, SUPPORT, MOTHERSHIP} # Ship types
enum {NONE, PLAYER_ONLY, ALL_PLAYERS, BOTS} #Lighting Options
const race_name = {TERRAN: "Post-Human", CONSTRUCT:"Construct", ZARKAVAN: "Zarkavan", HIVE: "Hive"}

var scenes = {
	"home": "res://scenes/shared_universe.tscn",
	"test": "res://scenes/ships/fleet_test_scene.tscn"
}

var current_scene
var current_scene_name

func load_scene(scene_name = "home"):
	if scene_name in scenes:
		current_scene = load(scenes[scene_name])

# Preload the objects that will be dynamically instanced
#var kinematic_ship = preload("res://scenes/kinematic_ship.tscn") # generic player ship scene
var kinematic_ship = preload("res://scenes/ships/ship_fitted.tscn")
var resource = preload("res://scenes/resource.tscn") #generic resource scene
var resource_id = 0 # used as a resource identifier
var resources = [] # stores the resource instances
var resource_values = {"isotopes": 50}

var npc_id = 100
var lobby
var my_network_id
var username
var diplomacy
var is_level_loaded = false



func _ready():
	# If its a network game, join it.
	settings.game = self
	lobby = get_parent()
	if get_tree().has_network_peer():
		my_network_id = get_tree().get_network_unique_id()
		player.network_id = my_network_id
		#lobby = get_parent()
		if get_tree().get_network_unique_id() != 1:
			activate_gui()
			join_network_game()
		else:
			hide()
	else:
		activate_gui()
		join_solo_game()

func activate_gui():
	$gui.add_child(load("res://scenes/gui.tscn").instance())
	if get_tree().get_nodes_in_group("Diplomacy_Panel"):
		diplomacy = get_tree().get_nodes_in_group("Diplomacy_Panel")[0]

func _process(delta):
	if not is_level_loaded:
		if settings.level:
			settings.level.load_scene()
			set_process(false)


func join_solo_game():
	username = "test_ship"
	player.username = username
	player.faction = 0
	my_network_id = 1000
		#request_faction_change", get_tree().get_network_unique_id(), faction)
	#request_new_ship(1000)
	spawn_mothership(1000, 0, "test_ship")
	#get_node("../control").show()

slave func join_network_game():
	username = lobby.players[my_network_id]["username"]
	player.username = username
	player.faction = lobby.players[my_network_id]["faction"]
	#player.network_id = my_network_id
	#Spawn any pre-existing Player ships
	for network_id in lobby.players:
		if network_id != my_network_id:
			spawn_mothership(network_id)
	#rpc_id(1, "request_new_ship", my_network_id)
	rpc("add_item_to_chat", username + " has connected.")
	race_selection()

func race_selection():
	$gui/control.hide()
	$gui.add_child(load("res://scenes/gui/race_selection.tscn").instance())

master func create_npc(npc_faction):
	npc_id += 1
	var npc_name
	if npc_faction == TERRAN:
		npc_name = "Terran Support"
	if npc_faction == CONSTRUCT:
		npc_name = "Construct Drone"
	if npc_faction == ZARKAVAN:
		npc_name = "Ancient Protector"
	lobby.register_npc(npc_id, npc_name, npc_faction)
	request_new_ship(npc_id)


############################SHIP STUFF############################
func _on_spawn_timer_timeout():
	if my_network_id != 1:
		rpc_id(1, "request_new_ship", my_network_id)

master func request_new_ship(network_id):
	if not self.has_node(str(network_id)):
		spawn_mothership(network_id) # Sever creates a ship instance for itself
	rpc("spawn_mothership", network_id) # Sever creates a ship instance for all the clients
	rpc("update_playerlist")

	#spawn_ship(network_id) # Sever creates a ship instance for itself
	#rpc("spawn_ship", network_id) # Sever creates a ship instance for all the clients

remote func spawn_ship(network_id):
	if not self.has_node(str(network_id)):
		var new_ship = kinematic_ship.instance()
		new_ship.set_name(str(network_id))
		new_ship.username = lobby.players[network_id]["username"]
		new_ship.my_network_id = network_id
		new_ship.faction = lobby.players[network_id]["faction"]
		new_ship.last_player_to_hit = null
		if lobby.players[network_id]["controls"] == BOT:
			new_ship.role = SUPPORT
			new_ship.set_network_master(1)
			if get_tree().is_network_server():
				new_ship.controls = BOT
				new_ship.configure_ai()
			else:
				new_ship.controls = SLAVE
		elif lobby.players[network_id]["controls"] == PLAYER:
			new_ship.role = PLAYER
			player.faction = lobby.players[network_id]["faction"]
			if my_network_id !=1:
				player.ship_panel.update_gui(player.faction)
			new_ship.set_network_master(network_id)
			if network_id == my_network_id:
				new_ship.controls = PLAYER
			else:
				new_ship.controls = SLAVE
		new_ship.spawnpoint = get_spawnpoint(lobby.players[network_id]["faction"])
		new_ship.global_position = new_ship.spawnpoint
		add_child(new_ship)
		print(str(my_network_id) + " spawning a ship for " + str(network_id))

remote func spawn_mothership(network_id, new_faction=null, new_username=null):
	if not self.has_node(str(network_id)):
		var new_ship = kinematic_ship.instance()
		new_ship.set_name(str(network_id))
		new_ship.my_network_id = network_id
		if new_faction != null:
			new_ship.faction = new_faction
		else:
			new_ship.faction = lobby.players[network_id]["faction"]
		if new_username:
			new_ship.username = new_username
		else:
			new_ship.username = lobby.players[network_id]["username"]
		new_ship.last_player_to_hit = null
		new_ship.role = MOTHERSHIP
		#WHy is this here??
		#player.faction = lobby.players[network_id]["faction"]
		if my_network_id !=1:
			player.ship_panel.update_gui(player.faction)
		new_ship.set_network_master(network_id)
		new_ship.spawnpoint = get_spawnpoint(new_ship.faction)
		new_ship.global_position = new_ship.spawnpoint
		if network_id == my_network_id:
			new_ship.controls = PLAYER
		else:
			new_ship.controls = SLAVE
		add_child(new_ship)
		print(str(my_network_id) + " spawning a ship for " + str(network_id))


master func report_death(network_id, killer_id = null, death_location = null):
	if get_node(str(network_id)).last_player_to_hit != null:
		killer_id = get_node(str(network_id)).last_player_to_hit
		if killer_id in lobby.players and network_id in lobby.players:
			var alert =  "%s was killed by %s" % [
			lobby.players[int(network_id)]["username"],
			lobby.players[int(killer_id)]["username"]]
			rpc("add_item_to_chat", alert)
	if killer_id != null:
		if killer_id != network_id and killer_id in lobby.players:
			update_score(killer_id)
	request_resource(death_location)  #Server asks itself to make the resource

master func delete_bot(network_id):
	if lobby.players[network_id]["controls"] == BOT:
		lobby.players.erase(network_id)
		get_parent().rpc("update_players", lobby.players)

master func kill_bots():
	pass

master func update_score(network_id, amount = 1000):
	if network_id in lobby.players:
		lobby.players[network_id]["score"] += amount
		get_parent().rpc("update_players", lobby.players)
		#update_playerlist()
		rpc("update_playerlist")

slave func update_playerlist():
	if diplomacy:
		diplomacy.chart.clear()
	for player in lobby.players:
		if lobby.players[player]["controls"] == PLAYER:
			diplomacy.chart.add_item(lobby.players[player]["username"])
			diplomacy.chart.add_item(race_name[lobby.players[player]["faction"]])
			diplomacy.chart.add_item(str(lobby.players[player]["score"]))
			#if player == my_network_id:
				#$gui/control/score/player_score.set_text(str(lobby.players[my_network_id]["score"]))
				#$gui/control/manage/build/resources/isotopes.set_text(str(lobby.players[my_network_id]["isotopes"]))
# Faction stuff
master func request_faction_change(network_id, user_faction):
	get_parent().change_factions(network_id, user_faction)
	rpc_id(network_id,"explode_ship", network_id)


############################SHIP STUFF############################

# Client asks the server to spawn a resource
master func request_resource(location, type="isotopes", count=1):
	resource_id += 1
	if get_tree().get_network_unique_id() == 1:
		spawn_resource(resource_id, location, type,count)
	rpc("spawn_resource", resource_id, location, type, count)

# Server makes the clients spawn a resource
slave func spawn_resource(id, location, type, count):
	var resource_name = type + "_" + str(id)
	#print("trying to make a resource")
	if not self.has_node(resource_name):
		var resource_instance = resource.instance()
		resource_instance.resource_id = id
		resource_instance.type = type
		resource_instance.count = count
		resource_instance.set_name(resource_name)
		resource_instance.set_position(location)
		add_child(resource_instance)

sync func claim_resource(network_id, type):
	#if self.has_node(resource_name):
		#TODO: add a check to make sure the player claiming the resource is near it
		#var id = get_node(resource_name).resource_id #todo: check this.
	var alert
		#	if network_id != 1:
	lobby.players[network_id][type] += 1
	update_score(network_id)
	alert =  "%s collected %s for faction %d" % [
		lobby.players[network_id]["username"],
		type,
		lobby.players[network_id]["faction"]
	]
	rpc("add_item_to_chat", alert)
	print(alert)
		#destroy_resource(resource_name)
		#rpc("destroy_resource",resource_name)
		#print("total: " + str(lobby.players[network_id]["resources"][type]))

slave func destroy_resource(resource_name):
	if self.has_node(resource_name):
		get_node(resource_name).free()

####################################################################
# GUI stuff

sync func add_item_to_chat(text):
	if my_network_id != 1:
		$gui/control/social/chat.add_item_to_chat(text)

#Anyone can initiate the explosion (security hole)
slave func explode_ship(network_id):
	if has_node(str(network_id)):
		get_node(str(network_id)).rpc("explode")

################################################################

# This should only be used when spawning motherships,
func get_spawnpoint(user_faction):
	for shipyard in get_tree().get_nodes_in_group("Shipyards"):
		print(str(shipyard))
		if shipyard.faction == user_faction:
			return shipyard.get_spawnpoint()
	return Vector2(0,0)
	#for mothership in get_tree().get_nodes_in_group("Motherships"):
	#	if mothership.faction == user_faction:
	#		return mothership.get_spawnpoint()
	#for station in get_tree().get_nodes_in_group("Stations"):
	#	if station.faction == user_faction:
	#		return station.get_spawnpoint()
	#return $map.default_spawnpoint.global_position

