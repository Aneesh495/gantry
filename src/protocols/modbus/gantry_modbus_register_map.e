note
	description: "Address space registry mapping Modbus memory regions (0x, 1x, 3x, 4x) to Gantry image table points."
	author: "Aneesh Krishna"

class
	GANTRY_MODBUS_REGISTER_MAP

create
	make

feature {NONE} -- Initialization

	make
		do
			create coil_tags.make (64)
			create discrete_input_tags.make (64)
			create input_register_tags.make (64)
			create holding_register_tags.make (64)
		ensure
			empty_coils: coil_tags.is_empty
			empty_di: discrete_input_tags.is_empty
			empty_ir: input_register_tags.is_empty
			empty_hr: holding_register_tags.is_empty
		end

feature -- Address Mappings

	coil_tags: HASH_TABLE [STRING, INTEGER]
			-- 0x memory region (coils).

	discrete_input_tags: HASH_TABLE [STRING, INTEGER]
			-- 1x memory region (discrete contacts).

	input_register_tags: HASH_TABLE [STRING, INTEGER]
			-- 3x memory region (read-only analog telemetry).

	holding_register_tags: HASH_TABLE [STRING, INTEGER]
			-- 4x memory region (read/write holding registers).

feature -- Registration

	map_coil (a_address: INTEGER; a_tag: STRING)
		require
			valid_address: a_address >= 0 and a_address <= 65535
			tag_not_empty: not a_tag.is_empty
		do
			coil_tags.force (a_tag.twin, a_address)
		ensure
			mapped: coil_tags.has (a_address)
		end

	map_discrete_input (a_address: INTEGER; a_tag: STRING)
		require
			valid_address: a_address >= 0 and a_address <= 65535
			tag_not_empty: not a_tag.is_empty
		do
			discrete_input_tags.force (a_tag.twin, a_address)
		ensure
			mapped: discrete_input_tags.has (a_address)
		end

	map_input_register (a_address: INTEGER; a_tag: STRING)
		require
			valid_address: a_address >= 0 and a_address <= 65535
			tag_not_empty: not a_tag.is_empty
		do
			input_register_tags.force (a_tag.twin, a_address)
		ensure
			mapped: input_register_tags.has (a_address)
		end

	map_holding_register (a_address: INTEGER; a_tag: STRING)
		require
			valid_address: a_address >= 0 and a_address <= 65535
			tag_not_empty: not a_tag.is_empty
		do
			holding_register_tags.force (a_tag.twin, a_address)
		ensure
			mapped: holding_register_tags.has (a_address)
		end

invariant
	coils_attached: coil_tags /= Void
	di_attached: discrete_input_tags /= Void
	ir_attached: input_register_tags /= Void
	hr_attached: holding_register_tags /= Void

end
