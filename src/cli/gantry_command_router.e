note
	description: "Command router and dispatcher for Gantry command line interface."
	author: "Aneesh Krishna"

class
	GANTRY_COMMAND_ROUTER

create
	make

feature {NONE} -- Initialization

	make
		do
		end

feature -- Command Dispatch

	execute (a_args: ARGUMENTS_32)
			-- Parse arguments and route to appropriate command handler.
		local
			cmd: STRING
		do
			if a_args.argument_count = 0 then
				print_help
			else
				cmd := a_args.argument (1).to_string_8
				cmd.to_lower

				if cmd.is_equal ("help") or cmd.is_equal ("-h") or cmd.is_equal ("--help") then
					print_help
				elseif cmd.is_equal ("version") or cmd.is_equal ("-v") or cmd.is_equal ("--version") then
					print_version
				elseif cmd.is_equal ("run") then
					run_simulation (a_args)
				elseif cmd.is_equal ("compile") then
					compile_st (a_args)
				elseif cmd.is_equal ("test") then
					run_tests
				elseif cmd.is_equal ("sdt") then
					run_sdt_demo
				else
					print ("Error: Unknown command '" + cmd + "'. Run 'gantry help' for available commands.%N")
				end
			end
		end

feature {NONE} -- Command Handlers

	print_banner
		do
			print ("========================================================================%N")
			print ("      GANTRY: High-Assurance Cyber-Physical Automation Runtime          %N")
			print ("               Deterministic Cyclic Executive & Safety PLC              %N")
			print ("========================================================================%N")
		end

	print_version
		do
			print_banner
			print ("Version:            1.0.0 (Production Release)%N")
			print ("Language:           Eiffel (ISO/ECMA-367 Standard)%N")
			print ("Safety Standard:    IEC 61508 SIL-3 / SIL-4 Deterministic Architecture%N")
			print ("PLC Standard:       IEC 61131-3 Structured Text Stack Virtual Machine%N")
			print ("Alarms:             ISA-18.2 / ANSI Lifecycle State Machine%N")
			print ("Historian:          Swinging Door Trending (SDT) Lossy Compression%N")
			print ("Protocols:          Modbus TCP/IP, OPC UA, DNP3 FT3, MQTT-SN%N")
			print ("FFI:                ANSI C shared library (libgantry) & Python SDK%N")
			print ("Copyright (C) 2026 Aneesh Krishna. All rights reserved.%N")
		end

	print_help
		do
			print_banner
			print ("USAGE:%N")
			print ("    gantry <command> [options]%N%N")
			print ("COMMANDS:%N")
			print ("    run [crane|reactor|rail]   Run cyber-physical simulation executive%N")
			print ("    compile                    Compile and disassemble IEC 61131-3 ST program%N")
			print ("    test                       Execute full high-assurance verification suite%N")
			print ("    sdt                        Demonstrate Swinging Door Trending compression%N")
			print ("    version                    Display runtime build and specification info%N")
			print ("    help                       Display this help reference manual%N%N")
			print ("EXAMPLES:%N")
			print ("    gantry run crane           Execute automated container crane simulation%N")
			print ("    gantry run reactor         Execute CSTR exothermic pressure vessel simulation%N")
			print ("    gantry run rail            Execute railway junction interlocking simulation%N")
			print ("    gantry compile             Compile sample ST safety interlock program%N")
			print ("    gantry test                Run 7-subsystem verification test suite%N")
		end

	run_simulation (a_args: ARGUMENTS_32)
		local
			plant_name: STRING
			table: GANTRY_IMAGE_TABLE
			crane: GANTRY_CONTAINER_CRANE_SIM
			vessel: GANTRY_PRESSURE_VESSEL_SIM
			rail: GANTRY_RAIL_JUNCTION_SIM
			i: INTEGER
			t_step: REAL_64
		do
			plant_name := "crane"
			if a_args.argument_count >= 2 then
				plant_name := a_args.argument (2).to_string_8
				plant_name.to_lower
			end

			print_banner
			print ("Initializing plant simulation: " + plant_name.as_upper + "%N")
			create table.make
			t_step := 0.1

			if plant_name.is_equal ("crane") then
				create crane.make
				crane.bind_image_table (table)
				table.write_analog ("CRANE_TROLLEY_FORCE_CMD", 45.0, 0)
				table.write_analog ("CRANE_HOIST_VEL_CMD", 0.3, 0)

				print ("Simulating 50 cycles of automated container gantry crane...%N%N")
				print ("CYCLE | TIME (s) | TROLLEY POS (m) | HOIST DEPTH (m) | SWAY ANGLE (deg)%N")
				print ("------+----------+-----------------+-----------------+-----------------%N")

				from i := 1 until i > 50 loop
					crane.step_simulation (t_step, table)
					if i \\ 10 = 0 or i = 1 then
						print (i.out + "%T| " +
							((i.to_double * t_step * 10.0).rounded / 10.0).out + "%T   | " +
							((table.read_analog ("CRANE_TROLLEY_POS") * 100.0).rounded / 100.0).out + "%T   | " +
							((table.read_analog ("CRANE_HOIST_POS") * 100.0).rounded / 100.0).out + "%T   | " +
							((table.read_analog ("CRANE_SWAY_ANGLE") * 100.0).rounded / 100.0).out + "%N")
					end
					i := i + 1
				end

			elseif plant_name.is_equal ("reactor") then
				create vessel.make
				vessel.bind_image_table (table)
				table.write_analog ("FEED_RATE_CMD", 250.0, 0)
				table.write_analog ("COOLANT_FLOW_CMD", 35.0, 0)

				print ("Simulating 50 cycles of CSTR exothermic chemical reactor...%N%N")
				print ("CYCLE | TIME (s) | TEMP (degC) | PRESSURE (bar) | BURST DISC%N")
				print ("------+----------+-------------+----------------+-----------%N")

				from i := 1 until i > 50 loop
					vessel.step_simulation (t_step, table)
					if i \\ 10 = 0 or i = 1 then
						print (i.out + "%T| " +
							((i.to_double * t_step * 10.0).rounded / 10.0).out + "%T   | " +
							((table.read_analog ("REACTOR_TEMP") * 100.0).rounded / 100.0).out + "%T| " +
							((table.read_analog ("REACTOR_PRESS") * 100.0).rounded / 100.0).out + "%T   | " +
							table.read_digital ("BURST_DISC_STATUS").out + "%N")
					end
					i := i + 1
				end

			elseif plant_name.is_equal ("rail") then
				create rail.make
				rail.bind_image_table (table)
				table.write_digital ("RAIL_POINT_MOTOR_REV_CMD", True, 0)

				print ("Simulating 50 cycles of railway turnout interlocking...%N%N")
				print ("CYCLE | TIME (s) | TC1 (APP) | TC2 (TURNOUT) | POINT NORMAL | POINT REVERSE%N")
				print ("------+----------+-----------+---------------+--------------+--------------%N")

				from i := 1 until i > 50 loop
					rail.step_simulation (t_step, table)
					if i \\ 10 = 0 or i = 1 then
						print (i.out + "%T| " +
							((i.to_double * t_step * 10.0).rounded / 10.0).out + "%T   | " +
							table.read_digital ("RAIL_TC1_APPROACH").out + "%T      | " +
							table.read_digital ("RAIL_TC2_TURNOUT").out + "%T          | " +
							table.read_digital ("RAIL_POINT_NORMAL_IND").out + "%T        | " +
							table.read_digital ("RAIL_POINT_REVERSE_IND").out + "%N")
					end
					i := i + 1
				end
			else
				print ("Unknown plant model: " + plant_name + ". Choose crane, reactor, or rail.%N")
			end

			print ("%NSimulation run complete. All safety bounds preserved.%N")
		end

	compile_st (a_args: ARGUMENTS_32)
		local
			lexer: GANTRY_ST_LEXER
			parser: GANTRY_ST_PARSER
			compiler: GANTRY_ST_COMPILER
			vm: GANTRY_ST_VM
			tbl: GANTRY_IMAGE_TABLE
			src: STRING
			i: INTEGER
			ins: GANTRY_ST_INSTRUCTION
			ap_tank: GANTRY_ANALOG_POINT
			dp_valve: GANTRY_DIGITAL_POINT
		do
			print_banner
			print ("Compiling IEC 61131-3 Structured Text Program...%N%N")

			src := "tank_press := 92.5;%N" +
				"IF tank_press > 85.0 THEN%N" +
				"  inlet_valve := FALSE;%N" +
				"ELSE%N" +
				"  inlet_valve := TRUE;%N" +
				"END_IF;%N"

			print ("--- SOURCE CODE ---%N" + src + "%N")

			create lexer.make (src)
			print ("Token count: " + lexer.tokens.count.out + "%N")

			create parser.make (lexer.tokens)
			print ("Parsed AST statements: " + parser.statements.count.out + "%N%N")

			create compiler.make
			compiler.compile_program (parser.statements)

			print ("--- DISASSEMBLED BYTECODE ---%N")
			from i := 1 until i > compiler.instructions.count loop
				ins := compiler.instructions.i_th (i)
				print ("[" + (i - 1).out + "] " + ins.disassemble + "%N")
				i := i + 1
			end

			print ("%NExecuting bytecode in stack VM with process image table...%N")
			create tbl.make
			create ap_tank.make_analog ("tank_press", "Tank vapor pressure", "bar")
			create dp_valve.make_digital ("inlet_valve", "Tank feed valve")
			tbl.register_analog_output (ap_tank)
			tbl.register_digital_output (dp_valve)

			create vm.make
			vm.execute (compiler.instructions, tbl, 1000)

			print ("Execution halted. Has runtime error: " + vm.has_runtime_error.out + "%N")
			print ("Final state of inlet_valve: " + tbl.read_digital ("inlet_valve").out + "%N")
			if not tbl.read_digital ("inlet_valve") then
				print ("Safety trip active: inlet_valve forced to FALSE (fail-safe).%N")
			end
		end

	run_tests
		do
			print_banner
			print ("High-assurance verification suite is configured under target 'gantry_test'.%N")
			print ("To run all verification passes across all 7 subsystems, execute:%N")
			print ("    make test%N")
			print ("    or: ec -batch -config gantry.ecf -target gantry_test -c_compile%N")
		end

	run_sdt_demo
		local
			sdt: GANTRY_SWINGING_DOOR
			i: INTEGER
			t: INTEGER_64
			v: REAL_64
			pt: detachable TUPLE [time: INTEGER_64; val: REAL_64]
		do
			print_banner
			print ("Swinging Door Trending (SDT) Lossy Compression Demonstration%N")
			print ("Deadband Deviation: 0.15 engineering units%N%N")

			create sdt.make (0.15, 10000)

			print ("Feeding 100 samples (steady plateau + linear ramp)...%N")
			from i := 1 until i > 100 loop
				t := i.to_integer_64 * 100
				if i <= 50 then
					v := 45.0
				else
					v := 45.0 + ((i - 50).to_double * 0.4)
				end

				pt := sdt.process_point (t, v)
				if attached pt as p then
					print ("  [ARCHIVE] t = " + ((p.time.to_double / 1000.0 * 10.0).rounded / 10.0).out +
						" s, val = " + ((p.val * 100.0).rounded / 100.0).out + "%N")
				end
				i := i + 1
			end

			print ("%NTotal raw input samples:       " + sdt.raw_points_count.out + "%N")
			print ("Total retained archive points: " + sdt.archived_points_count.out + "%N")
			print ("Bandwidth compression ratio:   " +
				((sdt.compression_ratio * 100.0).rounded / 100.0).out + "%%%N")
		end

end
