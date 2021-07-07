note
	description: "Modbus TCP/IP server dispatching industrial requests against the register map and process image."
	author: "Aneesh Krishna"

class
	GANTRY_MODBUS_SERVER

inherit
	GANTRY_MODBUS_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make (a_map: GANTRY_MODBUS_REGISTER_MAP)
		require
			map_attached: a_map /= Void
		do
			register_map := a_map
			processed_requests := 0
			exception_responses := 0
		ensure
			map_set: register_map = a_map
			zero_requests: processed_requests = 0
		end

feature -- Access

	register_map: GANTRY_MODBUS_REGISTER_MAP
	processed_requests: INTEGER_64
	exception_responses: INTEGER_64

feature -- Request Processing

	handle_request (a_request: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64): GANTRY_MODBUS_FRAME
			-- Process incoming Modbus frame and return appropriate response frame.
		require
			req_attached: a_request /= Void
			table_attached: a_table /= Void
		local
			fc: INTEGER
		do
			processed_requests := processed_requests + 1
			fc := a_request.function_code

			inspect fc
			when Fc_read_coils then
				Result := handle_read_coils (a_request, a_table)
			when Fc_read_discrete_inputs then
				Result := handle_read_discrete_inputs (a_request, a_table)
			when Fc_read_holding_registers then
				Result := handle_read_holding_registers (a_request, a_table)
			when Fc_read_input_registers then
				Result := handle_read_input_registers (a_request, a_table)
			when Fc_write_single_coil then
				Result := handle_write_single_coil (a_request, a_table, a_timestamp_ms)
			when Fc_write_single_register then
				Result := handle_write_single_register (a_request, a_table, a_timestamp_ms)
			else
				exception_responses := exception_responses + 1
				Result := a_request.make_exception_frame (Ex_illegal_function)
			end
		ensure
			response_attached: Result /= Void
		end

feature {NONE} -- Handlers

	handle_read_coils (a_req: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE): GANTRY_MODBUS_FRAME
		local
			start_addr, count_val, byte_cnt: INTEGER
			payload: ARRAYED_LIST [INTEGER]
			byte_accum, bit_pos, i: INTEGER
			addr: INTEGER
			val: BOOLEAN
		do
			if a_req.data_payload.count < 4 then
				Result := a_req.make_exception_frame (Ex_illegal_data_value)
			else
				start_addr := (a_req.data_payload.i_th (1) * 256) + a_req.data_payload.i_th (2)
				count_val := (a_req.data_payload.i_th (3) * 256) + a_req.data_payload.i_th (4)

				byte_cnt := (count_val + 7) // 8
				create payload.make (byte_cnt + 1)
				payload.extend (byte_cnt)

				byte_accum := 0
				bit_pos := 0

				from
					i := 0
				until
					i >= count_val
				loop
					addr := start_addr + i
					val := False
					if attached register_map.coil_tags.item (addr) as t_tag then
						val := a_table.read_digital (t_tag)
					end
					if val then
						byte_accum := byte_accum + power_of_two (bit_pos)
					end
					bit_pos := bit_pos + 1
					if bit_pos = 8 or i = count_val - 1 then
						payload.extend (byte_accum)
						byte_accum := 0
						bit_pos := 0
					end
					i := i + 1
				end

				create Result.make_response (a_req.transaction_id, a_req.unit_id, Fc_read_coils, payload)
			end
		end

	handle_read_discrete_inputs (a_req: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE): GANTRY_MODBUS_FRAME
		local
			start_addr, count_val, byte_cnt: INTEGER
			payload: ARRAYED_LIST [INTEGER]
			byte_accum, bit_pos, i: INTEGER
			addr: INTEGER
			val: BOOLEAN
		do
			if a_req.data_payload.count < 4 then
				Result := a_req.make_exception_frame (Ex_illegal_data_value)
			else
				start_addr := (a_req.data_payload.i_th (1) * 256) + a_req.data_payload.i_th (2)
				count_val := (a_req.data_payload.i_th (3) * 256) + a_req.data_payload.i_th (4)

				byte_cnt := (count_val + 7) // 8
				create payload.make (byte_cnt + 1)
				payload.extend (byte_cnt)

				byte_accum := 0
				bit_pos := 0

				from
					i := 0
				until
					i >= count_val
				loop
					addr := start_addr + i
					val := False
					if attached register_map.discrete_input_tags.item (addr) as t_tag then
						val := a_table.read_digital (t_tag)
					end
					if val then
						byte_accum := byte_accum + power_of_two (bit_pos)
					end
					bit_pos := bit_pos + 1
					if bit_pos = 8 or i = count_val - 1 then
						payload.extend (byte_accum)
						byte_accum := 0
						bit_pos := 0
					end
					i := i + 1
				end

				create Result.make_response (a_req.transaction_id, a_req.unit_id, Fc_read_discrete_inputs, payload)
			end
		end

	handle_read_holding_registers (a_req: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE): GANTRY_MODBUS_FRAME
		local
			start_addr, count_val, byte_cnt: INTEGER
			payload: ARRAYED_LIST [INTEGER]
			i, addr, reg_val: INTEGER
			real_val: REAL_64
		do
			if a_req.data_payload.count < 4 then
				Result := a_req.make_exception_frame (Ex_illegal_data_value)
			else
				start_addr := (a_req.data_payload.i_th (1) * 256) + a_req.data_payload.i_th (2)
				count_val := (a_req.data_payload.i_th (3) * 256) + a_req.data_payload.i_th (4)

				byte_cnt := count_val * 2
				create payload.make (byte_cnt + 1)
				payload.extend (byte_cnt)

				from
					i := 0
				until
					i >= count_val
				loop
					addr := start_addr + i
					reg_val := 0
					if attached register_map.holding_register_tags.item (addr) as t_tag then
						real_val := a_table.read_analog (t_tag)
						reg_val := real_val.truncated_to_integer
					end
					payload.extend ((reg_val // 256) \\ 256)
					payload.extend (reg_val \\ 256)
					i := i + 1
				end

				create Result.make_response (a_req.transaction_id, a_req.unit_id, Fc_read_holding_registers, payload)
			end
		end

	handle_read_input_registers (a_req: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE): GANTRY_MODBUS_FRAME
		local
			start_addr, count_val, byte_cnt: INTEGER
			payload: ARRAYED_LIST [INTEGER]
			i, addr, reg_val: INTEGER
			real_val: REAL_64
		do
			if a_req.data_payload.count < 4 then
				Result := a_req.make_exception_frame (Ex_illegal_data_value)
			else
				start_addr := (a_req.data_payload.i_th (1) * 256) + a_req.data_payload.i_th (2)
				count_val := (a_req.data_payload.i_th (3) * 256) + a_req.data_payload.i_th (4)

				byte_cnt := count_val * 2
				create payload.make (byte_cnt + 1)
				payload.extend (byte_cnt)

				from
					i := 0
				until
					i >= count_val
				loop
					addr := start_addr + i
					reg_val := 0
					if attached register_map.input_register_tags.item (addr) as t_tag then
						real_val := a_table.read_analog (t_tag)
						reg_val := real_val.truncated_to_integer
					end
					payload.extend ((reg_val // 256) \\ 256)
					payload.extend (reg_val \\ 256)
					i := i + 1
				end

				create Result.make_response (a_req.transaction_id, a_req.unit_id, Fc_read_input_registers, payload)
			end
		end

	handle_write_single_coil (a_req: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64): GANTRY_MODBUS_FRAME
		local
			addr, raw_cmd: INTEGER
			bool_cmd: BOOLEAN
		do
			if a_req.data_payload.count < 4 then
				Result := a_req.make_exception_frame (Ex_illegal_data_value)
			else
				addr := (a_req.data_payload.i_th (1) * 256) + a_req.data_payload.i_th (2)
				raw_cmd := (a_req.data_payload.i_th (3) * 256) + a_req.data_payload.i_th (4)

				if raw_cmd = 65280 then -- 0xFF00 = ON
					bool_cmd := True
				elseif raw_cmd = 0 then -- 0x0000 = OFF
					bool_cmd := False
				else
					bool_cmd := False
				end

				if attached register_map.coil_tags.item (addr) as t_tag then
					a_table.write_digital (t_tag, bool_cmd, a_timestamp_ms)
					create Result.make_response (a_req.transaction_id, a_req.unit_id, Fc_write_single_coil, a_req.data_payload)
				else
					Result := a_req.make_exception_frame (Ex_illegal_data_address)
				end
			end
		end

	handle_write_single_register (a_req: GANTRY_MODBUS_FRAME; a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64): GANTRY_MODBUS_FRAME
		local
			addr, reg_val: INTEGER
		do
			if a_req.data_payload.count < 4 then
				Result := a_req.make_exception_frame (Ex_illegal_data_value)
			else
				addr := (a_req.data_payload.i_th (1) * 256) + a_req.data_payload.i_th (2)
				reg_val := (a_req.data_payload.i_th (3) * 256) + a_req.data_payload.i_th (4)

				if attached register_map.holding_register_tags.item (addr) as t_tag then
					a_table.write_analog (t_tag, reg_val.to_double, a_timestamp_ms)
					create Result.make_response (a_req.transaction_id, a_req.unit_id, Fc_write_single_register, a_req.data_payload)
				else
					Result := a_req.make_exception_frame (Ex_illegal_data_address)
				end
			end
		end

feature {NONE} -- Bit Packing Helpers

	power_of_two (a_bit: INTEGER): INTEGER
		do
			inspect a_bit
			when 0 then Result := 1
			when 1 then Result := 2
			when 2 then Result := 4
			when 3 then Result := 8
			when 4 then Result := 16
			when 5 then Result := 32
			when 6 then Result := 64
			when 7 then Result := 128
			else Result := 0
			end
		end

invariant
	map_attached: register_map /= Void

end
