note
	description: "Alarm deadband and hysteresis calculator preventing signal chattering near limits."
	author: "Aneesh Krishna"

class
	GANTRY_ALARM_HYSTERESIS

create
	make

feature {NONE} -- Initialization

	make (a_trip_limit, a_hysteresis_amount: REAL_64; a_is_high_trip: BOOLEAN)
		require
			non_negative_hys: a_hysteresis_amount >= 0.0
		do
			trip_limit := a_trip_limit
			hysteresis_amount := a_hysteresis_amount
			is_high_trip := a_is_high_trip
			is_tripped := False
		ensure
			limit_set: trip_limit = a_trip_limit
			hys_set: hysteresis_amount = a_hysteresis_amount
			not_tripped: not is_tripped
		end

feature -- Access

	trip_limit: REAL_64
	hysteresis_amount: REAL_64
	is_high_trip: BOOLEAN
	is_tripped: BOOLEAN

feature -- Evaluation

	evaluate (a_val: REAL_64): BOOLEAN
			-- Step hysteresis state machine with value.
		do
			if is_high_trip then
				if not is_tripped then
					if a_val >= trip_limit then
						is_tripped := True
					end
				else
					-- Clears only when dropping below limit minus hysteresis
					if a_val < (trip_limit - hysteresis_amount) then
						is_tripped := False
					end
				end
			else
				-- Low trip
				if not is_tripped then
					if a_val <= trip_limit then
						is_tripped := True
					end
				else
					-- Clears only when rising above limit plus hysteresis
					if a_val > (trip_limit + hysteresis_amount) then
						is_tripped := False
					end
				end
			end
			Result := is_tripped
		end

invariant
	hys_non_negative: hysteresis_amount >= 0.0

end
