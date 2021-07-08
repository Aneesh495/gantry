note
	description: "Modbus TCP/IP master client formatting queries and parsing responses from remote RTUs."
	author: "Aneesh Krishna"

class
	GANTRY_MODBUS_CLIENT

inherit
	GANTRY_MODBUS_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make
		do
			next_transaction_id := 1
		ensure
			trans_initialized: next_transaction_id = 1
		end

feature -- Access

	next_transaction_id: INTEGER

feature -- Request Builders

	build_read_holding_registers (a_unit_id, a_start_addr, a_count: INTEGER): GANTRY_MODBUS_FRAME
		require
			valid_unit: a_unit_id >= 0 and a_unit_id <= 255
			valid_addr: a_start_addr >= 0 and a_start_addr <= 65535
			valid_count: a_count >= 1 and a_count <= 125
		local
			payload: ARRAYED_LIST [INTEGER]
			tid: INTEGER
		do
			tid := get_next_tid
			create payload.make (4)
			payload.extend ((a_start_addr // 256) \\ 256)
			payload.extend (a_start_addr \\ 256)
			payload.extend ((a_count // 256) \\ 256)
			payload.extend (a_count \\ 256)
			create Result.make_request (tid, a_unit_id, Fc_read_holding_registers, payload)
		ensure
			frame_attached: Result /= Void
		end

	build_write_single_coil (a_unit_id, a_addr: INTEGER; a_value: BOOLEAN): GANTRY_MODBUS_FRAME
		require
			valid_unit: a_unit_id >= 0 and a_unit_id <= 255
			valid_addr: a_addr >= 0 and a_addr <= 65535
		local
			payload: ARRAYED_LIST [INTEGER]
			tid: INTEGER
		do
			tid := get_next_tid
			create payload.make (4)
			payload.extend ((a_addr // 256) \\ 256)
			payload.extend (a_addr \\ 256)
			if a_value then
				payload.extend (255) -- 0xFF
				payload.extend (0)   -- 0x00
			else
				payload.extend (0)
				payload.extend (0)
			end
			create Result.make_request (tid, a_unit_id, Fc_write_single_coil, payload)
		ensure
			frame_attached: Result /= Void
		end

feature {NONE} -- Helpers

	get_next_tid: INTEGER
		do
			Result := next_transaction_id
			if next_transaction_id >= 65535 then
				next_transaction_id := 1
			else
				next_transaction_id := next_transaction_id + 1
			end
		end

end
