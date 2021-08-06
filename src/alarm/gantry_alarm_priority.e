note
	description: "ISA-18.2 Alarm priority tiers for rationalization and operator workload leveling."
	author: "Aneesh Krishna"

class
	GANTRY_ALARM_PRIORITY

feature -- Priority Constants

	Priority_diagnostic: INTEGER = 1
	Priority_low: INTEGER = 2
	Priority_medium: INTEGER = 3
	Priority_high: INTEGER = 4
	Priority_critical: INTEGER = 5

feature -- Query

	is_valid_priority (a_prio: INTEGER): BOOLEAN
		do
			Result := (a_prio >= Priority_diagnostic and a_prio <= Priority_critical)
		ensure
			consistent: Result = (a_prio >= Priority_diagnostic and a_prio <= Priority_critical)
		end

	priority_name (a_prio: INTEGER): STRING
		require
			valid_prio: is_valid_priority (a_prio)
		do
			inspect a_prio
			when Priority_diagnostic then Result := "DIAGNOSTIC"
			when Priority_low then Result := "LOW"
			when Priority_medium then Result := "MEDIUM"
			when Priority_high then Result := "HIGH"
			when Priority_critical then Result := "CRITICAL"
			else
				Result := "UNKNOWN_PRIO"
			end
		ensure
			not_empty: not Result.is_empty
		end

invariant
	levels_ordered: Priority_diagnostic < Priority_low and
		Priority_low < Priority_medium and
		Priority_medium < Priority_high and
		Priority_high < Priority_critical

end
