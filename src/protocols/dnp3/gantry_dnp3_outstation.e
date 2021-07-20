note
	description: "DNP3 Outstation responding to Class 0/1/2/3 integrity polls and serializing telemetry points."
	author: "Aneesh Krishna"

class
	GANTRY_DNP3_OUTSTATION

inherit
	GANTRY_DNP3_OBJECT_GROUP

create
	make

feature {NONE} -- Initialization

	make (a_address: INTEGER)
		require
			valid_address: a_address >= 0 and a_address <= 65535
		do
			outstation_address := a_address
			processed_polls := 0
		ensure
			addr_set: outstation_address = a_address
		end

feature -- Access

	outstation_address: INTEGER
	processed_polls: INTEGER_64

feature -- Request Processing

	handle_read_class_zero (a_master_addr: INTEGER; a_table: GANTRY_IMAGE_TABLE): GANTRY_DNP3_LINK_FRAME
			-- Construct Class 0 integrity poll response containing current binary and analog values.
		require
			table_attached: a_table /= Void
		local
			payload: ARRAYED_LIST [INTEGER]
			b_val: INTEGER
			a_val: INTEGER
		do
			processed_polls := processed_polls + 1
			create payload.make (32)

			-- Application Header: App Control (0xC0: FIR, FIN), Function Code (0x81: Response), IIN (2 bytes 0x00 0x00)
			payload.extend (192) -- 0xC0
			payload.extend (Fc_response)
			payload.extend (0)   -- IIN 1
			payload.extend (0)   -- IIN 2

			-- Object Header: Group 1 (Binary Input), Var 1 (Single-bit), Range Qualifier (0x00: 8-bit start/stop)
			payload.extend (Group_binary_input)
			payload.extend (1) -- Var 1
			payload.extend (0) -- Qualifier
			payload.extend (0) -- Start index 0
			payload.extend (a_table.digital_inputs.count - 1) -- Stop index

			across a_table.digital_inputs as cur loop
				if cur.value then b_val := 129 else b_val := 1 end -- 0x81 (online, state=1) vs 0x01 (online, state=0)
				payload.extend (b_val)
			end

			-- Object Header: Group 30 (Analog Input), Var 2 (16-bit int with flag)
			if not a_table.analog_inputs.is_empty then
				payload.extend (Group_analog_input)
				payload.extend (2) -- Var 2
				payload.extend (0) -- Qualifier
				payload.extend (0) -- Start index 0
				payload.extend (a_table.analog_inputs.count - 1)

				across a_table.analog_inputs as cur loop
					payload.extend (1) -- Flag 0x01: Online
					a_val := cur.value.truncated_to_integer.bit_and (65535)
					payload.extend (a_val \\ 256)
					payload.extend ((a_val // 256) \\ 256)
				end
			end

			create Result.make_frame (196, a_master_addr, outstation_address, payload) -- Control 0xC4
		ensure
			response_attached: Result /= Void
		end

invariant
	valid_address: outstation_address >= 0 and outstation_address <= 65535

end
