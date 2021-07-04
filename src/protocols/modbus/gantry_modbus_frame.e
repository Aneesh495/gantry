note
	description: "Modbus TCP/IP Application Protocol (MBAP) frame encoder and decoder with big-endian wire formatting."
	author: "Aneesh Krishna"

class
	GANTRY_MODBUS_FRAME

inherit
	GANTRY_MODBUS_CONSTANTS

create
	make_request,
	make_response,
	make_from_bytes

feature {NONE} -- Initializers

	make_request (a_trans_id, a_unit_id, a_fc: INTEGER; a_payload: ARRAYED_LIST [INTEGER])
		require
			valid_trans: a_trans_id >= 0 and a_trans_id <= 65535
			valid_unit: a_unit_id >= 0 and a_unit_id <= 255
			valid_fc: a_fc >= 1 and a_fc <= 255
			payload_attached: a_payload /= Void
		do
			transaction_id := a_trans_id
			protocol_id := 0
			unit_id := a_unit_id
			function_code := a_fc
			data_payload := a_payload.twin
			length := 1 + 1 + data_payload.count -- unit_id + fc + payload
		ensure
			trans_set: transaction_id = a_trans_id
			fc_set: function_code = a_fc
		end

	make_response (a_trans_id, a_unit_id, a_fc: INTEGER; a_payload: ARRAYED_LIST [INTEGER])
		do
			make_request (a_trans_id, a_unit_id, a_fc, a_payload)
		end

	make_from_bytes (a_bytes: ARRAYED_LIST [INTEGER])
			-- Parse raw byte stream into structured Modbus frame.
		require
			minimum_mbap_size: a_bytes.count >= 8
		local
			p_len: INTEGER
			i: INTEGER
		do
			transaction_id := (a_bytes.i_th (1) * 256) + a_bytes.i_th (2)
			protocol_id := (a_bytes.i_th (3) * 256) + a_bytes.i_th (4)
			length := (a_bytes.i_th (5) * 256) + a_bytes.i_th (6)
			unit_id := a_bytes.i_th (7)
			function_code := a_bytes.i_th (8)

			create data_payload.make (a_bytes.count - 8)
			p_len := a_bytes.count - 8
			from
				i := 9
			until
				i > a_bytes.count
			loop
				data_payload.extend (a_bytes.i_th (i))
				i := i + 1
			end
		ensure
			parsed: transaction_id >= 0
		end

feature -- Access

	transaction_id: INTEGER
	protocol_id: INTEGER
	length: INTEGER
	unit_id: INTEGER
	function_code: INTEGER
	data_payload: ARRAYED_LIST [INTEGER]

feature -- Serialization

	to_bytes: ARRAYED_LIST [INTEGER]
			-- Serialize MBAP header and PDU to standard wire representation.
		local
			res: ARRAYED_LIST [INTEGER]
			len_val: INTEGER
		do
			len_val := 1 + 1 + data_payload.count -- UnitID + FC + Payload
			create res.make (7 + 1 + data_payload.count)

			-- MBAP Header (7 bytes)
			res.extend ((transaction_id // 256) \\ 256)
			res.extend (transaction_id \\ 256)
			res.extend (0) -- Protocol ID high (0x00)
			res.extend (0) -- Protocol ID low (0x00)
			res.extend ((len_val // 256) \\ 256)
			res.extend (len_val \\ 256)
			res.extend (unit_id)

			-- PDU: Function Code + Data
			res.extend (function_code)
			across data_payload as b loop
				res.extend (b)
			end

			Result := res
		ensure
			valid_wire_size: Result.count >= 8
		end

	make_exception_frame (a_ex_code: INTEGER): GANTRY_MODBUS_FRAME
			-- Generate standard Modbus error response frame.
		local
			payload: ARRAYED_LIST [INTEGER]
		do
			create payload.make (1)
			payload.extend (a_ex_code)
			create Result.make_response (transaction_id, unit_id, function_code + 128, payload)
		ensure
			exception_flag_set: Result.function_code >= 128
		end

invariant
	valid_protocol: protocol_id = 0
	payload_attached: data_payload /= Void

end
