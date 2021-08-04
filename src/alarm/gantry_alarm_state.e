note
	description: "ISA-18.2 Alarm lifecycle state definitions and valid state transitions."
	author: "Aneesh Krishna"

class
	GANTRY_ALARM_STATE

feature -- State Constants

	State_normal: INTEGER = 0
			-- Process is within safe limits; alarm is inactive.

	State_unack_alarm: INTEGER = 1
			-- Process breached limit; active alarm awaiting operator acknowledgment.

	State_ack_alarm: INTEGER = 2
			-- Operator acknowledged active alarm; condition still persists in field.

	State_unack_cleared: INTEGER = 3
			-- Process returned to normal before operator acknowledged alarm.

	State_shelved: INTEGER = 4
			-- Temporarily suppressed by operator with authorized timeout.

	State_suppressed: INTEGER = 5
			-- Suppressed by design logic or equipment maintenance lockout.

	State_out_of_service: INTEGER = 6
			-- Point decommissioned from active supervisory monitoring.

feature -- Query

	is_valid_state (a_state: INTEGER): BOOLEAN
		do
			Result := (a_state >= State_normal and a_state <= State_out_of_service)
		ensure
			consistent: Result = (a_state >= State_normal and a_state <= State_out_of_service)
		end

	state_name (a_state: INTEGER): STRING
		require
			valid_state: is_valid_state (a_state)
		do
			inspect a_state
			when State_normal then Result := "NORMAL"
			when State_unack_alarm then Result := "UNACK_ALARM"
			when State_ack_alarm then Result := "ACK_ALARM"
			when State_unack_cleared then Result := "UNACK_CLEARED"
			when State_shelved then Result := "SHELVED"
			when State_suppressed then Result := "SUPPRESSED"
			when State_out_of_service then Result := "OUT_OF_SERVICE"
			else
				Result := "UNKNOWN_STATE"
			end
		ensure
			not_empty: not Result.is_empty
		end

end
