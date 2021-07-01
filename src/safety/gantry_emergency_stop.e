note
	description: "Latching Emergency Stop (E-Stop) coordinator with mandatory physical verification before reset."
	author: "Aneesh Krishna"

class
	GANTRY_EMERGENCY_STOP

create
	make

feature {NONE} -- Initialization

	make
		do
			is_tripped := False
			trip_reason := ""
			last_trip_time_ms := 0
			total_estop_trips := 0
		ensure
			not_tripped: not is_tripped
			empty_reason: trip_reason.is_empty
			zero_trips: total_estop_trips = 0
		end

feature -- Access

	is_tripped: BOOLEAN
	trip_reason: STRING
	last_trip_time_ms: INTEGER_64
	total_estop_trips: INTEGER

feature -- State Control

	trip (a_reason: STRING; a_timestamp_ms: INTEGER_64)
			-- Latch emergency stop trip.
		require
			reason_not_empty: not a_reason.is_empty
		do
			is_tripped := True
			trip_reason := a_reason.twin
			last_trip_time_ms := a_timestamp_ms
			total_estop_trips := total_estop_trips + 1
		ensure
			tripped: is_tripped
			reason_set: trip_reason.is_equal (a_reason)
			time_set: last_trip_time_ms = a_timestamp_ms
		end

	attempt_reset (a_hardware_pushbuttons_healthy: BOOLEAN): BOOLEAN
			-- Attempt reset; fails if physical pushbutton is still depressed.
		do
			if is_tripped then
				if a_hardware_pushbuttons_healthy then
					is_tripped := False
					trip_reason := ""
					Result := True
				else
					Result := False -- Denied: physical field hazard persists
				end
			else
				Result := True
			end
		ensure
			cleared_if_healthy: (old is_tripped and a_hardware_pushbuttons_healthy) implies not is_tripped
		end

	enforce_fail_safe (a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64)
			-- Force all digital outputs to de-energized (False) and analog outputs to 0.0.
		require
			table_attached: a_table /= Void
		local
			tag_str: STRING
		do
			if is_tripped then
				across a_table.digital_outputs as cur loop
					tag_str := cur.tag
					a_table.write_digital (tag_str, False, a_timestamp_ms)
				end
				across a_table.analog_outputs as cur loop
					tag_str := cur.tag
					a_table.write_analog (tag_str, 0.0, a_timestamp_ms)
				end
			end
		end

invariant
	trips_non_negative: total_estop_trips >= 0

end
