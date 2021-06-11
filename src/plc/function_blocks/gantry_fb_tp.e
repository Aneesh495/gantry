note
	description: "Standard IEC 61131-3 pulse timer function block (TP)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_TP

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_in := False
			preset_time_ms := 0
			output_q := False
			elapsed_time_ms := 0
			start_time_ms := 0
			prev_in := False
		ensure
			name_set: name.is_equal (a_name)
			q_false: not output_q
		end

feature -- Inputs

	input_in: BOOLEAN
	preset_time_ms: INTEGER_64

feature -- Outputs

	output_q: BOOLEAN
	elapsed_time_ms: INTEGER_64

feature {NONE} -- Internal State

	start_time_ms: INTEGER_64
	prev_in: BOOLEAN

feature -- Mutators

	set_inputs (a_in: BOOLEAN; a_pt_ms: INTEGER_64)
		require
			non_negative_pt: a_pt_ms >= 0
		do
			input_in := a_in
			preset_time_ms := a_pt_ms
		ensure
			in_set: input_in = a_in
			pt_set: preset_time_ms = a_pt_ms
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		local
			dt: INTEGER_64
		do
			if not output_q and not prev_in and input_in then
				-- Rising edge trigger
				output_q := True
				start_time_ms := a_current_time_ms
				elapsed_time_ms := 0
			elseif output_q then
				dt := a_current_time_ms - start_time_ms
				if dt >= preset_time_ms then
					elapsed_time_ms := preset_time_ms
					output_q := False
					start_time_ms := 0
				else
					elapsed_time_ms := dt
				end
			else
				elapsed_time_ms := 0
			end
			prev_in := input_in
			last_scan_time_ms := a_current_time_ms
		end

invariant
	pt_non_negative: preset_time_ms >= 0
	et_bounded: elapsed_time_ms >= 0 and elapsed_time_ms <= preset_time_ms

end
