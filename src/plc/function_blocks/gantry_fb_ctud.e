note
	description: "Standard IEC 61131-3 bidirectional up-down counter function block (CTUD)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_CTUD

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_cu := False
			input_cd := False
			input_reset := False
			input_load := False
			preset_val := 0
			output_qu := False
			output_qd := False
			count_val := 0
			prev_cu := False
			prev_cd := False
		ensure
			name_set: name.is_equal (a_name)
			qu_false: not output_qu
			qd_false: not output_qd
		end

feature -- Inputs

	input_cu: BOOLEAN
	input_cd: BOOLEAN
	input_reset: BOOLEAN
	input_load: BOOLEAN
	preset_val: INTEGER_64

feature -- Outputs

	output_qu: BOOLEAN
	output_qd: BOOLEAN
	count_val: INTEGER_64

feature {NONE} -- Internal State

	prev_cu: BOOLEAN
	prev_cd: BOOLEAN

feature -- Mutators

	set_inputs (a_cu, a_cd, a_reset, a_load: BOOLEAN; a_pv: INTEGER_64)
		require
			non_negative_pv: a_pv >= 0
		do
			input_cu := a_cu
			input_cd := a_cd
			input_reset := a_reset
			input_load := a_load
			preset_val := a_pv
		ensure
			cu_set: input_cu = a_cu
			cd_set: input_cd = a_cd
			reset_set: input_reset = a_reset
			load_set: input_load = a_load
			pv_set: preset_val = a_pv
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		do
			if input_reset then
				count_val := 0
			elseif input_load then
				count_val := preset_val
			else
				if input_cu and not prev_cu then
					if count_val < 9223372036854775807 then
						count_val := count_val + 1
					end
				end
				if input_cd and not prev_cd then
					if count_val > 0 then
						count_val := count_val - 1
					end
				end
			end
			output_qu := (count_val >= preset_val)
			output_qd := (count_val <= 0)
			prev_cu := input_cu
			prev_cd := input_cd
			last_scan_time_ms := a_current_time_ms
		end

invariant
	pv_non_negative: preset_val >= 0
	cv_non_negative: count_val >= 0

end
