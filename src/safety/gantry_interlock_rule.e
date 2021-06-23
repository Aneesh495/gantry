note
	description: "Formal safety interlock rule mapping cause conditions to enforced fail-safe actuator states."
	author: "Aneesh Krishna"

class
	GANTRY_INTERLOCK_RULE

inherit
	GANTRY_SIL_LEVEL

create
	make

feature {NONE} -- Initialization

	make (a_id, a_desc: STRING; a_sil: INTEGER)
		require
			id_not_empty: not a_id.is_empty
			valid_sil: is_valid_sil (a_sil)
		do
			rule_id := a_id.twin
			description := a_desc.twin
			sil_rating := a_sil
			create cause_tags.make (4)
			create cause_trigger_values.make (4)
			create effect_tags.make (4)
			create effect_enforced_values.make (4)
			is_tripped := False
			trip_count := 0
			last_trip_time_ms := 0
		ensure
			id_set: rule_id.is_equal (a_id)
			sil_set: sil_rating = a_sil
			not_tripped: not is_tripped
			zero_trips: trip_count = 0
		end

feature -- Access

	rule_id: STRING
	description: STRING
	sil_rating: INTEGER

	cause_tags: ARRAYED_LIST [STRING]
	cause_trigger_values: ARRAYED_LIST [BOOLEAN]

	effect_tags: ARRAYED_LIST [STRING]
	effect_enforced_values: ARRAYED_LIST [BOOLEAN]

	is_tripped: BOOLEAN
	trip_count: INTEGER
	last_trip_time_ms: INTEGER_64

feature -- Rule Configuration

	add_cause (a_tag: STRING; a_trigger_value: BOOLEAN)
		require
			tag_not_empty: not a_tag.is_empty
		do
			cause_tags.extend (a_tag.twin)
			cause_trigger_values.extend (a_trigger_value)
		ensure
			cause_added: cause_tags.count = old cause_tags.count + 1
		end

	add_effect (a_tag: STRING; a_enforced_value: BOOLEAN)
		require
			tag_not_empty: not a_tag.is_empty
		do
			effect_tags.extend (a_tag.twin)
			effect_enforced_values.extend (a_enforced_value)
		ensure
			effect_added: effect_tags.count = old effect_tags.count + 1
		end

feature -- Evaluation

	evaluate (a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64): BOOLEAN
			-- Verify cause conditions; if active, enforce required safety effects.
		require
			table_attached: a_table /= Void
		local
			i: INTEGER
			all_causes_active: BOOLEAN
			c_tag, e_tag: STRING
			c_val: BOOLEAN
			current_val: BOOLEAN
		do
			if cause_tags.is_empty then
				all_causes_active := False
			else
				all_causes_active := True
				from
					i := 1
				until
					not all_causes_active or i > cause_tags.count
				loop
					c_tag := cause_tags.i_th (i)
					c_val := cause_trigger_values.i_th (i)
					if a_table.digital_inputs.has (c_tag) or a_table.digital_outputs.has (c_tag) or a_table.memory_bits.has (c_tag) then
						current_val := a_table.read_digital (c_tag)
						if current_val /= c_val then
							all_causes_active := False
						end
					else
						-- Missing telemetry point: fail-safe assumption trips cause
						all_causes_active := True
					end
					i := i + 1
				end
			end

			if all_causes_active then
				if not is_tripped then
					is_tripped := True
					trip_count := trip_count + 1
					last_trip_time_ms := a_timestamp_ms
				end
				-- Enforce safe actuator states immediately
				from
					i := 1
				until
					i > effect_tags.count
				loop
					e_tag := effect_tags.i_th (i)
					a_table.write_digital (e_tag, effect_enforced_values.i_th (i), a_timestamp_ms)
					i := i + 1
				end
			else
				is_tripped := False
			end

			Result := is_tripped
		end

invariant
	valid_sil: is_valid_sil (sil_rating)
	causes_aligned: cause_tags.count = cause_trigger_values.count
	effects_aligned: effect_tags.count = effect_enforced_values.count
	trips_non_negative: trip_count >= 0

end
