extends Control

# We need to name the things me and other,
# Possibly dynamically name and subscribe without the dropdowns
# localname and remotename, topic subscribing and diagrams
# Make a websocket version of the mqtt, so it can deploy
# Once press button (then disable it)
# comment on the flow, and include mosquitto_sub commands

var peer = WebRTCPeerConnection.new()
var datachannel = null

var metopic = ""
var othertopic = ""

func syncremoteid(i):
	$remote_id/OptionButton.selected = 1-$local_id/OptionButton.selected

func _ready():
	$remote_id/OptionButton.items = $local_id/OptionButton.items
	$local_id/OptionButton.connect("item_selected", self, "syncremoteid")
	syncremoteid(0)
	$mqttconnect.connect("pressed", self, "mqttconnect")
	$webrtcconnect.connect("pressed", self, "webrtcconnect")

	peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
	datachannel = peer.create_data_channel("chat", {"id": 1, "negotiated": true})
	peer.connect("session_description_created", self, "_session_description_created")
	peer.connect("ice_candidate_created", self, "_ice_candidate_created")


func texteditappend(textedit, topic, msg=null):
	var textline = topic
	if msg != null:
		textline = topic + ": " + msg.replace("\n", " ")
		if len(textline) > 43:
			textline = textline.substr(0, 40)+"..."
	textedit.set_line(textedit.get_line_count()-1, textline+"\n")
	textedit.scroll_vertical = textedit.get_line_count() - 3
	textedit.update()
	
func mqttpublish(topic, msg, retain=false):
	texteditappend($msg_pub/TextEdit, topic, msg)
	$mqttnode.publish(topic, msg, retain)

func mqttsubscribe(topic):
	texteditappend($msg_sub/TextEdit, "subscribing", topic)
	$mqttnode.subscribe(topic)


func mqttconnect():
	$mqttconnect.disabled = true
	metopic = $roottopic/LineEdit.text + "/" + $local_id/OptionButton.text + "/"
	othertopic = $roottopic/LineEdit.text + "/" + $remote_id/OptionButton.text + "/"
	print("Metopic: ", metopic, " othertopic: ", othertopic)		

	randomize()
	$mqttnode.client_id = "u%da%d"%[int(metopic), randi()]
	print("MQTT client_id:", $mqttnode.client_id)
	$mqttnode.set_last_will(metopic+"status", "stopped", true)
	$mqttnode.connect("received_message", self, "received_mqtt")
	
	#if yield($mqttnode.connect_to_server(), "completed"):
	yield($mqttnode.websocket_connect_to_server(), "completed")

	mqttsubscribe(othertopic+"status")
	mqttsubscribe(metopic+"offer")
	mqttsubscribe(metopic+"answer")
	mqttsubscribe(metopic+"ice")
	mqttpublish(metopic+"status", "connected", true)


func webrtcconnect():
	var x = peer.create_offer()
	print("peer create offer ", peer, "Error:", x)
	if not $mqttnode.is_connected_to_server():
		$remote_sdp/TextEdit.text = "MQTT not connected, so won't work"

func _process(delta):
	peer.poll()
	if datachannel != null and datachannel.get_ready_state() == datachannel.STATE_OPEN and datachannel.get_available_packet_count() > 0:
		var packet = datachannel.get_packet()
		var wmsg = packet.get_string_from_utf8()
		print("datachannel received: ", wmsg)
		$PingButton/recdata.text = wmsg
		
func _session_description_created(type, data):
	$webrtcconnect.disabled = true	
	print("_session_description_created ", [type, data.substr(0, 10)])
	$local_sdp/TextEdit.text = data
	peer.set_local_description(type, data)
	mqttpublish(othertopic+type, data)
		
func _ice_candidate_created(mid_name, index_name, sdp_name):
	print("_ice_candidate_created ", [mid_name, index_name, sdp_name])
	texteditappend($ice_candidates/TextEdit, "Sent: "+mid_name+", "+str(index_name)+", "+sdp_name)
	mqttpublish(othertopic+"ice", to_json([mid_name, index_name, sdp_name]))

func received_mqtt(topic, msg):
	texteditappend($msg_sub/TextEdit, topic, msg)	
	var stopic = topic.split("/")
	print("MQTT RECEIVED: ", stopic, ": ", msg.substr(0, 10))
	if len(stopic) == 3:
		#assert (metopic == stopic[0]+"/"+stopic[1]+"/")
		if stopic[2] == "offer":
			$remote_sdp/TextEdit.text = msg
			peer.set_remote_description("offer", msg)
		elif stopic[2] == "answer":
			$remote_sdp/TextEdit.text = msg
			peer.set_remote_description("answer", msg)
		elif stopic[2] == "ice":
			var js = parse_json(msg)
			texteditappend($ice_candidates/TextEdit, "Rec: "+js[0]+", "+str(js[1])+", "+js[2])
			var e = peer.add_ice_candidate(js[0], js[1], js[2])
			print("ICE error:", e)

var np = 0
func _on_PingButton_pressed():
	np += 1
	var e = datachannel.put_packet(("Ping %d from %s yay!" % [np, metopic]).to_utf8())
	print("Ping Error: ", e)

