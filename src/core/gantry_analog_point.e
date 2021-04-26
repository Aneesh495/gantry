note
	description: "Analog telemetry point supporting zero-span linear scaling, deadband filtering, rate-of-change limiting, and engineering unit conversion."
	author: "Aneesh Krishna"

class
	GANTRY_ANALOG_POINT

inherit
	GANTRY_POINT
		redefine
			force_override,
			release_override
		end

create
	make_analog,
	make_scaled

feature {NONE} -- Initialization

	make_analog (a_tag: STRING; a_description: STRING; a_units: STRING)
			-- Initialize simple unscaled analog point (1:1 scaling).
		require
			tag_not_empty: not a_tag.is_empty
		do
			make_scaled (a_tag, a_description, a_units, 0.0, 100.0, 0.0, 100.0)
		ensure
			units_set: engineering_units.is_equal (a_units)
			default_raw_min: raw_min = 0.0
			default_raw_max: raw_max = 100.0
			default_eng_min: eng_min = 0.0
			default_eng_max: eng_max = 100.0
		end

	make_scaled (a_tag: STRING; a_description: STRING; a_units: STRING;
			a_raw_min, a_raw_max, a_eng_min, a_eng_max: REAL_64)
			-- Initialize analog point with explicit zero-span range conversion.
		require
			tag_not_empty: not a_tag.is_empty
			valid_raw_span: a_raw_max > a_raw_min
			valid_eng_span: a_eng_max > a_eng_min
		do
			make_point (a_tag, a_description)
			engineering_units := a_units.twin
			raw_min := a_raw_min
			raw_max := a_raw_max
			eng_min := a_eng_min
			eng_max := a_eng_max
			deadband := 0.0
			rate_limit_per_sec := 0.0 -- 0.0 denotes unlimited rate
			value := eng_min
			raw_value := raw_min
			last_reported_value := eng_min
			last_update_time_ms := 0
		ensure
			units_set: engineering_units.is_equal (a_units)
			raw_min_set: raw_min = a_raw_min
			raw_max_set: raw_max = a_raw_max
			eng_min_set: eng_min = a_eng_min
			eng_max_set: eng_max = a_eng_max
		end

feature -- Access

	engineering_units: STRING
			-- Physical unit identifier (e.g. "degC", "bar", "m/s", "kW").

	value: REAL_64
			-- Conditioned engineering value after scaling, rate limiting, and clamping.

	raw_value: REAL_64
			-- Unscaled raw ADC counts or transmitter signal (e.g. 4.0 to 20.0 mA).

	raw_min: REAL_64
			-- Lower boundary of expected raw input signal.

	raw_max: REAL_64
			-- Upper boundary of expected raw input signal.

	eng_min: REAL_64
			-- Lower boundary of scaled engineering units.

	eng_max: REAL_64
			-- Upper boundary of scaled engineering units.

	deadband: REAL_64
			-- Absolute value deviation required to trigger an update.

	rate_limit_per_sec: REAL_64
			-- Maximum permitted rate of change in engineering units per second.

	last_reported_value: REAL_64
			-- Previous commuted value used for deadband comparison.

	last_update_time_ms: INTEGER_64
			-- Timestamp of previous analog computation.

feature -- Telemetry Updates

	update_value (a_raw: REAL_64; a_timestamp_ms: INTEGER_64)
			-- Process raw analog telemetry through calibration, scaling, and rate limits.
		require
			timestamp_valid: a_timestamp_ms >= 0
		local
			scaled: REAL_64
			dt_sec: REAL_64
			delta: REAL_64
			max_step: REAL_64
		do
			raw_value := a_raw
			set_timestamp (a_timestamp_ms)
			increment_update_count

			if is_forced then
				-- Point is forced; do not modify value
			else
				-- Check for sensor out-of-range before scaling
				if a_raw < raw_min or a_raw > raw_max then
					set_status (Status_overrange)
				else
					if status = Status_uninitialized or status = Status_bad_sensor or
						status = Status_comm_failure or status = Status_overrange then
						set_status (Status_good)
					end
				end

				-- Linear interpolation: eng = eng_min + (raw - raw_min) * (eng_max - eng_min) / (raw_max - raw_min)
				scaled := eng_min + ((a_raw - raw_min) * (eng_max - eng_min)) / (raw_max - raw_min)

				-- Clamping to calibrated physical range
				if scaled < eng_min then
					scaled := eng_min
				elseif scaled > eng_max then
					scaled := eng_max
				end

				-- Rate of change limiting
				if rate_limit_per_sec > 0.0 and last_update_time_ms > 0 then
					dt_sec := (a_timestamp_ms - last_update_time_ms).to_double / 1000.0
					if dt_sec > 0.0 then
						max_step := rate_limit_per_sec * dt_sec
						delta := scaled - value
						if delta > max_step then
							scaled := value + max_step
						elseif delta < -max_step then
							scaled := value - max_step
						end
					end
				end

				-- Apply deadband filtering
				delta := (scaled - last_reported_value).abs
				if delta >= deadband or last_update_time_ms = 0 then
					value := scaled
					last_reported_value := scaled
				end

				last_update_time_ms := a_timestamp_ms
			end
		ensure
			raw_recorded: raw_value = a_raw
			timestamp_updated: timestamp_ms = a_timestamp_ms
		end

feature -- Configuration & Overrides

	set_deadband (a_deadband: REAL_64)
			-- Configure noise deadband threshold in engineering units.
		require
			deadband_non_negative: a_deadband >= 0.0
		do
			deadband := a_deadband
		ensure
			deadband_assigned: deadband = a_deadband
		end

	set_rate_limit (a_limit: REAL_64)
			-- Configure rate of change limit in units per second (0.0 for unlimited).
		require
			limit_non_negative: a_limit >= 0.0
		do
			rate_limit_per_sec := a_limit
		ensure
			rate_limit_assigned: rate_limit_per_sec = a_limit
		end

	force_value (a_forced_value: REAL_64)
			-- Operator manual override with explicit analog target value.
		do
			force_override
			value := a_forced_value
		ensure
			forced_flag: is_forced
			forced_value_set: value = a_forced_value
		end

	force_override
			-- Override inherited feature to arm force status.
		do
			Precursor
		ensure then
			forced_is_true: is_forced
		end

	release_override
			-- Release manual override and recalculate value from current raw telemetry.
		do
			Precursor
			update_value (raw_value, timestamp_ms)
		ensure then
			not_forced: not is_forced
		end

invariant
	valid_raw_span: raw_max > raw_min
	valid_eng_span: eng_max > eng_min
	deadband_non_negative: deadband >= 0.0
	rate_limit_non_negative: rate_limit_per_sec >= 0.0

end
