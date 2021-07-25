extends Control


var rtc_mp: WebRTCMultiplayer = WebRTCMultiplayer.new()
var sealed = false


func Lset_remote_description(type: String, sdp: String):
	print(" Lset_remote_description ")
	print("TYPE: ", type)
	print("SDP: ", sdp)
	print("END")

#var p1 = WebRTCPeerConnection.new()
#var ch1 = p1.create_data_channel("chat", {"id": 1, "negotiated": true})

func _process(delta):
	#p1.poll()
	rtc_mp.poll()
	
func _ready():
	print(rtc_mp, rtc_mp.get_unique_id())
	#p1.connect("session_description_created", self, "Lset_remote_description")

func stop():
	rtc_mp.close()

var Ldatachannel = null
func _input(event):
	if event is InputEventKey and event.pressed:
		#if event.scancode == KEY_M:
		#	var x = p1.create_offer()
		#	print("create offer err=", x)
		if event.scancode == KEY_L:
			var id = 1313131313			
			var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
			peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
			peer.connect("session_description_created", self, "_offer_created", [id])
			peer.connect("ice_candidate_created", self, "_new_ice_candidate", [id])

			rtc_mp.add_peer(peer, id)
			#Ldatachannel = peer.create_data_channel("channel1", { "negotiated": true, "id": 1,  "maxRetransmits": 1, "ordered": true })
			#print("Ldatachannel ", Ldatachannel)
			var x = peer.create_offer()
			print("peer create offer ", peer, "Error:", x)
			
		if event.scancode == KEY_M:
			$MQTTExperiment.mqttpublish("yo", "datathing")
						
#There are two ways to create a working data channel: either call create_data_channel() 
#on only one of the peer and listen to 
#data_channel_received on the other, 
#or call create_data_channel() on both peers, 
#with the same values, and the negotiated option set to true.

func _new_ice_candidate(mid_name, index_name, sdp_name, id):
	print("nnnnew ice ", [mid_name, index_name, sdp_name, id])
	#send_candidate(id, mid_name, index_name, sdp_name)


func _offer_created(type, data, id):
	print("oooo ", [type, data, id])
	$MQTTExperiment.mqttpublish(type, data)

	if not rtc_mp.has_peer(id):
		return
	print("created", type)
	rtc_mp.get_peer(id).connection.set_local_description(type, data)
	if type == "offer": 
		#return _send_msg("O", id, offer)
		#send_offer(id, data)
		pass
	else: 
		#_send_msg("A", id, answer)
		#send_answer(id, data)
		pass

func connected(id):
	print("Connected %d" % id)
	rtc_mp.initialize(id, true)


func lobby_joined(lobby):
	self.lobby = lobby


func lobby_sealed():
	sealed = true


func disconnected():
	stop() # Unexpected disconnect


func peer_connected(id):
	print("Peer connected %d" % id)
	#_create_peer(id)


func peer_disconnected(id):
	if rtc_mp.has_peer(id): rtc_mp.remove_peer(id)


func offer_received(id, offer):
	print("Got offer: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("offer", offer)


func answer_received(id, answer):
	print("Got answer: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("answer", answer)


func candidate_received(id, mid, index, sdp):
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.add_ice_candidate(mid, index, sdp)





