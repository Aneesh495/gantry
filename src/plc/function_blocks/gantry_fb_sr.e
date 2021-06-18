note
	description: "Standard IEC 61131-3 set-dominant bistable latch function block (SR)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_SR

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_s1 := False
			input_r := False
			output_q1 := False
		ensure
			name_set: name.is_equal (a_name)
			q1_false: not output_q1
		end

feature -- Inputs

	input_s1: BOOLEAN
	input_r: BOOLEAN

feature -- Outputs

	output_q1: BOOLEAN

feature -- Mutators

	set_inputs (a_s1, a_r: BOOLEAN)
		do
			input_s1 := a_s1
			input_r := a_r
		ensure
			s1_set: input_s1 = a_s1
			r_set: input_r = a_r
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		do
			output_q1 := input_s1 or (not input_r and output_q1)
			last_scan_time_ms := a_current_time_ms
		end

end
