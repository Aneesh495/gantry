note
	description: "Sensor noise filter suppressing updates within absolute and percentage deadband limits."
	author: "Aneesh Krishna"

class
	GANTRY_DEADBAND_FILTER

create
	make

feature {NONE} -- Initialization

	make (a_deadband: REAL_64)
		require
			non_negative_deadband: a_deadband >= 0.0
		do
			deadband := a_deadband
			last_archived_val := 0.0
			is_initialized := False
			suppressed_count := 0
			archived_count := 0
		ensure
			deadband_set: deadband = a_deadband
			not_init: not is_initialized
		end

feature -- Access

	deadband: REAL_64
	last_archived_val: REAL_64
	is_initialized: BOOLEAN
	suppressed_count: INTEGER_64
	archived_count: INTEGER_64

feature -- Filter Operations

	should_archive (a_val: REAL_64): BOOLEAN
			-- Test if new telemetry value exceeds deadband deviation threshold.
		local
			diff: REAL_64
		do
			if not is_initialized then
				is_initialized := True
				last_archived_val := a_val
				archived_count := archived_count + 1
				Result := True
			else
				diff := (a_val - last_archived_val).abs
				if diff >= deadband then
					last_archived_val := a_val
					archived_count := archived_count + 1
					Result := True
				else
					suppressed_count := suppressed_count + 1
					Result := False
				end
			end
		end

	reset
		do
			is_initialized := False
			last_archived_val := 0.0
		ensure
			cleared: not is_initialized
		end

invariant
	deadband_non_negative: deadband >= 0.0

end
