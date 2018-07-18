extends Node
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
	logger.info("Multiplayer API Framework")
	logger.info("A tool by al shady")
	#settings.lobby = self
	#_setup_network_callbacks()
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

func _process_flags(flags):
	for flag in flags:
		match(flag):
			"-server":
				launch_options = SERVER
			"-debug_client":
				launch_options = DEBUG_CLIENT
			"-spectate":
				launch_options = SPECTATE