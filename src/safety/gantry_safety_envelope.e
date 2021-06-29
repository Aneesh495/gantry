note
	description: "Formal safety envelope verifying continuous physical invariants and actuator mutual exclusions."
	author: "Aneesh Krishna"

class
	GANTRY_SAFETY_ENVELOPE

create
	make

feature {NONE} -- Initialization

	make
		do
			create mutual_exclusion_a.make (8)
			create mutual_exclusion_b.make (8)
			create analog_high_limit_tags.make (8)
			create analog_high_limit_values.make (8)
			violation_count := 0
			last_violation_reason := ""
		ensure
			zero_violations: violation_count = 0
			empty_reason: last_violation_reason.is_empty
		end

feature -- Access

	mutual_exclusion_a: ARRAYED_LIST [STRING]
	mutual_exclusion_b: ARRAYED_LIST [STRING]

	analog_high_limit_tags: ARRAYED_LIST [STRING]
	analog_high_limit_values: ARRAYED_LIST [REAL_64]

	violation_count: INTEGER
	last_violation_reason: STRING

feature -- Configuration

	add_mutual_exclusion (a_tag1, a_tag2: STRING)
			-- Assert that tag1 and tag2 must never simultaneously be active (True).
		require
			tags_not_empty: not a_tag1.is_empty and not a_tag2.is_empty
		do
			mutual_exclusion_a.extend (a_tag1.twin)
			mutual_exclusion_b.extend (a_tag2.twin)
		ensure
			pair_added: mutual_exclusion_a.count = old mutual_exclusion_a.count + 1
		end

	add_high_limit (a_tag: STRING; a_limit: REAL_64)
			-- Assert that analog telemetry tag must not exceed high boundary.
		require
			tag_not_empty: not a_tag.is_empty
		do
			analog_high_limit_tags.extend (a_tag.twin)
			analog_high_limit_values.extend (a_limit)
		ensure
			limit_added: analog_high_limit_tags.count = old analog_high_limit_tags.count + 1
		end

feature -- Verification

	verify_envelope (a_table: GANTRY_IMAGE_TABLE): BOOLEAN
			-- Verify all physical invariants; returns True if process remains strictly inside envelope.
		require
			table_attached: a_table /= Void
		local
			i: INTEGER
			t1, t2: STRING
			v1, v2: BOOLEAN
			ana_tag: STRING
			ana_val, limit_val: REAL_64
			safe: BOOLEAN
		do
			safe := True

			-- 1. Check mutual exclusion constraints
			from
				i := 1
			until
				not safe or i > mutual_exclusion_a.count
			loop
				t1 := mutual_exclusion_a.i_th (i)
				t2 := mutual_exclusion_b.i_th (i)
				if (a_table.digital_outputs.has (t1) or a_table.digital_inputs.has (t1)) and
					(a_table.digital_outputs.has (t2) or a_table.digital_inputs.has (t2)) then
					v1 := a_table.read_digital (t1)
					v2 := a_table.read_digital (t2)
					if v1 and v2 then
						safe := False
						violation_count := violation_count + 1
						last_violation_reason := "Mutual exclusion violation: " + t1 + " and " + t2 + " both active"
					end
				end
				i := i + 1
			end

			-- 2. Check analog hard physical limits
			if safe then
				from
					i := 1
				until
					not safe or i > analog_high_limit_tags.count
				loop
					ana_tag := analog_high_limit_tags.i_th (i)
					limit_val := analog_high_limit_values.i_th (i)
					if a_table.analog_inputs.has (ana_tag) or a_table.analog_outputs.has (ana_tag) then
						ana_val := a_table.read_analog (ana_tag)
						if ana_val > limit_val then
							safe := False
							violation_count := violation_count + 1
							last_violation_reason := "Physical high limit breached: " + ana_tag + " (" + ana_val.out + " > " + limit_val.out + ")"
						end
					end
					i := i + 1
				end
			end

			Result := safe
		end

invariant
	pairs_aligned: mutual_exclusion_a.count = mutual_exclusion_b.count
	limits_aligned: analog_high_limit_tags.count = analog_high_limit_values.count
	violations_non_negative: violation_count >= 0

end
