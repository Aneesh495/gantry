note
	description: "Compiled bytecode instruction executed by the Gantry Structured Text virtual machine."
	author: "Aneesh Krishna"

class
	GANTRY_ST_INSTRUCTION

inherit
	GANTRY_ST_OPCODE

create
	make_simple,
	make_with_int,
	make_with_real,
	make_with_bool,
	make_with_string,
	make_with_jump

feature {NONE} -- Initializers

	make_simple (a_op: INTEGER)
		do
			opcode := a_op
			int_operand := 0
			real_operand := 0.0
			bool_operand := False
			string_operand := ""
			jump_target := 0
		ensure
			opcode_set: opcode = a_op
		end

	make_with_int (a_op: INTEGER; a_val: INTEGER_64)
		do
			make_simple (a_op)
			int_operand := a_val
		ensure
			opcode_set: opcode = a_op
			int_set: int_operand = a_val
		end

	make_with_real (a_op: INTEGER; a_val: REAL_64)
		do
			make_simple (a_op)
			real_operand := a_val
		ensure
			opcode_set: opcode = a_op
			real_set: real_operand = a_val
		end

	make_with_bool (a_op: INTEGER; a_val: BOOLEAN)
		do
			make_simple (a_op)
			bool_operand := a_val
		ensure
			opcode_set: opcode = a_op
			bool_set: bool_operand = a_val
		end

	make_with_string (a_op: INTEGER; a_str: STRING)
		do
			make_simple (a_op)
			string_operand := a_str.twin
		ensure
			opcode_set: opcode = a_op
			string_set: string_operand.is_equal (a_str)
		end

	make_with_jump (a_op: INTEGER; a_target: INTEGER)
		do
			make_simple (a_op)
			jump_target := a_target
		ensure
			opcode_set: opcode = a_op
			target_set: jump_target = a_target
		end

feature -- Access

	opcode: INTEGER
	int_operand: INTEGER_64
	real_operand: REAL_64
	bool_operand: BOOLEAN
	string_operand: STRING
	jump_target: INTEGER

feature -- Mutators

	set_jump_target (a_target: INTEGER)
			-- Patch forward jump target offset.
		require
			valid_target: a_target >= 1
		do
			jump_target := a_target
		ensure
			target_patched: jump_target = a_target
		end

feature -- Disassembly

	disassemble: STRING
		do
			Result := opcode_name (opcode)
			inspect opcode
			when Op_push_int then
				Result.append (" " + int_operand.out)
			when Op_push_real then
				Result.append (" " + real_operand.out)
			when Op_push_bool then
				Result.append (" " + bool_operand.out)
			when Op_load_var, Op_store_var, Op_call_fb then
				Result.append (" " + string_operand)
			when Op_jmp, Op_jz, Op_jnz then
				Result.append (" -> " + jump_target.out)
			else
			end
		ensure
			not_empty: not Result.is_empty
		end

invariant
	string_attached: string_operand /= Void

end
