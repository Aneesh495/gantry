note
	description: "High-resolution telemetry tracking scan jitter, minimum/maximum/average cycle durations, and overruns."
	author: "Aneesh Krishna"

class
	GANTRY_CYCLIC_STATS

create
	make

feature {NONE} -- Initialization

	make (a_target_period_us: INTEGER_64)
			-- Initialize telemetry monitor with configured scan cycle period.
		require
			positive_target: a_target_period_us > 0
		do
			target_period_us := a_target_period_us
			total_cycles := 0
			cycle_overruns := 0
			last_scan_duration_us := 0
			min_scan_duration_us := 999999999
			max_scan_duration_us := 0
			total_duration_us := 0
			last_jitter_us := 0
			max_jitter_us := 0
		ensure
			target_set: target_period_us = a_target_period_us
			zero_cycles: total_cycles = 0
			zero_overruns: cycle_overruns = 0
		end

feature -- Access

	target_period_us: INTEGER_64
			-- Configured cycle period in microseconds (e.g. 10,000 us for 100 Hz scan).

	total_cycles: INTEGER_64
			-- Total number of scan cycles executed.

	cycle_overruns: INTEGER_64
			-- Number of times execution duration exceeded configured target period.

	last_scan_duration_us: INTEGER_64
			-- Elapsed time of most recently completed scan cycle in microseconds.

	min_scan_duration_us: INTEGER_64
			-- Minimum recorded scan duration across all executed cycles.

	max_scan_duration_us: INTEGER_64
			-- Maximum recorded scan duration across all executed cycles.

	total_duration_us: INTEGER_64
			-- Sum of all scan durations used to compute average.

	last_jitter_us: INTEGER_64
			-- Deviation of previous cycle duration from target period.

	max_jitter_us: INTEGER_64
			-- Peak observed jitter in microseconds.

feature -- Telemetry Updates

	record_cycle (a_duration_us: INTEGER_64)
			-- Record completion of a scan cycle with measured elapsed execution time.
		require
			non_negative_duration: a_duration_us >= 0
		local
			diff: INTEGER_64
		do
			total_cycles := total_cycles + 1
			last_scan_duration_us := a_duration_us
			total_duration_us := total_duration_us + a_duration_us

			if a_duration_us < min_scan_duration_us then
				min_scan_duration_us := a_duration_us
			end

			if a_duration_us > max_scan_duration_us then
				max_scan_duration_us := a_duration_us
			end

			if a_duration_us > target_period_us then
				cycle_overruns := cycle_overruns + 1
			end

			-- Calculate jitter relative to target
			if a_duration_us >= target_period_us then
				diff := a_duration_us - target_period_us
			else
				diff := target_period_us - a_duration_us
			end
			last_jitter_us := diff

			if diff > max_jitter_us then
				max_jitter_us := diff
			end
		ensure
			cycles_incremented: total_cycles = old total_cycles + 1
			last_duration_stored: last_scan_duration_us = a_duration_us
		end

feature -- Computed Properties

	average_scan_duration_us: REAL_64
			-- Arithmetic mean of scan duration in microseconds.
		do
			if total_cycles > 0 then
				Result := total_duration_us.to_double / total_cycles.to_double
			else
				Result := 0.0
			end
		ensure
			non_negative_average: Result >= 0.0
		end

	overrun_percentage: REAL_64
			-- Proportion of cycles that violated target period deadline (0.0 to 100.0).
		do
			if total_cycles > 0 then
				Result := (cycle_overruns.to_double / total_cycles.to_double) * 100.0
			else
				Result := 0.0
			end
		ensure
			bounded_percentage: Result >= 0.0 and Result <= 100.0
		end

invariant
	positive_target: target_period_us > 0
	cycles_non_negative: total_cycles >= 0
	overruns_bounded: cycle_overruns <= total_cycles
	jitter_non_negative: last_jitter_us >= 0 and max_jitter_us >= 0

end
