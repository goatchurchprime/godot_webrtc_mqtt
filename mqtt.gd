extends Node

# Copyright (c) 2019, Pycom Limited.
# Some parts copyright (c) 2020, Dynamic Devices Ltd

# This software is licensed under the GNU GPL version 3 or any
# later version, with permitted additional terms. For more information
# see the Pycom Licence v1.0 document supplied with this file, or
# available at https://www.pycom.io/opensource/licensing
#
#
# Ported to gdscript by Alex J Lennon <ajlennon@dynamicdevices.co.uk>
# from https://github.com/pycom/pycom-libraries/blob/master/lib/mqtt/mqtt.py
#
# - ssl not implemented yet
# - qos 1,2 may not work
#
# Code should be considered ALPHA

export var server = "test.mosquitto.org"
export var port = 1883
export var client_id = ""

var socket = null
var websocket = null

var ssl = false
var ssl_params = null
var pid = 0
var user = null
var pswd = null
var keepalive = 0
var lw_topic = null
var lw_msg = null
var lw_qos = 0
var lw_retain = false

signal received_message(topic, message)

func get_data_bytes_async(n, socket=null):
	var timeout = 10
	var timestep = 0.2
	if socket == null:
		socket = self.socket
	yield(get_tree(), "idle_frame") 
	while socket.get_available_bytes() < n:
		yield(get_tree().create_timer(timestep), "timeout")
		timeout -= timestep
		if timeout < 0:
			print("get_data_bytes_async ", n, " timed out")
			return null
	return socket.get_data(n)

func websocketexperiment():
	websocket = WebSocketClient.new()
	var URL = "ws://node-red.dynamicdevices.co.uk:1880/ws/test"
	var E = websocket.connect_to_url(URL)
	print("Err: ", E)
	print(websocket.get_connected_host())
	var peer = websocket.get_peer(1)
	while not peer.is_connected_to_host():
		websocket.poll()
		print("connecting to host")
		yield(get_tree().create_timer(0.1), "timeout")

	for i in range(50):
		var E2 = peer.put_packet(PoolByteArray([100,101,102,103,104,105]))
		print("Ersr putpacket: ", E2)
		yield(get_tree().create_timer(0.1), "timeout")
	
func _ready():
	if client_id == "":
		randomize()
		client_id = str(randi())


	if get_name() == "test_mqtt1":
		websocketexperiment()
		
	if get_name() == "test_mqtt":
		server = "mosquitto.doesliverpool.xyz"
		server = "test.mosquitto.org"
		var metopic = "metest/"
		set_last_will(metopic+"status", "stopped", true)
		if yield(connect_to_server(), "completed"):
			publish(metopic+"status", "connected", true)
		else:
			print("mqtt failed to connect")

	#$mqttnode.connect("received_message", self, "received_mqtt")
	#$mqttnode.subscribe(metopic+"offer")
	#$mqttnode.subscribe(metopic+"answer")
	#$mqttnode.subscribe(metopic+"ice")

func _recv_len():
	var n = 0
	var sh = 0
	var b
	while 1:
		b = self.socket.get_u8() # Is this right ?
		n |= (b & 0x7f) << sh
		if not b & 0x80:
			return n
		sh += 7

func set_last_will(topic, msg, retain=false, qos=0):
	assert((0 <= qos) and (qos <= 2))
	assert(topic)
	self.lw_topic = topic
	self.lw_msg = msg
	self.lw_qos = qos
	self.lw_retain = retain

func connect_to_server(clean_session=true):
	var timeout = 30
	assert (server != "")
	if client_id == "":
		client_id = "rr%d" % randi()
	socket = StreamPeerTCP.new()
	socket.set_no_delay(true)
	socket.set_big_endian(true)
	print("Connecting to %s:%s" % [self.server, self.port])
	socket.connect_to_host(self.server, self.port)
#	if self.ssl:
#		import ussl
#		self.socket = ussl.wrap_socket(self.socket, **self.ssl_params)
	
	var timestep = 0.2
	while not socket.is_connected_to_host():
		yield(get_tree().create_timer(timestep), "timeout")
		timeout -= timestep
		if timeout < 0:
			return false
	while socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		yield(get_tree().create_timer(timestep), "timeout")
		timeout -= timestep
		if timeout < 0:
			return false
	print("Connected to mqtt broker ", self.server)
		
	# May need a little delay after connecting to the server ?
	
	var msg = PoolByteArray()
	# Must be an easier way of doing this...
	msg.append(0x10);
	msg.append(0x00);
	msg.append(0x00);
	msg.append(0x04);
	msg.append_array("MQTT".to_ascii());
	msg.append(0x04);
	msg.append(0x02);
	msg.append(0x00);
	msg.append(0x00);

	msg[1] = 10 + 2 + len(self.client_id)
	msg[9] = (1<<1) if clean_session else 0
	if self.user != null:
		msg[1] += 2 + len(self.user) + 2 + len(self.pswd)
		msg[9] |= 0xC0
	if self.keepalive:
		assert(self.keepalive < 65536)
		msg[10] |= self.keepalive >> 8
		msg[11] |= self.keepalive & 0x00FF
	if self.lw_topic:
		msg[1] += 2 + len(self.lw_topic) + 2 + len(self.lw_msg)
		msg[9] |= 0x4 | (self.lw_qos & 0x1) << 3 | (self.lw_qos & 0x2) << 3
		msg[9] |= 1<<5 if self.lw_retain else 0

	msg.append(self.client_id.length() >> 8)
	msg.append(self.client_id.length() & 0xFF)
	msg.append_array(self.client_id.to_ascii())
	if self.lw_topic:
		msg.append(self.lw_topic.length() >> 8)
		msg.append(self.lw_topic.length() & 0xFF)
		msg.append_array(self.lw_topic.to_ascii())
		msg.append(self.lw_msg.length() >> 8)
		msg.append(self.lw_msg.length() & 0xFF)
		msg.append_array(self.lw_msg.to_ascii())
	if self.user != null:
		msg.append(self.user.length() >> 8)
		msg.append(self.user.length() & 0xFF)
		msg.append_array(self.user.to_ascii())
		msg.append(self.pswd.length() >> 8)
		msg.append(self.pswd.length() & 0xFF)
		msg.append_array(self.pswd.to_ascii())
	socket.put_data(msg)
	
	var ret = yield(get_data_bytes_async(4), "completed")
	if ret == null:
		socket = null
		return false
		
	var error = ret[0]
	assert(error == 0)
	var data = ret[1]
	assert(data[0] == 0x20 and data[1] == 0x02)
	if data[3] != 0:
		print("MQTT exception ", data[3])
		return false

	#return data[2] & 1
	return true

func disconnect_from_server():
	self.socket.put_u16(0xE000)
	self.socket.disconnect_from_host()

	
func ping():
	self.socket.put_u16(0xC000)

func publish(topic, msg, retain=false, qos=0):
	#print("publishing ", topic, " ", msg)
	if(self.socket == null):
		return
	if(!self.socket.is_connected_to_host()):
		return

	var pkt = PoolByteArray()
	# Must be an easier way of doing this...
	pkt.append(0x30);
	pkt.append(0x00);
		
	pkt[0] |= ((1<<1) if qos else 0) | (1 if retain else 0)
	var sz = 2 + len(topic) + len(msg)
	if qos > 0:
		sz += 2
	assert(sz < 2097152)
	var i = 1
	while sz > 0x7f:
		pkt[i] = (sz & 0x7f) | 0x80
		sz >>= 7
		i += 1
		if i + 1 > len(pkt):
			pkt.append(0x00);
	pkt[i] = sz
	
	pkt.append(topic.length() >> 8)
	pkt.append(topic.length() & 0xFF)
	pkt.append_array(topic.to_ascii())

	if qos > 0:
		self.pid += 1
		pkt.append(self.pid >> 8)
		pkt.append(self.pid & 0xFF)

	pkt.append_array(msg.to_ascii())
	self.socket.put_data(pkt)
	
	if qos == 1:
		while 1:
			var op = self.wait_msg()
			if op == 0x40:
				sz = self.socket.get_u8()
				assert(sz == 0x02)
				var rcv_pid = self.socket.get_u16()
				if self.pid == rcv_pid:
					return
	elif qos == 2:
		assert(0)

func subscribe(topic, qos=0):
	self.pid += 1

	var msg = PoolByteArray()
	# Must be an easier way of doing this...
	msg.append(0x82);
	var length = 2 + 2 + topic.length() + 1
	msg.append(length)
	msg.append(self.pid >> 8)
	msg.append(self.pid & 0xFF)
	msg.append(topic.length() >> 8)
	msg.append(topic.length() & 0xFF)
	msg.append_array(topic.to_ascii())
	msg.append(qos);
	
	self.socket.put_data(msg)
	
	while 0:
		var op = self.wait_msg()
		if op == 0x90:
			var ret = yield(get_data_bytes_async(4), "completed")
			var error = ret[0]
			assert(error == 0)
			var data = ret[1]
			assert(data[1] == (self.pid >> 8) and data[2] == (self.pid & 0x0F))
			if data[3] == 0x80:
				print("MQTT exception ", data[3])
				return false
			return true

var in_wait_msg = false
func _process(delta):
	if websocket != null:
		websocket.poll()
	if in_wait_msg:
		return
	if(self.socket == null):
		return
	if(!self.socket.is_connected_to_host()):
		return
	if(self.socket.get_available_bytes() <= 0):
		return
	in_wait_msg = true
	while self.socket.get_available_bytes() > 0:
		yield(wait_msg(), "completed")
	in_wait_msg = false
	

# Wait for a single incoming MQTT message and process it.
# Subscribed messages are delivered to a callback previously
# set by .set_callback() method. Other (internal) MQTT
# messages processed internally.
func wait_msg():
	yield(get_tree(), "idle_frame") 
	if(self.socket == null):
		return
	if(!self.socket.is_connected_to_host()):
		return
	if(self.socket.get_available_bytes() <= 0):
		return
		
	var res = self.socket.get_u8()
#	self.socket.setblocking(True)
	if res == null:
		return null
	if res == 0:
		return false # raise OSError(-1)
	if res == 0xD0:  # PINGRESP
		var sz = self.socket.get_u8()
		assert(sz == 0)
		return null
	var op = res
	if op & 0xf0 != 0x30:
		return op
	var sz = _recv_len()
	var topic_len = self.socket.get_u16()
	var ret = yield(get_data_bytes_async(topic_len), "completed")
	var error = ret[0]
	assert(error == 0)
	var topic = ret[1].get_string_from_ascii()
	sz -= topic_len + 2
	var pid
	if op & 6:
		pid = self.socket.get_u16()
		sz -= 2
	ret  = yield(get_data_bytes_async(sz), "completed")
	error = ret[0]
	assert(error == 0)
	# warn: May not want to convert payload as ascii
	var msg = ret[1].get_string_from_ascii()
	
	emit_signal("received_message", topic, msg)
	
#	self.cb(topic, msg)
	if op & 6 == 2:
		var pkt = PoolByteArray()
		pkt.append(0x40);
		pkt.append(0x02);
		pkt.append(pid >> 8);
		pkt.append(pid & 0xFF);
		self.socket.write(pkt)
	elif op & 6 == 4:
		assert(0)

# Checks whether a pending message from server is available.
# If not, returns immediately with None. Otherwise, does
# the same processing as wait_msg.
func check_msg():
#	self.socket.setblocking(false)
	return self.wait_msg()

