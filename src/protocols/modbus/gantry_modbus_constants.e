note
	description: "Modbus Application Protocol (MBAP) function codes and exception specifications."
	author: "Aneesh Krishna"

class
	GANTRY_MODBUS_CONSTANTS

feature -- Function Codes

	Fc_read_coils: INTEGER = 1
	Fc_read_discrete_inputs: INTEGER = 2
	Fc_read_holding_registers: INTEGER = 3
	Fc_read_input_registers: INTEGER = 4
	Fc_write_single_coil: INTEGER = 5
	Fc_write_single_register: INTEGER = 6
	Fc_write_multiple_coils: INTEGER = 15
	Fc_write_multiple_registers: INTEGER = 16

feature -- Exception Codes

	Ex_illegal_function: INTEGER = 1
	Ex_illegal_data_address: INTEGER = 2
	Ex_illegal_data_value: INTEGER = 3
	Ex_slave_device_failure: INTEGER = 4
	Ex_acknowledge: INTEGER = 5
	Ex_slave_device_busy: INTEGER = 6

feature -- Query

	is_supported_function (a_fc: INTEGER): BOOLEAN
		do
			Result := (a_fc = Fc_read_coils or a_fc = Fc_read_discrete_inputs or
				a_fc = Fc_read_holding_registers or a_fc = Fc_read_input_registers or
				a_fc = Fc_write_single_coil or a_fc = Fc_write_single_register or
				a_fc = Fc_write_multiple_coils or a_fc = Fc_write_multiple_registers)
		end

	function_name (a_fc: INTEGER): STRING
		do
			inspect a_fc
			when Fc_read_coils then Result := "READ_COILS"
			when Fc_read_discrete_inputs then Result := "READ_DISCRETE_INPUTS"
			when Fc_read_holding_registers then Result := "READ_HOLDING_REGISTERS"
			when Fc_read_input_registers then Result := "READ_INPUT_REGISTERS"
			when Fc_write_single_coil then Result := "WRITE_SINGLE_COIL"
			when Fc_write_single_register then Result := "WRITE_SINGLE_REGISTER"
			when Fc_write_multiple_coils then Result := "WRITE_MULTIPLE_COILS"
			when Fc_write_multiple_registers then Result := "WRITE_MULTIPLE_REGISTERS"
			else
				Result := "UNKNOWN_FC"
			end
		ensure
			not_empty: not Result.is_empty
		end

end
