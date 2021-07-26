extends Control


var peer = WebRTCPeerConnection.new()
var datachannel = null

var metopic = ""
var othertopic = ""

func _process(delta):
	peer.poll()
	if datachannel != null and datachannel.get_ready_state() == datachannel.STATE_OPEN and datachannel.get_available_packet_count() > 0:
		print("datachannel received: ", datachannel.get_packet().get_string_from_utf8())

func _on_SetMeTopic_toggled(button_pressed):
	if button_pressed:
		
		print($metopic.items, $metopic.selected)
		metopic = $metopic.get_item_text($metopic.selected)
		othertopic = $metopic.get_item_text(1-$metopic.selected)
		print("Metopic: ", metopic, " othertopic: ", othertopic)		

		var uniqstring = OS.get_unique_id().replace("{", "").split("-")[0].to_upper().substr(0,4)
		$mqttnode.server = "mosquitto.doesliverpool.xyz"
		randomize()
		$mqttnode.client_id = "u%s%da%d"%[uniqstring, int(metopic), randi()]
		print("MQTT client_id:", $mqttnode.client_id)
		$mqttnode.set_last_will(metopic+"status", "stopped", true)
		if yield($mqttnode.connect_to_server(), "completed"):
			$mqttnode.publish(metopic+"status", "connected", true)
		else:
			print("mqtt failed to connect")

		$mqttnode.connect("received_message", self, "received_mqtt")
		$mqttnode.subscribe(metopic+"offer")
		$mqttnode.subscribe(metopic+"answer")
		$mqttnode.subscribe(metopic+"ice")

		peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		datachannel = peer.create_data_channel("chat", {"id": 1, "negotiated": true})
		peer.connect("session_description_created", self, "_session_description_created")
		peer.connect("ice_candidate_created", self, "_ice_candidate_created")

		if $metopic.selected == 0:
			var x = peer.create_offer()
			print("peer create offer ", peer, "Error:", x)

	else:
		print("Can only do once")
		assert(false)
		
func _session_description_created(type, data):
	print("_session_description_created ", [type, data.substr(0, 10)])
	peer.set_local_description(type, data)
	$mqttnode.publish(othertopic+type, data)
	
func _ice_candidate_created(mid_name, index_name, sdp_name):
	print("_ice_candidate_created ", [mid_name, index_name, sdp_name])
	$mqttnode.publish(othertopic+"ice", to_json([mid_name, index_name, sdp_name]))

func received_mqtt(topic, message):
	var stopic = topic.split("/")
	print("MQTT RECEIVED: ", stopic, ": ", message.substr(0, 10))
	if len(stopic) == 3:
		assert (metopic == stopic[0]+"/"+stopic[1]+"/")
		if stopic[2] == "offer":
			peer.set_remote_description("offer", message)
		elif stopic[2] == "answer":
			peer.set_remote_description("answer", message)
		elif stopic[2] == "ice":
			var js = parse_json(message)
			var e = peer.add_ice_candidate(js[0], js[1], js[2])
			print("ICE error:", e)

func _on_PingButton_pressed():
	var e = datachannel.put_packet(("Ping from "+metopic+" yay!").to_utf8())
	print("Ping Error: ", e)
