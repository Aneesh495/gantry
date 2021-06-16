note
	description: "Standard IEC 61131-3 down-counter function block (CTD)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_CTD

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_cd := False
			input_load := False
			preset_val := 0
			output_q := False
			count_val := 0
			prev_cd := False
		ensure
			name_set: name.is_equal (a_name)
			q_false: not output_q
		end

feature -- Inputs

	input_cd: BOOLEAN
	input_load: BOOLEAN
	preset_val: INTEGER_64

feature -- Outputs

	output_q: BOOLEAN
	count_val: INTEGER_64

feature {NONE} -- Internal State

	prev_cd: BOOLEAN

feature -- Mutators

	set_inputs (a_cd, a_load: BOOLEAN; a_pv: INTEGER_64)
		require
			non_negative_pv: a_pv >= 0
		do
			input_cd := a_cd
			input_load := a_load
			preset_val := a_pv
		ensure
			cd_set: input_cd = a_cd
			load_set: input_load = a_load
			pv_set: preset_val = a_pv
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		do
			if input_load then
				count_val := preset_val
			elseif input_cd and not prev_cd then
				if count_val > 0 then
					count_val := count_val - 1
				end
			end
			output_q := (count_val <= 0)
			prev_cd := input_cd
			last_scan_time_ms := a_current_time_ms
		end

invariant
	pv_non_negative: preset_val >= 0
	cv_non_negative: count_val >= 0

end
