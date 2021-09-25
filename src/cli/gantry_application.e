note
	description: "Top-level command line entrypoint for the Gantry cyber-physical automation runtime."
	author: "Aneesh Krishna"

class
	GANTRY_APPLICATION

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Bootstrap and run Gantry CLI.
		local
			router: GANTRY_COMMAND_ROUTER
		do
			create router.make
			router.execute (Current)
		end

end
