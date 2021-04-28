note
	description: "Memory-mapped process image table decoupling field I/O scanning from PLC logic and safety interlocks."
	author: "Aneesh Krishna"

class
	GANTRY_IMAGE_TABLE

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize empty process image table with standard memory partitions.
		do
			create digital_inputs.make (128)
			create digital_outputs.make (128)
			create analog_inputs.make (128)
			create analog_outputs.make (128)
			create memory_bits.make (64)
			create memory_registers.make (64)
			is_frozen := False
			cycle_count := 0
		ensure
			empty_di: digital_inputs.is_empty
			empty_do: digital_outputs.is_empty
			empty_ai: analog_inputs.is_empty
			empty_ao: analog_outputs.is_empty
			not_frozen: not is_frozen
			cycle_zero: cycle_count = 0
		end

feature -- Partitions

	digital_inputs: HASH_TABLE [GANTRY_DIGITAL_POINT, STRING]
			-- Discrete binary inputs from field sensors and contacts.

	digital_outputs: HASH_TABLE [GANTRY_DIGITAL_POINT, STRING]
			-- Discrete binary outputs driving field coils, contactors, and solenoids.

	analog_inputs: HASH_TABLE [GANTRY_ANALOG_POINT, STRING]
			-- Scaled continuous telemetry inputs (pressure, temperature, flow).

	analog_outputs: HASH_TABLE [GANTRY_ANALOG_POINT, STRING]
			-- Scaled analog command outputs (control valve position, motor VFD speed).

	memory_bits: HASH_TABLE [BOOLEAN, STRING]
			-- Internal scratchpad boolean flags (%M).

	memory_registers: HASH_TABLE [REAL_64, STRING]
			-- Internal scratchpad double-precision holding registers (%MD).

	is_frozen: BOOLEAN
			-- When frozen, input and output states cannot be mutated (used during snapshot safety audit).

	cycle_count: INTEGER_64
			-- Total number of scan cycles executed with this image table.

feature -- Point Registration

	register_digital_input (a_point: GANTRY_DIGITAL_POINT)
			-- Register a new discrete input point.
		require
			point_attached: a_point /= Void
			tag_not_empty: not a_point.tag.is_empty
			unique_tag: not digital_inputs.has (a_point.tag)
		do
			digital_inputs.put (a_point, a_point.tag)
		ensure
			registered: digital_inputs.has (a_point.tag)
			point_stored: digital_inputs.item (a_point.tag) = a_point
		end

	register_digital_output (a_point: GANTRY_DIGITAL_POINT)
			-- Register a new discrete output actuator point.
		require
			point_attached: a_point /= Void
			tag_not_empty: not a_point.tag.is_empty
			unique_tag: not digital_outputs.has (a_point.tag)
		do
			digital_outputs.put (a_point, a_point.tag)
		ensure
			registered: digital_outputs.has (a_point.tag)
			point_stored: digital_outputs.item (a_point.tag) = a_point
		end

	register_analog_input (a_point: GANTRY_ANALOG_POINT)
			-- Register a new analog sensor telemetry point.
		require
			point_attached: a_point /= Void
			tag_not_empty: not a_point.tag.is_empty
			unique_tag: not analog_inputs.has (a_point.tag)
		do
			analog_inputs.put (a_point, a_point.tag)
		ensure
			registered: analog_inputs.has (a_point.tag)
			point_stored: analog_inputs.item (a_point.tag) = a_point
		end

	register_analog_output (a_point: GANTRY_ANALOG_POINT)
			-- Register a new analog control actuator point.
		require
			point_attached: a_point /= Void
			tag_not_empty: not a_point.tag.is_empty
			unique_tag: not analog_outputs.has (a_point.tag)
		do
			analog_outputs.put (a_point, a_point.tag)
		ensure
			registered: analog_outputs.has (a_point.tag)
			point_stored: analog_outputs.item (a_point.tag) = a_point
		end

feature -- Query Operations

	get_digital_input (a_tag: STRING): detachable GANTRY_DIGITAL_POINT
			-- Retrieve digital input point by tag, or Void if absent.
		require
			tag_not_empty: not a_tag.is_empty
		do
			if digital_inputs.has (a_tag) then
				Result := digital_inputs.item (a_tag)
			end
		end

	get_digital_output (a_tag: STRING): detachable GANTRY_DIGITAL_POINT
			-- Retrieve digital output point by tag, or Void if absent.
		require
			tag_not_empty: not a_tag.is_empty
		do
			if digital_outputs.has (a_tag) then
				Result := digital_outputs.item (a_tag)
			end
		end

	get_analog_input (a_tag: STRING): detachable GANTRY_ANALOG_POINT
			-- Retrieve analog input point by tag, or Void if absent.
		require
			tag_not_empty: not a_tag.is_empty
		do
			if analog_inputs.has (a_tag) then
				Result := analog_inputs.item (a_tag)
			end
		end

	get_analog_output (a_tag: STRING): detachable GANTRY_ANALOG_POINT
			-- Retrieve analog output point by tag, or Void if absent.
		require
			tag_not_empty: not a_tag.is_empty
		do
			if analog_outputs.has (a_tag) then
				Result := analog_outputs.item (a_tag)
			end
		end

	read_digital (a_tag: STRING): BOOLEAN
			-- Read boolean value of any digital point (input or output).
		require
			tag_exists: digital_inputs.has (a_tag) or digital_outputs.has (a_tag) or memory_bits.has (a_tag)
		do
			if digital_inputs.has (a_tag) then
				if attached digital_inputs.item (a_tag) as p then
					Result := p.value
				end
			elseif digital_outputs.has (a_tag) then
				if attached digital_outputs.item (a_tag) as p then
					Result := p.value
				end
			elseif memory_bits.has (a_tag) then
				Result := memory_bits.item (a_tag)
			end
		end

	read_analog (a_tag: STRING): REAL_64
			-- Read double-precision value of any analog point (input or output).
		require
			tag_exists: analog_inputs.has (a_tag) or analog_outputs.has (a_tag) or memory_registers.has (a_tag)
		do
			if analog_inputs.has (a_tag) then
				if attached analog_inputs.item (a_tag) as p then
					Result := p.value
				end
			elseif analog_outputs.has (a_tag) then
				if attached analog_outputs.item (a_tag) as p then
					Result := p.value
				end
			elseif memory_registers.has (a_tag) then
				Result := memory_registers.item (a_tag)
			end
		end

	write_digital (a_tag: STRING; a_val: BOOLEAN; a_timestamp_ms: INTEGER_64)
			-- Write boolean value to output point or internal memory flag.
		require
			not_frozen: not is_frozen
			tag_valid: digital_outputs.has (a_tag) or memory_bits.has (a_tag)
		do
			if digital_outputs.has (a_tag) then
				if attached digital_outputs.item (a_tag) as p then
					p.update_value (a_val, a_timestamp_ms)
				end
			else
				memory_bits.force (a_val, a_tag)
			end
		end

	write_analog (a_tag: STRING; a_val: REAL_64; a_timestamp_ms: INTEGER_64)
			-- Write continuous engineering value to analog output or internal register.
		require
			not_frozen: not is_frozen
			tag_valid: analog_outputs.has (a_tag) or memory_registers.has (a_tag)
		do
			if analog_outputs.has (a_tag) then
				if attached analog_outputs.item (a_tag) as p then
					p.update_value (a_val, a_timestamp_ms)
				end
			else
				memory_registers.force (a_val, a_tag)
			end
		end

feature -- Lifecycle Control

	freeze_image
			-- Lock table against modifications during critical section audit.
		do
			is_frozen := True
		ensure
			image_is_frozen: is_frozen
		end

	unfreeze_image
			-- Unlock table to resume scan updates.
		do
			is_frozen := False
		ensure
			image_is_unfrozen: not is_frozen
		end

	increment_cycle
			-- Record completion of a full deterministic scan loop.
		do
			cycle_count := cycle_count + 1
		ensure
			cycle_bumped: cycle_count = old cycle_count + 1
		end

	total_points_count: INTEGER
			-- Total number of registered physical I/O points.
		do
			Result := digital_inputs.count + digital_outputs.count + analog_inputs.count + analog_outputs.count
		ensure
			consistent_sum: Result = digital_inputs.count + digital_outputs.count + analog_inputs.count + analog_outputs.count
		end

invariant
	di_attached: digital_inputs /= Void
	do_attached: digital_outputs /= Void
	ai_attached: analog_inputs /= Void
	ao_attached: analog_outputs /= Void
	cycle_non_negative: cycle_count >= 0

end
