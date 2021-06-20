note
	description: "Industrial Proportional-Integral-Derivative (PID) controller function block with anti-windup clamping and bumpless transfer."
	author: "Aneesh Krishna"

class
	GANTRY_FB_PID

inherit
	GANTRY_FB_BASE

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING)
		do
			make_fb (a_name)
			input_auto := False
			setpoint := 0.0
			process_variable := 0.0
			gain_kp := 1.0
			integral_time_tn_sec := 10.0
			derivative_time_tv_sec := 0.0
			output_min := 0.0
			output_max := 100.0
			manual_output := 0.0
			output_y := 0.0
			limit_min := False
			limit_max := False
			integral_sum := 0.0
			prev_pv := 0.0
			prev_time_ms := 0
		ensure
			name_set: name.is_equal (a_name)
			default_kp: gain_kp = 1.0
			not_auto: not input_auto
		end

feature -- Inputs

	input_auto: BOOLEAN
			-- True for automatic closed-loop control; False for manual output tracking.

	setpoint: REAL_64
			-- Desired target engineering value (SP).

	process_variable: REAL_64
			-- Measured feedback engineering value from transmitter (PV).

	gain_kp: REAL_64
			-- Proportional gain parameter.

	integral_time_tn_sec: REAL_64
			-- Integral reset time in seconds (0.0 disables integration).

	derivative_time_tv_sec: REAL_64
			-- Derivative rate time in seconds (0.0 disables derivative action).

	output_min: REAL_64
			-- Output clamp lower boundary.

	output_max: REAL_64
			-- Output clamp upper boundary.

	manual_output: REAL_64
			-- Commanded output when operating in manual mode (Y_MAN).

feature -- Outputs

	output_y: REAL_64
			-- Calculated control effort actuator command (Y).

	limit_min: BOOLEAN
			-- True when control output is saturated at minimum limit.

	limit_max: BOOLEAN
			-- True when control output is saturated at maximum limit.

feature {NONE} -- Internal State

	integral_sum: REAL_64
	prev_pv: REAL_64
	prev_time_ms: INTEGER_64

feature -- Mutators

	set_parameters (a_kp, a_tn_sec, a_tv_sec, a_min, a_max: REAL_64)
		require
			valid_span: a_max > a_min
			non_negative_tn: a_tn_sec >= 0.0
			non_negative_tv: a_tv_sec >= 0.0
		do
			gain_kp := a_kp
			integral_time_tn_sec := a_tn_sec
			derivative_time_tv_sec := a_tv_sec
			output_min := a_min
			output_max := a_max
		ensure
			kp_set: gain_kp = a_kp
			tn_set: integral_time_tn_sec = a_tn_sec
			tv_set: derivative_time_tv_sec = a_tv_sec
			min_set: output_min = a_min
			max_set: output_max = a_max
		end

	set_inputs (a_auto: BOOLEAN; a_sp, a_pv, a_man: REAL_64)
		do
			input_auto := a_auto
			setpoint := a_sp
			process_variable := a_pv
			manual_output := a_man
		ensure
			auto_set: input_auto = a_auto
			sp_set: setpoint = a_sp
			pv_set: process_variable = a_pv
			man_set: manual_output = a_man
		end

feature -- Step

	step (a_current_time_ms: INTEGER_64)
		local
			dt_sec: REAL_64
			err: REAL_64
			p_term, i_term, d_term: REAL_64
			unclamped_y: REAL_64
		do
			if not input_auto then
				-- Manual mode: bumpless tracking
				output_y := manual_output
				if output_y < output_min then
					output_y := output_min
				elseif output_y > output_max then
					output_y := output_max
				end
				-- Initialize integrator to avoid bump upon switching to AUTO
				integral_sum := output_y
				limit_min := (output_y <= output_min)
				limit_max := (output_y >= output_max)
				prev_pv := process_variable
				prev_time_ms := a_current_time_ms
			else
				if prev_time_ms = 0 then
					dt_sec := 0.01 -- Default 10 ms if first step
				else
					dt_sec := (a_current_time_ms - prev_time_ms).to_double / 1000.0
				end

				if dt_sec <= 0.000001 then
					dt_sec := 0.001
				end

				err := setpoint - process_variable
				p_term := gain_kp * err

				-- Integration with anti-windup clamping
				if integral_time_tn_sec > 0.0001 then
					integral_sum := integral_sum + (gain_kp / integral_time_tn_sec) * err * dt_sec
					-- Clamp integral term within physical bounds
					if integral_sum > output_max then
						integral_sum := output_max
					elseif integral_sum < output_min then
						integral_sum := output_min
					end
					i_term := integral_sum
				else
					i_term := 0.0
				end

				-- Derivative on PV (derivative kick prevention)
				if derivative_time_tv_sec > 0.0001 and dt_sec > 0.0 then
					d_term := -gain_kp * derivative_time_tv_sec * (process_variable - prev_pv) / dt_sec
				else
					d_term := 0.0
				end

				unclamped_y := p_term + i_term + d_term

				-- Output clamping and saturation alarms
				if unclamped_y >= output_max then
					output_y := output_max
					limit_max := True
					limit_min := False
				elseif unclamped_y <= output_min then
					output_y := output_min
					limit_min := True
					limit_max := False
				else
					output_y := unclamped_y
					limit_min := False
					limit_max := False
				end

				prev_pv := process_variable
				prev_time_ms := a_current_time_ms
			end
			last_scan_time_ms := a_current_time_ms
		end

invariant
	valid_limits: output_max > output_min

end
