note
	description: "Abstract base class for standard IEC 61131-3 function blocks with internal state retention."
	author: "Aneesh Krishna"

deferred class
	GANTRY_FB_BASE

feature {NONE} -- Initialization

	make_fb (a_name: STRING)
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name.twin
			last_scan_time_ms := 0
		ensure
			name_set: name.is_equal (a_name)
			time_zero: last_scan_time_ms = 0
		end

feature -- Access

	name: STRING
			-- Function block instance name.

	last_scan_time_ms: INTEGER_64
			-- Monotonic timestamp of previous execution step.

feature -- Step

	step (a_current_time_ms: INTEGER_64)
			-- Execute one cyclic iteration of this function block.
		require
			valid_time: a_current_time_ms >= last_scan_time_ms
		deferred
		ensure
			time_advanced: last_scan_time_ms = a_current_time_ms
		end

invariant
	name_valid: not name.is_empty
	time_non_negative: last_scan_time_ms >= 0

end
