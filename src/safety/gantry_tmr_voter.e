note
	description: "Triple Modular Redundancy (TMR) 2-out-of-3 voting engine with sensor discrepancy fault isolation."
	author: "Aneesh Krishna"

class
	GANTRY_TMR_VOTER

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name.twin
			channel_a_fault := False
			channel_b_fault := False
			channel_c_fault := False
			has_discrepancy := False
		ensure
			name_set: name.is_equal (a_name)
			no_faults: not channel_a_fault and not channel_b_fault and not channel_c_fault
		end

feature -- Access

	name: STRING
	channel_a_fault: BOOLEAN
	channel_b_fault: BOOLEAN
	channel_c_fault: BOOLEAN
	has_discrepancy: BOOLEAN

feature -- Discrete 2oo3 Voting

	vote_discrete (a_val_a, a_val_b, a_val_c: BOOLEAN): BOOLEAN
			-- Majority 2-out-of-3 vote across three redundant binary channels.
		do
			Result := (a_val_a and a_val_b) or (a_val_b and a_val_c) or (a_val_a and a_val_c)

			-- Identify discrepancy channel
			channel_a_fault := (a_val_a /= Result)
			channel_b_fault := (a_val_b /= Result)
			channel_c_fault := (a_val_c /= Result)
			has_discrepancy := channel_a_fault or channel_b_fault or channel_c_fault
		ensure
			majority_holds: Result = ((a_val_a and a_val_b) or (a_val_b and a_val_c) or (a_val_a and a_val_c))
		end

feature -- Analog 2oo3 Voting

	vote_analog (a_val_a, a_val_b, a_val_c: REAL_64; a_discrepancy_threshold: REAL_64): REAL_64
			-- Median selection with sensor drift outlier detection and healthy average fallback.
		require
			positive_threshold: a_discrepancy_threshold > 0.0
		local
			median: REAL_64
			dev_a, dev_b, dev_c: REAL_64
		do
			-- Find median of three values
			if (a_val_a <= a_val_b and a_val_b <= a_val_c) or (a_val_c <= a_val_b and a_val_b <= a_val_a) then
				median := a_val_b
			elseif (a_val_b <= a_val_a and a_val_a <= a_val_c) or (a_val_c <= a_val_a and a_val_a <= a_val_b) then
				median := a_val_a
			else
				median := a_val_c
			end

			-- Check discrepancies relative to median
			dev_a := (a_val_a - median).abs
			dev_b := (a_val_b - median).abs
			dev_c := (a_val_c - median).abs

			channel_a_fault := (dev_a > a_discrepancy_threshold)
			channel_b_fault := (dev_b > a_discrepancy_threshold)
			channel_c_fault := (dev_c > a_discrepancy_threshold)
			has_discrepancy := channel_a_fault or channel_b_fault or channel_c_fault

			if channel_a_fault and not channel_b_fault and not channel_c_fault then
				Result := (a_val_b + a_val_c) / 2.0
			elseif channel_b_fault and not channel_a_fault and not channel_c_fault then
				Result := (a_val_a + a_val_c) / 2.0
			elseif channel_c_fault and not channel_a_fault and not channel_b_fault then
				Result := (a_val_a + a_val_b) / 2.0
			else
				Result := median
			end
		end

invariant
	name_attached: name /= Void

end
