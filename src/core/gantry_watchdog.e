note
	description: "Hardware and software fail-safe watchdog timer enforcing deterministic scan deadline compliance."
	author: "Aneesh Krishna"

class
	GANTRY_WATCHDOG

create
	make

feature {NONE} -- Initialization

	make (a_timeout_ms: INTEGER_64)
			-- Initialize watchdog with configured timeout deadline in milliseconds.
		require
			positive_timeout: a_timeout_ms > 0
		do
			timeout_ms := a_timeout_ms
			last_kick_time_ms := 0
			is_tripped := False
			trip_count := 0
		ensure
			timeout_set: timeout_ms = a_timeout_ms
			not_tripped: not is_tripped
			zero_trips: trip_count = 0
		end

feature -- Access

	timeout_ms: INTEGER_64
			-- Permitted maximum interval between consecutive watchdog kicks.

	last_kick_time_ms: INTEGER_64
			-- Millisecond timestamp of the most recent watchdog refresh.

	is_tripped: BOOLEAN
			-- True if a deadline overrun occurred without a timely refresh.

	trip_count: INTEGER
			-- Cumulative count of watchdog trip events.

feature -- Watchdog Operations

	kick (a_current_time_ms: INTEGER_64)
			-- Refresh watchdog timer indicating healthy execution of scan loop.
		require
			valid_timestamp: a_current_time_ms >= last_kick_time_ms
		do
			if not is_tripped then
				last_kick_time_ms := a_current_time_ms
			end
		ensure
			timestamp_refreshed: not is_tripped implies last_kick_time_ms = a_current_time_ms
		end

	check_timeout (a_current_time_ms: INTEGER_64): BOOLEAN
			-- Verify deadline; trips watchdog if execution has stalled beyond timeout.
		require
			valid_timestamp: a_current_time_ms >= 0
		local
			elapsed: INTEGER_64
		do
			if not is_tripped and last_kick_time_ms > 0 then
				elapsed := a_current_time_ms - last_kick_time_ms
				if elapsed > timeout_ms then
					is_tripped := True
					trip_count := trip_count + 1
				end
			end
			Result := is_tripped
		ensure
			tripped_if_elapsed: (last_kick_time_ms > 0 and (a_current_time_ms - last_kick_time_ms > timeout_ms)) implies is_tripped
		end

	reset (a_current_time_ms: INTEGER_64)
			-- Manually clear watchdog trip condition following maintenance verification.
		require
			valid_timestamp: a_current_time_ms >= 0
		do
			is_tripped := False
			last_kick_time_ms := a_current_time_ms
		ensure
			cleared: not is_tripped
			refreshed: last_kick_time_ms = a_current_time_ms
		end

invariant
	positive_timeout: timeout_ms > 0
	last_kick_non_negative: last_kick_time_ms >= 0
	trips_non_negative: trip_count >= 0

end
