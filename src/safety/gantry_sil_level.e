note
	description: "Safety Integrity Level (SIL) classification constants conforming to IEC 61508 and IEC 61511."
	author: "Aneesh Krishna"

class
	GANTRY_SIL_LEVEL

feature -- SIL Level Constants

	Sil_0: INTEGER = 0
			-- Standard commercial industrial process control (non-safety instrumented).

	Sil_1: INTEGER = 1
			-- Probability of Failure on Demand: 10^-2 to 10^-1.

	Sil_2: INTEGER = 2
			-- Probability of Failure on Demand: 10^-3 to 10^-2.

	Sil_3: INTEGER = 3
			-- Probability of Failure on Demand: 10^-4 to 10^-3 (Mission-critical safety interlocks).

	Sil_4: INTEGER = 4
			-- Probability of Failure on Demand: 10^-5 to 10^-4 (Catastrophic nuclear/rail safety).

feature -- Query

	is_valid_sil (a_level: INTEGER): BOOLEAN
		do
			Result := (a_level >= Sil_0 and a_level <= Sil_4)
		ensure
			consistent: Result = (a_level >= Sil_0 and a_level <= Sil_4)
		end

	sil_name (a_level: INTEGER): STRING
		require
			valid_sil: is_valid_sil (a_level)
		do
			inspect a_level
			when Sil_0 then Result := "SIL_0"
			when Sil_1 then Result := "SIL_1"
			when Sil_2 then Result := "SIL_2"
			when Sil_3 then Result := "SIL_3"
			when Sil_4 then Result := "SIL_4"
			else
				Result := "UNKNOWN_SIL"
			end
		ensure
			not_empty: not Result.is_empty
		end

invariant
	levels_ordered: Sil_0 < Sil_1 and Sil_1 < Sil_2 and Sil_2 < Sil_3 and Sil_3 < Sil_4

end
