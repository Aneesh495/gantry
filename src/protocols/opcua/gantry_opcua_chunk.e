note
	description: "OPC UA binary protocol message chunk framing and header serialization."
	author: "Aneesh Krishna"

class
	GANTRY_OPCUA_CHUNK

create
	make,
	make_from_bytes

feature {NONE} -- Initializers

	make (a_msg_type: STRING; a_chunk_type: CHARACTER; a_channel_id: INTEGER_64; a_payload: ARRAYED_LIST [INTEGER])
		require
			type_length: a_msg_type.count = 3
			payload_attached: a_payload /= Void
		do
			message_type := a_msg_type.twin
			chunk_type := a_chunk_type
			channel_id := a_channel_id
			payload := a_payload.twin
			message_size := 8 + 4 + payload.count -- 8 byte header + 4 byte channel ID + payload
		ensure
			type_set: message_type.is_equal (a_msg_type)
			chunk_set: chunk_type = a_chunk_type
		end

	make_from_bytes (a_bytes: ARRAYED_LIST [INTEGER])
		require
			min_size: a_bytes.count >= 12
		local
			m_type: STRING
			i: INTEGER
		do
			create m_type.make (3)
			m_type.append_character (a_bytes.i_th (1).to_character_8)
			m_type.append_character (a_bytes.i_th (2).to_character_8)
			m_type.append_character (a_bytes.i_th (3).to_character_8)
			message_type := m_type

			chunk_type := a_bytes.i_th (4).to_character_8
			message_size := a_bytes.i_th (5) + (a_bytes.i_th (6) * 256) +
				(a_bytes.i_th (7) * 65536) + (a_bytes.i_th (8) * 16777216)
			channel_id := a_bytes.i_th (9) + (a_bytes.i_th (10) * 256) +
				(a_bytes.i_th (11) * 65536) + (a_bytes.i_th (12) * 16777216)

			create payload.make (a_bytes.count - 12)
			from
				i := 13
			until
				i > a_bytes.count
			loop
				payload.extend (a_bytes.i_th (i))
				i := i + 1
			end
		end

feature -- Access

	message_type: STRING
	chunk_type: CHARACTER
	message_size: INTEGER
	channel_id: INTEGER_64
	payload: ARRAYED_LIST [INTEGER]

feature -- Serialization

	to_bytes: ARRAYED_LIST [INTEGER]
		local
			res: ARRAYED_LIST [INTEGER]
			sz: INTEGER
		do
			sz := 8 + 4 + payload.count
			create res.make (sz)

			-- 3 ASCII chars
			res.extend (message_type.item (1).code)
			res.extend (message_type.item (2).code)
			res.extend (message_type.item (3).code)
			res.extend (chunk_type.code)

			-- Message Size (Little-endian 32-bit)
			res.extend (sz \\ 256)
			res.extend ((sz // 256) \\ 256)
			res.extend ((sz // 65536) \\ 256)
			res.extend ((sz // 16777216) \\ 256)

			-- Channel ID (Little-endian 32-bit)
			res.extend ((channel_id.to_integer \\ 256))
			res.extend (((channel_id.to_integer // 256) \\ 256))
			res.extend (((channel_id.to_integer // 65536) \\ 256))
			res.extend (((channel_id.to_integer // 16777216) \\ 256))

			across payload as b loop
				res.extend (b)
			end
			Result := res
		ensure
			valid_size: Result.count >= 12
		end

invariant
	type_length: message_type.count = 3
	payload_attached: payload /= Void

end
