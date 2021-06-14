note
	description: "Standard IEC 61131-3 falling edge detector function block (F_TRIG)."
	author: "Aneesh Krishna"

class
	GANTRY_FB_F_TRIG

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_clk := False
			output_q := False
			prev_clk := False
		ensure
			name_set: name.is_equal (a_name)
			q_false: not output_q
		end

feature -- Inputs

	input_clk: BOOLEAN

feature -- Outputs

	output_q: BOOLEAN

feature {NONE} -- Internal State

	prev_clk: BOOLEAN

feature -- Mutator

	set_clk (a_clk: BOOLEAN)
		do
			input_clk := a_clk
		ensure
			clk_set: input_clk = a_clk
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		do
			output_q := not input_clk and prev_clk
			prev_clk := input_clk
			last_scan_time_ms := a_current_time_ms
		end

end
