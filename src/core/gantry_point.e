note
	description: "Abstract base class for all process telemetry points in the process image table."
	author: "Aneesh Krishna"

deferred class
	GANTRY_POINT

inherit
	GANTRY_POINT_STATUS

feature {NONE} -- Initialization

	make_point (a_tag: STRING; a_description: STRING)
			-- Initialize telemetry point with tag and description.
		require
			tag_not_empty: not a_tag.is_empty
		do
			tag := a_tag.twin
			description := a_description.twin
			status := Status_uninitialized
			timestamp_ms := 0
			is_forced := False
			update_count := 0
		ensure
			tag_assigned: tag.is_equal (a_tag)
			description_assigned: description.is_equal (a_description)
			status_uninitialized: status = Status_uninitialized
			not_forced: not is_forced
			update_count_zero: update_count = 0
		end

feature -- Access

	tag: STRING
			-- Unique industrial identifier for the point (e.g. FIT_101_PRESSURE).

	description: STRING
			-- Human-readable description of field sensor or actuator.

	status: INTEGER
			-- Quality status conforming to IEC 61850 quality hierarchy.

	timestamp_ms: INTEGER_64
			-- Epoch timestamp in milliseconds of most recent field update.

	is_forced: BOOLEAN
			-- Is point value currently manually forced by maintenance override?

	update_count: INTEGER_64
			-- Monotonically increasing count of processed telemetry updates.

feature -- Status Mutators

	set_status (a_status: INTEGER)
			-- Update quality status flag for this point.
		require
			valid_status: is_valid_status (a_status)
		do
			status := a_status
		ensure
			status_updated: status = a_status
		end

	set_timestamp (a_timestamp_ms: INTEGER_64)
			-- Record timestamp of field telemetry acquisition.
		require
			non_negative_time: a_timestamp_ms >= 0
		do
			timestamp_ms := a_timestamp_ms
		ensure
			timestamp_assigned: timestamp_ms = a_timestamp_ms
		end

	force_override
			-- Arm manual override flag.
		do
			is_forced := True
			status := Status_forced
		ensure
			forced_armed: is_forced
			status_forced: status = Status_forced
		end

	release_override
			-- Disarm manual override and restore automatic scan status.
		do
			is_forced := False
			status := Status_good
		ensure
			forced_disarmed: not is_forced
			status_good: status = Status_good
		end

	increment_update_count
			-- Increment count of received updates.
		do
			update_count := update_count + 1
		ensure
			count_incremented: update_count = old update_count + 1
		end

feature -- Output Formatting

	status_string: STRING
			-- Text representation of current quality status.
		do
			Result := status_to_string (status)
		ensure
			result_not_empty: not Result.is_empty
		end

invariant
	tag_valid: not tag.is_empty
	status_valid: is_valid_status (status)
	timestamp_non_negative: timestamp_ms >= 0
	update_count_non_negative: update_count >= 0
	forced_consistency: is_forced implies status = Status_forced

end
