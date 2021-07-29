note
	description: "Swinging Door Trending (SDT) lossy time-series compression preserving slope transitions within error bounds."
	author: "Aneesh Krishna"

class
	GANTRY_SWINGING_DOOR

create
	make

feature {NONE} -- Initialization

	make (a_deviation: REAL_64; a_max_time_ms: INTEGER_64)
		require
			positive_dev: a_deviation > 0.0
			positive_time: a_max_time_ms > 0
		do
			compression_deviation := a_deviation
			max_time_ms := a_max_time_ms
			pivot_time_ms := 0
			pivot_val := 0.0
			prev_time_ms := 0
			prev_val := 0.0
			upper_slope := 1.0e30
			lower_slope := -1.0e30
			point_count := 0
			raw_points_count := 0
			archived_points_count := 0
		ensure
			dev_set: compression_deviation = a_deviation
			time_set: max_time_ms = a_max_time_ms
		end

feature -- Access

	compression_deviation: REAL_64
	max_time_ms: INTEGER_64

	pivot_time_ms: INTEGER_64
	pivot_val: REAL_64

	prev_time_ms: INTEGER_64
	prev_val: REAL_64

	upper_slope: REAL_64
	lower_slope: REAL_64

	point_count: INTEGER
	raw_points_count: INTEGER_64
	archived_points_count: INTEGER_64

feature -- Compression Step

	process_point (a_time_ms: INTEGER_64; a_val: REAL_64): detachable TUPLE [time: INTEGER_64; val: REAL_64]
			-- Ingest point; if slope boundary is breached or heartbeat expires, returns archived inflection point.
		require
			time_advances: a_time_ms >= prev_time_ms
		local
			dt: REAL_64
			su, sl: REAL_64
			archived_pt: TUPLE [time: INTEGER_64; val: REAL_64]
		do
			raw_points_count := raw_points_count + 1

			if point_count = 0 then
				-- First point becomes initial pivot
				pivot_time_ms := a_time_ms
				pivot_val := a_val
				prev_time_ms := a_time_ms
				prev_val := a_val
				point_count := 1
				archived_points_count := archived_points_count + 1
				create archived_pt
				archived_pt.time := a_time_ms
				archived_pt.val := a_val
				Result := archived_pt
			elseif point_count = 1 then
				-- Second point establishes initial slopes
				dt := (a_time_ms - pivot_time_ms).to_double
				if dt > 0.0 then
					upper_slope := ((a_val + compression_deviation) - pivot_val) / dt
					lower_slope := ((a_val - compression_deviation) - pivot_val) / dt
				end
				prev_time_ms := a_time_ms
				prev_val := a_val
				point_count := 2
			else
				dt := (a_time_ms - pivot_time_ms).to_double
				if dt > 0.0 then
					su := ((a_val + compression_deviation) - pivot_val) / dt
					sl := ((a_val - compression_deviation) - pivot_val) / dt

					if su < upper_slope then upper_slope := su end
					if sl > lower_slope then lower_slope := sl end

					-- Check if doors have crossed or maximum time expired
					if (upper_slope < lower_slope) or ((a_time_ms - pivot_time_ms) >= max_time_ms) then
						-- Archive previous point as critical inflection node
						create archived_pt
						archived_pt.time := prev_time_ms
						archived_pt.val := prev_val
						archived_points_count := archived_points_count + 1
						Result := archived_pt

						-- Reset pivot to previous point
						pivot_time_ms := prev_time_ms
						pivot_val := prev_val

						-- Recalculate slopes from new pivot to current point
						dt := (a_time_ms - pivot_time_ms).to_double
						if dt > 0.0 then
							upper_slope := ((a_val + compression_deviation) - pivot_val) / dt
							lower_slope := ((a_val - compression_deviation) - pivot_val) / dt
						else
							upper_slope := 1.0e30
							lower_slope := -1.0e30
						end
					end
				end
				prev_time_ms := a_time_ms
				prev_val := a_val
				point_count := point_count + 1
			end
		end

feature -- Statistics

	compression_ratio: REAL_64
			-- Percentage of raw points eliminated by swinging door compression (0.0 to 100.0).
		do
			if raw_points_count > 0 then
				Result := (1.0 - (archived_points_count.to_double / raw_points_count.to_double)) * 100.0
			else
				Result := 0.0
			end
		ensure
			bounded: Result >= 0.0 and Result <= 100.0
		end

invariant
	positive_deviation: compression_deviation > 0.0
	positive_max_time: max_time_ms > 0

end
