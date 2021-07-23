note
	description: "MQTT-SN binary packet codec with compact byte-aligned frame serialization."
	author: "Aneesh Krishna"

class
	GANTRY_MQTTSN_PACKET

inherit
	GANTRY_MQTTSN_PACKET_TYPE

create
	make,
	make_from_bytes

feature {NONE} -- Initializers

	make (a_type: INTEGER; a_payload: ARRAYED_LIST [INTEGER])
		require
			payload_attached: a_payload /= Void
		do
			message_type := a_type
			payload := a_payload.twin
			length := 2 + payload.count -- 1 byte length + 1 byte type + payload
		ensure
			type_set: message_type = a_type
		end

	make_from_bytes (a_bytes: ARRAYED_LIST [INTEGER])
		require
			min_size: a_bytes.count >= 2
		local
			i: INTEGER
		do
			length := a_bytes.i_th (1)
			message_type := a_bytes.i_th (2)
			create payload.make (a_bytes.count - 2)
			from
				i := 3
			until
				i > a_bytes.count
			loop
				payload.extend (a_bytes.i_th (i))
				i := i + 1
			end
		end

feature -- Access

	length: INTEGER
	message_type: INTEGER
	payload: ARRAYED_LIST [INTEGER]

feature -- Serialization

	to_bytes: ARRAYED_LIST [INTEGER]
		local
			res: ARRAYED_LIST [INTEGER]
		do
			create res.make (2 + payload.count)
			res.extend (2 + payload.count)
			res.extend (message_type)
			across payload as b loop
				res.extend (b)
			end
			Result := res
		ensure
			valid_size: Result.count = 2 + payload.count
		end

invariant
	payload_attached: payload /= Void

end
