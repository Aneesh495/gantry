note
	description: "Standard IEC 61131-3 on-delay timer function block (TON)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_TON

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
		ensure
			name_set: name.is_equal (a_name)
			q_false: not output_q
			et_zero: elapsed_time_ms = 0
		end

feature -- Inputs

	input_in: BOOLEAN
			-- Trigger input signal.

	preset_time_ms: INTEGER_64
			-- Configured delay duration in milliseconds.

feature -- Outputs

	output_q: BOOLEAN
			-- Delayed active-high output.

	elapsed_time_ms: INTEGER_64
			-- Time elapsed since rising edge of input_in while active.

feature {NONE} -- Internal State

	start_time_ms: INTEGER_64

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
			if not input_in then
				output_q := False
				elapsed_time_ms := 0
				start_time_ms := 0
			else
				if start_time_ms = 0 then
					start_time_ms := a_current_time_ms
					elapsed_time_ms := 0
				else
					dt := a_current_time_ms - start_time_ms
					if dt >= preset_time_ms then
						elapsed_time_ms := preset_time_ms
						output_q := True
					else
						elapsed_time_ms := dt
						output_q := False
					end
				end
			end
			last_scan_time_ms := a_current_time_ms
		end

invariant
	pt_non_negative: preset_time_ms >= 0
	et_bounded: elapsed_time_ms >= 0 and elapsed_time_ms <= preset_time_ms

end
