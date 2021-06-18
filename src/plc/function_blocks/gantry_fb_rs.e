note
	description: "Standard IEC 61131-3 reset-dominant bistable latch function block (RS)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_RS

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_s := False
			input_r1 := False
			output_q1 := False
		ensure
			name_set: name.is_equal (a_name)
			q1_false: not output_q1
		end

feature -- Inputs

	input_s: BOOLEAN
	input_r1: BOOLEAN

feature -- Outputs

	output_q1: BOOLEAN

feature -- Mutators

	set_inputs (a_s, a_r1: BOOLEAN)
		do
			input_s := a_s
			input_r1 := a_r1
		ensure
			s_set: input_s = a_s
			r1_set: input_r1 = a_r1
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		do
			output_q1 := not input_r1 and (input_s or output_q1)
			last_scan_time_ms := a_current_time_ms
		end

end
