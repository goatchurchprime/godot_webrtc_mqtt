# Godot WebRTC signalled via MQTT

## Introduction

Most computer communication protocols are based on combinations of 
low-level TCP and UDP connections.  For example, a HTTP is implemented using a single 
TCP socket that is opened by the client that sends its request up to 
the server, receives one blob of data (usually a webpage) back from the server, and then closes.

Many platforms (eg Windows executables, iOS, and Android apps) provide access to these low-level
TCP and UDP systems, which makes it possible to implement higher level protocols based on them.
The exception is HTML5 (ie things that run in the browser) that, for security and 
compatibility reasons, does not provide access to the low-level data channels. 
Therefore we are limited to the few high-level protocols that we are implemented in the system.
These are, in order of invention, HTTP, WebSockets, and WebRTC.

HTTP is simple and familiar, WebSockets work just like TCP sockets and were originally developed 
as a hack on top of HTTP to provide realtime text chat functionality, but WebRTC is the most 
difficult and powerful because it is designed to carry moving images and sound (video conferencing) 
in realtime from one computer to another without going via a server.

This App is designed to show how this is set up in the Godot engine (which can deploy to HTML5
as well as other platforms) using the MQTT protocol as the signalling server.

MQTT is chosen because it is a simple and transparent publish-and-subscribe protocol based on TCP 
(or WebSockets if operated from HTML5) requiring no setup and where you can see the messages (signals) 
being communicated between the two computers necessary to initiate the WebRTC connection.

This makes it easier to show you the step-by-step process for creating a WebRTC connection 
with as little confusion as possible.

## Crash course in MQTT

We will be using [test.mosquitto.org](http://test.mosquitto.org/). If you are using Linux, 
try the following command in one window:
> `mosquitto_sub -h test.mosquitto.org -t "crumble77/#" -v`

Then type the following command in another window:
> `mosquitto_pub -h test.mosquitto.org -t "crumble77/teacake" -m 'hi there'`

As you can see, we have published the message 'hi there' to the topic 'crumble77/teacake' 
having subscribed to all topics beginning with 'crumble77/' using the wildcard '#'.



goatchurchprime.github.io/godot_webrtc_mqtt_html5/webrtcmqtt.html


# Where is the WebRTC library downloaded from


# HTML5 deployment

In order for a browser to run an HTML5 program it needs to be served through 
HTTP or HTTPS.  Serving HTTP is easy, simply run the following command in Linux

> `python -m http.server`



# Discussion


