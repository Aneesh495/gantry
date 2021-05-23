note
	description: "Virtual machine bytecode opcodes for IEC 61131-3 Structured Text execution."
	author: "Aneesh Krishna"

class
	GANTRY_ST_OPCODE

feature -- Opcodes

	Op_nop: INTEGER = 0
	Op_push_int: INTEGER = 1
	Op_push_real: INTEGER = 2
	Op_push_bool: INTEGER = 3
	Op_load_var: INTEGER = 4
	Op_store_var: INTEGER = 5

	-- Arithmetic
	Op_add: INTEGER = 10
	Op_sub: INTEGER = 11
	Op_mul: INTEGER = 12
	Op_div: INTEGER = 13
	Op_mod: INTEGER = 14
	Op_neg: INTEGER = 15

	-- Boolean Logic
	Op_and: INTEGER = 20
	Op_or: INTEGER = 21
	Op_xor: INTEGER = 22
	Op_not: INTEGER = 23

	-- Relational Comparisons
	Op_eq: INTEGER = 30
	Op_neq: INTEGER = 31
	Op_lt: INTEGER = 32
	Op_le: INTEGER = 33
	Op_gt: INTEGER = 34
	Op_ge: INTEGER = 35

	-- Flow Control
	Op_jmp: INTEGER = 40
	Op_jz: INTEGER = 41
	Op_jnz: INTEGER = 42
	Op_call_fb: INTEGER = 50
	Op_halt: INTEGER = 60

feature -- Diagnostics

	opcode_name (a_op: INTEGER): STRING
		do
			inspect a_op
			when Op_nop then Result := "NOP"
			when Op_push_int then Result := "PUSH_INT"
			when Op_push_real then Result := "PUSH_REAL"
			when Op_push_bool then Result := "PUSH_BOOL"
			when Op_load_var then Result := "LOAD_VAR"
			when Op_store_var then Result := "STORE_VAR"
			when Op_add then Result := "ADD"
			when Op_sub then Result := "SUB"
			when Op_mul then Result := "MUL"
			when Op_div then Result := "DIV"
			when Op_mod then Result := "MOD"
			when Op_neg then Result := "NEG"
			when Op_and then Result := "AND"
			when Op_or then Result := "OR"
			when Op_xor then Result := "XOR"
			when Op_not then Result := "NOT"
			when Op_eq then Result := "EQ"
			when Op_neq then Result := "NEQ"
			when Op_lt then Result := "LT"
			when Op_le then Result := "LE"
			when Op_gt then Result := "GT"
			when Op_ge then Result := "GE"
			when Op_jmp then Result := "JMP"
			when Op_jz then Result := "JZ"
			when Op_jnz then Result := "JNZ"
			when Op_call_fb then Result := "CALL_FB"
			when Op_halt then Result := "HALT"
			else
				Result := "UNKNOWN_OP"
			end
		ensure
			not_empty: not Result.is_empty
		end

end
