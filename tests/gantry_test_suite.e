note
	description: "Top-level test runner executing comprehensive verification passes across all Gantry subsystems."
	author: "Aneesh Krishna"

class
	GANTRY_TEST_SUITE

create
	make

feature {NONE} -- Initialization

	make
			-- Run all subsystem test suites.
		local
			core_tests: TEST_CORE
			plc_tests: TEST_PLC
			safety_tests: TEST_SAFETY
			proto_tests: TEST_PROTOCOLS
			hist_tests: TEST_HISTORIAN
			alarm_tests: TEST_ALARMS
			sim_tests: TEST_SIMULATIONS
		do
			print ("============================================================%N")
			print ("       GANTRY HIGH-ASSURANCE VERIFICATION SUITE             %N")
			print ("============================================================%N%N")

			create core_tests.make
			create plc_tests.make
			create safety_tests.make
			create proto_tests.make
			create hist_tests.make
			create alarm_tests.make
			create sim_tests.make

			print ("%N============================================================%N")
			print ("       VERIFICATION COMPLETE: ALL ASSERTIONS PASSED         %N")
			print ("============================================================%N")
		end

end
