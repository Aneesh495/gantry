note
	description: "DNP3 Application Layer Object Groups and Function Codes conforming to IEEE 1815-2012."
	author: "Aneesh Krishna"

class
	GANTRY_DNP3_OBJECT_GROUP

feature -- Object Groups

	Group_binary_input: INTEGER = 1
	Group_binary_output: INTEGER = 10
	Group_analog_input: INTEGER = 30
	Group_analog_output: INTEGER = 40
	Group_class_data: INTEGER = 60

feature -- Function Codes

	Fc_confirm: INTEGER = 0
	Fc_read: INTEGER = 1
	Fc_write: INTEGER = 2
	Fc_select: INTEGER = 3
	Fc_operate: INTEGER = 4
	Fc_direct_operate: INTEGER = 5
	Fc_response: INTEGER = 129 -- 0x81
	Fc_unsolicited_response: INTEGER = 130 -- 0x82

feature -- Qualifiers

	Qualifier_all_objects: INTEGER = 6 -- 0x06

end
