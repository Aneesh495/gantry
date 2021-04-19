note
	description: "Quality and operational status flags for process telemetry points conforming to IEC 61850 and OPC DA quality hierarchies."
	author: "Aneesh Krishna"

class
	GANTRY_POINT_STATUS

feature -- Quality Status Constants

	Status_good: INTEGER = 0
			-- Point telemetry is verified valid and fresh from field sensor.

	Status_bad_sensor: INTEGER = 1
			-- Field sensor reported hardware fault, wire break, or ADC saturation.

	Status_comm_failure: INTEGER = 2
			-- Communication link to field remote terminal unit (RTU) timed out.

	Status_overrange: INTEGER = 3
			-- Value exceeds physical sensor dynamic measurement envelope.

	Status_forced: INTEGER = 4
			-- Value has been manually overridden by an authorized operator.

	Status_uninitialized: INTEGER = 5
			-- Point created in process image but has not received an initial scan.

feature -- Status Classification

	is_valid_status (a_status: INTEGER): BOOLEAN
			-- Is the provided integer a recognized status code?
		do
			Result := (a_status >= Status_good and a_status <= Status_uninitialized)
		ensure
			consistent: Result = (a_status = Status_good or a_status = Status_bad_sensor or
				a_status = Status_comm_failure or a_status = Status_overrange or
				a_status = Status_forced or a_status = Status_uninitialized)
		end

	is_usable (a_status: INTEGER): BOOLEAN
			-- Can a value with this status code be safely used in safety-critical calculations?
		require
			valid_status: is_valid_status (a_status)
		do
			Result := (a_status = Status_good or a_status = Status_forced)
		ensure
			safe_subset: Result implies (a_status = Status_good or a_status = Status_forced)
		end

	status_to_string (a_status: INTEGER): STRING
			-- Human-readable mnemonic for the given status code.
		require
			valid_status: is_valid_status (a_status)
		do
			inspect a_status
			when Status_good then
				Result := "GOOD"
			when Status_bad_sensor then
				Result := "BAD_SENSOR"
			when Status_comm_failure then
				Result := "COMM_FAILURE"
			when Status_overrange then
				Result := "OVERRANGE"
			when Status_forced then
				Result := "FORCED"
			when Status_uninitialized then
				Result := "UNINITIALIZED"
			else
				Result := "UNKNOWN"
			end
		ensure
			result_not_empty: not Result.is_empty
		end

invariant
	constants_unique: Status_good /= Status_bad_sensor and
		Status_bad_sensor /= Status_comm_failure and
		Status_comm_failure /= Status_overrange and
		Status_overrange /= Status_forced and
		Status_forced /= Status_uninitialized

end
