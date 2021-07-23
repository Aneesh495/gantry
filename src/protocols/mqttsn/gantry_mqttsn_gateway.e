note
	description: "MQTT-SN Edge Gateway bridging resource-constrained sensor packets into the Gantry image table."
	author: "Aneesh Krishna"

class
	GANTRY_MQTTSN_GATEWAY

inherit
	GANTRY_MQTTSN_PACKET_TYPE

create
	make

feature {NONE} -- Initialization

	make
		do
			create topic_id_to_tag.make (32)
			create tag_to_topic_id.make (32)
			next_topic_id := 1
			published_packets := 0
		ensure
			empty_topics: topic_id_to_tag.is_empty
			zero_packets: published_packets = 0
		end

feature -- Access

	topic_id_to_tag: HASH_TABLE [STRING, INTEGER]
	tag_to_topic_id: HASH_TABLE [INTEGER, STRING]
	next_topic_id: INTEGER
	published_packets: INTEGER_64

feature -- Topic Registration

	register_topic (a_tag: STRING): INTEGER
		require
			tag_not_empty: not a_tag.is_empty
		do
			if tag_to_topic_id.has (a_tag) then
				Result := tag_to_topic_id.item (a_tag)
			else
				Result := next_topic_id
				next_topic_id := next_topic_id + 1
				topic_id_to_tag.put (a_tag.twin, Result)
				tag_to_topic_id.put (Result, a_tag.twin)
			end
		ensure
			valid_topic_id: Result > 0
			mapped: topic_id_to_tag.has (Result)
		end

feature -- Packet Handling

	handle_publish (a_packet: GANTRY_MQTTSN_PACKET; a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64): GANTRY_MQTTSN_PACKET
			-- Process incoming PUBLISH packet and return PUBACK confirmation.
		require
			packet_attached: a_packet /= Void
			table_attached: a_table /= Void
		local
			topic_id: INTEGER
			msg_id: INTEGER
			raw_val: INTEGER
			resp_payload: ARRAYED_LIST [INTEGER]
			l_ana: detachable GANTRY_ANALOG_POINT
			l_dig: detachable GANTRY_DIGITAL_POINT
		do
			published_packets := published_packets + 1

			if a_packet.payload.count < 4 then
				create resp_payload.make (4)
				resp_payload.extend (0)
				resp_payload.extend (0)
				resp_payload.extend (0)
				resp_payload.extend (Rc_rejected_invalid_topic_id)
				create Result.make (Msg_puback, resp_payload)
			else
				-- Flags(1), TopicId(2), MsgId(2), Data(...)
				topic_id := (a_packet.payload.i_th (2) * 256) + a_packet.payload.i_th (3)
				msg_id := 0
				if a_packet.payload.count >= 5 then
					msg_id := (a_packet.payload.i_th (4) * 256) + a_packet.payload.i_th (5)
				end

				create resp_payload.make (4)
				resp_payload.extend (topic_id // 256)
				resp_payload.extend (topic_id \\ 256)
				resp_payload.extend (msg_id // 256)
				resp_payload.extend (msg_id \\ 256)

				if attached topic_id_to_tag.item (topic_id) as tag_str then
					-- Extract 16-bit integer payload
					if a_packet.payload.count >= 7 then
						raw_val := (a_packet.payload.i_th (6) * 256) + a_packet.payload.i_th (7)
						l_ana := a_table.get_analog_input (tag_str)
						if attached l_ana as ana_pt then
							ana_pt.update_value (raw_val.to_double, a_timestamp_ms)
						else
							l_dig := a_table.get_digital_input (tag_str)
							if attached l_dig as dig_pt then
								dig_pt.update_value (raw_val > 0, a_timestamp_ms)
							end
						end
					end
					resp_payload.extend (Rc_accepted)
				else
					resp_payload.extend (Rc_rejected_invalid_topic_id)
				end

				create Result.make (Msg_puback, resp_payload)
			end
		ensure
			puback_returned: Result.message_type = Msg_puback
		end

invariant
	topics_attached: topic_id_to_tag /= Void

end
