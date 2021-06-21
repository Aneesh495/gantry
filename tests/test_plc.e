note
	description: "Comprehensive unit tests for IEC 61131-3 Structured Text lexer, parser, compiler, VM, and standard function blocks."
	author: "Aneesh Krishna"

class
	TEST_PLC

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("Running PLC Subsystem Unit Tests...%N")
			test_st_lexer
			test_st_parser
			test_st_compiler_and_vm
			test_fb_timers
			test_fb_edge_detectors
			test_fb_counters
			test_fb_bistables
			test_fb_pid_controller
			print ("  -> PLC Subsystem Tests: ALL PASSED%N")
		end

feature -- Tests

	test_st_lexer
		local
			code: STRING
			lexer: GANTRY_ST_LEXER
		do
			code := "(* Test script *)%NIF tank_level > 75.5 AND pump_en THEN%N  valve_cmd := TRUE;%NEND_IF;%N"
			create lexer.make (code)
			check has_tokens: lexer.tokens.count >= 10 end
			check first_is_if: lexer.tokens.i_th (1).type = lexer.Tok_if end
			check second_is_ident: lexer.tokens.i_th (2).lexeme.is_equal ("tank_level") end
			check third_is_gt: lexer.tokens.i_th (3).type = lexer.Tok_gt end
			check fourth_is_real: lexer.tokens.i_th (4).lexeme.is_equal ("75.5") end
			check fifth_is_and: lexer.tokens.i_th (5).type = lexer.Tok_and end
		end

	test_st_parser
		local
			code: STRING
			lexer: GANTRY_ST_LEXER
			parser: GANTRY_ST_PARSER
		do
			code := "target := 10 + 20 * 3;%NIF target > 50 THEN%N  alarm := TRUE;%NELSE%N  alarm := FALSE;%NEND_IF;%N"
			create lexer.make (code)
			create parser.make (lexer.tokens)
			check no_parse_err: not parser.has_error end
			check two_stmts: parser.statements.count = 2 end
			check first_is_assign: parser.statements.i_th (1).stmt_kind = 1 end
			check second_is_if: parser.statements.i_th (2).stmt_kind = 2 end
		end

	test_st_compiler_and_vm
		local
			code: STRING
			lexer: GANTRY_ST_LEXER
			parser: GANTRY_ST_PARSER
			compiler: GANTRY_ST_COMPILER
			vm: GANTRY_ST_VM
			tbl: GANTRY_IMAGE_TABLE
			do_alarm: GANTRY_DIGITAL_POINT
			ao_target: GANTRY_ANALOG_POINT
			d: REAL_64
		do
			create tbl.make
			create do_alarm.make_digital ("ALARM_OUT", "Master alarm horn")
			create ao_target.make_analog ("TARGET_VAL", "Target value", "units")
			tbl.register_digital_output (do_alarm)
			tbl.register_analog_output (ao_target)

			code := "TARGET_VAL := 5.0 * (4.0 + 6.0);%NIF TARGET_VAL >= 50.0 THEN%N  ALARM_OUT := TRUE;%NELSE%N  ALARM_OUT := FALSE;%NEND_IF;%N"
			create lexer.make (code)
			create parser.make (lexer.tokens)
			check parse_ok: not parser.has_error end

			create compiler.make
			compiler.compile_program (parser.statements)
			check code_generated: compiler.instructions.count > 0 end

			create vm.make
			vm.execute (compiler.instructions, tbl, 1000)
			check no_runtime_err: not vm.has_runtime_error end

			d := tbl.read_analog ("TARGET_VAL") - 50.0
			check target_eval: d.abs < 0.001 end
			check alarm_active: tbl.read_digital ("ALARM_OUT") end
		end

	test_fb_timers
		local
			ton: GANTRY_FB_TON
			tof: GANTRY_FB_TOF
			tp: GANTRY_FB_TP
		do
			-- Test TON (On-Delay)
			create ton.make ("TON_TEST")
			ton.set_inputs (True, 50) -- 50 ms delay
			ton.step (1000)
			check ton_not_yet: not ton.output_q end

			ton.step (1030)
			check ton_still_not: not ton.output_q end

			ton.step (1060)
			check ton_tripped: ton.output_q end

			ton.set_inputs (False, 50)
			ton.step (1070)
			check ton_cleared: not ton.output_q end

			-- Test TOF (Off-Delay)
			create tof.make ("TOF_TEST")
			tof.set_inputs (True, 50)
			tof.step (1000)
			check tof_on: tof.output_q end

			tof.set_inputs (False, 50) -- Falling edge
			tof.step (1010)
			check tof_persists: tof.output_q end

			tof.step (1070) -- > 50 ms elapsed
			check tof_expired: not tof.output_q end

			-- Test TP (Pulse)
			create tp.make ("TP_TEST")
			tp.set_inputs (True, 40)
			tp.step (1000) -- Trigger pulse
			check tp_on: tp.output_q end

			tp.step (1020)
			check tp_mid: tp.output_q end

			tp.step (1050) -- > 40 ms elapsed
			check tp_off: not tp.output_q end
		end

	test_fb_edge_detectors
		local
			r_trig: GANTRY_FB_R_TRIG
			f_trig: GANTRY_FB_F_TRIG
		do
			create r_trig.make ("R_TEST")
			r_trig.set_clk (False)
			r_trig.step (100)
			check r_init: not r_trig.output_q end

			r_trig.set_clk (True)
			r_trig.step (110)
			check r_detected: r_trig.output_q end -- Rising edge

			r_trig.step (120)
			check r_cleared: not r_trig.output_q end -- Returns False next cycle

			create f_trig.make ("F_TEST")
			f_trig.set_clk (True)
			f_trig.step (100)
			check f_init: not f_trig.output_q end

			f_trig.set_clk (False)
			f_trig.step (110)
			check f_detected: f_trig.output_q end -- Falling edge

			f_trig.step (120)
			check f_cleared: not f_trig.output_q end
		end

	test_fb_counters
		local
			ctu: GANTRY_FB_CTU
			ctd: GANTRY_FB_CTD
			ctud: GANTRY_FB_CTUD
		do
			-- Up counter: Preset 2
			create ctu.make ("CTU_TEST")
			ctu.set_inputs (False, False, 2)
			ctu.step (100)
			check ctu_init: not ctu.output_q and ctu.count_val = 0 end

			ctu.set_inputs (True, False, 2) -- Pulse 1
			ctu.step (110)
			check count_1: ctu.count_val = 1 and not ctu.output_q end

			ctu.set_inputs (False, False, 2)
			ctu.step (120)

			ctu.set_inputs (True, False, 2) -- Pulse 2
			ctu.step (130)
			check count_2: ctu.count_val = 2 and ctu.output_q end

			-- Down counter: Preset 2
			create ctd.make ("CTD_TEST")
			ctd.set_inputs (False, True, 2) -- Load 2
			ctd.step (100)
			check ctd_loaded: ctd.count_val = 2 and not ctd.output_q end

			ctd.set_inputs (True, False, 2) -- Pulse down 1
			ctd.step (110)
			check ctd_1: ctd.count_val = 1 and not ctd.output_q end

			ctd.set_inputs (False, False, 2)
			ctd.step (120)

			ctd.set_inputs (True, False, 2) -- Pulse down 2
			ctd.step (130)
			check ctd_zero: ctd.count_val = 0 and ctd.output_q end

			-- Up-down counter
			create ctud.make ("CTUD_TEST")
			ctud.set_inputs (False, False, True, False, 3) -- Reset
			ctud.step (100)
			check ctud_init: ctud.count_val = 0 end
		end

	test_fb_bistables
		local
			sr: GANTRY_FB_SR
			rs: GANTRY_FB_RS
		do
			-- Set-dominant
			create sr.make ("SR_TEST")
			sr.set_inputs (True, False)
			sr.step (100)
			check sr_set: sr.output_q1 end

			sr.set_inputs (True, True) -- Conflict: Set wins
			sr.step (110)
			check sr_set_wins: sr.output_q1 end

			sr.set_inputs (False, True) -- Reset
			sr.step (120)
			check sr_reset: not sr.output_q1 end

			-- Reset-dominant
			create rs.make ("RS_TEST")
			rs.set_inputs (True, False)
			rs.step (100)
			check rs_set: rs.output_q1 end

			rs.set_inputs (True, True) -- Conflict: Reset wins
			rs.step (110)
			check rs_reset_wins: not rs.output_q1 end
		end

	test_fb_pid_controller
		local
			pid: GANTRY_FB_PID
		do
			create pid.make ("PID_TEST")
			pid.set_parameters (2.0, 5.0, 0.0, 0.0, 100.0) -- Kp=2.0, Tn=5.0s, Min=0, Max=100

			-- In manual mode: tracks Y_MAN
			pid.set_inputs (False, 50.0, 40.0, 25.0)
			pid.step (1000)
			check pid_man: (pid.output_y - 25.0).abs < 0.001 end

			-- In auto mode: SP=50, PV=40 -> Error=10, Kp=2 -> P term = 20
			pid.set_inputs (True, 50.0, 40.0, 25.0)
			pid.step (1100)
			check pid_auto_moves: pid.output_y > 20.0 end
			check not pid.limit_min and not pid.limit_max end
		end

end
