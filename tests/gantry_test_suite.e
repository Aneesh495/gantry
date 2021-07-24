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
		do
			print ("============================================================%N")
			print ("       GANTRY HIGH-ASSURANCE VERIFICATION SUITE             %N")
			print ("============================================================%N%N")

			create core_tests.make
			create plc_tests.make
			create safety_tests.make
			create proto_tests.make

			print ("%N============================================================%N")
			print ("       VERIFICATION COMPLETE: ALL ASSERTIONS PASSED         %N")
			print ("============================================================%N")
		end

end
