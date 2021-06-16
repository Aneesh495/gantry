note
	description: "Standard IEC 61131-3 up-counter function block (CTU)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_CTU

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_cu := False
			input_reset := False
			preset_val := 0
			output_q := False
			count_val := 0
			prev_cu := False
		ensure
			name_set: name.is_equal (a_name)
			q_false: not output_q
			cv_zero: count_val = 0
		end

feature -- Inputs

	input_cu: BOOLEAN
	input_reset: BOOLEAN
	preset_val: INTEGER_64

feature -- Outputs

	output_q: BOOLEAN
	count_val: INTEGER_64

feature {NONE} -- Internal State

	prev_cu: BOOLEAN

feature -- Mutators

	set_inputs (a_cu, a_reset: BOOLEAN; a_pv: INTEGER_64)
		require
			non_negative_pv: a_pv >= 0
		do
			input_cu := a_cu
			input_reset := a_reset
			preset_val := a_pv
		ensure
			cu_set: input_cu = a_cu
			reset_set: input_reset = a_reset
			pv_set: preset_val = a_pv
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		do
			if input_reset then
				count_val := 0
			elseif input_cu and not prev_cu then
				if count_val < 9223372036854775807 then
					count_val := count_val + 1
				end
			end
			output_q := (count_val >= preset_val)
			prev_cu := input_cu
			last_scan_time_ms := a_current_time_ms
		end

invariant
	pv_non_negative: preset_val >= 0
	cv_non_negative: count_val >= 0

end
