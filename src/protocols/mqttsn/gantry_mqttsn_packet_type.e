note
	description: "MQTT For Sensor Networks (MQTT-SN v1.2) packet type identifiers."
	author: "Aneesh Krishna"

class
	GANTRY_MQTTSN_PACKET_TYPE

feature -- Message Types

	Msg_advertise: INTEGER = 0
	Msg_searchgw: INTEGER = 1
	Msg_gwinfo: INTEGER = 2
	Msg_connect: INTEGER = 4
	Msg_connack: INTEGER = 5
	Msg_register: INTEGER = 10
	Msg_regack: INTEGER = 11
	Msg_publish: INTEGER = 12
	Msg_puback: INTEGER = 13
	Msg_pingreq: INTEGER = 22
	Msg_pingresp: INTEGER = 23
	Msg_disconnect: INTEGER = 24

feature -- Return Codes

	Rc_accepted: INTEGER = 0
	Rc_rejected_congestion: INTEGER = 1
	Rc_rejected_invalid_topic_id: INTEGER = 2
	Rc_rejected_not_supported: INTEGER = 3

end
