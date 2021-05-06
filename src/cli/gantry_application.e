note
	description: "Top-level command line entrypoint for the Gantry cyber-physical automation runtime."
	author: "Aneesh Krishna"

class
	GANTRY_APPLICATION

create
	make

feature {NONE} -- Initialization

	make
			-- Bootstrap and run Gantry CLI.
		do
			print ("Gantry High-Assurance Cyber-Physical Automation Engine%N")
			print ("Version 1.0.0 (Design-by-Contract SIL-3/4 Runtime)%N")
		end

end
