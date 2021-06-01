note
	description: "Stack-based virtual machine executing IEC 61131-3 bytecode with step limits and process image coupling."
	author: "Aneesh Krishna"

class
	GANTRY_ST_VM

inherit
	GANTRY_ST_OPCODE

create
	make

feature {NONE} -- Initialization

	make
		do
			create stack.make (64)
			create variables.make (64)
			max_steps := 100000
			execution_steps := 0
			has_runtime_error := False
			runtime_error_message := ""
		ensure
			empty_stack: stack.is_empty
			no_error: not has_runtime_error
		end

feature -- Access

	stack: ARRAYED_STACK [REAL_64]
			-- Operand evaluation stack.

	variables: HASH_TABLE [REAL_64, STRING]
			-- Script-local holding variables.

	max_steps: INTEGER
			-- Maximum instructions permitted per cycle execution before trip.

	execution_steps: INTEGER
			-- Actual instruction step count consumed during most recent execution.

	has_runtime_error: BOOLEAN
			-- True if a runtime fault (divide by zero, stack underflow, overrun) occurred.

	runtime_error_message: STRING
			-- Diagnostic explanation of runtime fault.

feature -- Execution

	execute (a_code: ARRAYED_LIST [GANTRY_ST_INSTRUCTION]; a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64)
			-- Run bytecode sequence to completion against the given process image table.
		require
			code_attached: a_code /= Void
			table_attached: a_table /= Void
		local
			pc: INTEGER
			inst: GANTRY_ST_INSTRUCTION
			op: INTEGER
			a, b: REAL_64
			v_bool: BOOLEAN
		do
			stack.wipe_out
			execution_steps := 0
			has_runtime_error := False
			runtime_error_message := ""
			pc := 1

			from
			until
				has_runtime_error or pc > a_code.count or pc <= 0
			loop
				execution_steps := execution_steps + 1
				if execution_steps > max_steps then
					has_runtime_error := True
					runtime_error_message := "PLC step limit exceeded: infinite loop detected"
				else
					inst := a_code.i_th (pc)
					op := inst.opcode

					inspect op
					when Op_nop then
						pc := pc + 1
					when Op_halt then
						pc := a_code.count + 1 -- Exit loop
					when Op_push_int then
						stack.put (inst.int_operand.to_double)
						pc := pc + 1
					when Op_push_real then
						stack.put (inst.real_operand)
						pc := pc + 1
					when Op_push_bool then
						if inst.bool_operand then
							stack.put (1.0)
						else
							stack.put (0.0)
						end
						pc := pc + 1
					when Op_load_var then
						if a_table.digital_inputs.has (inst.string_operand) or
							a_table.digital_outputs.has (inst.string_operand) or
							a_table.memory_bits.has (inst.string_operand) then
							v_bool := a_table.read_digital (inst.string_operand)
							if v_bool then stack.put (1.0) else stack.put (0.0) end
						elseif a_table.analog_inputs.has (inst.string_operand) or
							a_table.analog_outputs.has (inst.string_operand) or
							a_table.memory_registers.has (inst.string_operand) then
							stack.put (a_table.read_analog (inst.string_operand))
						elseif variables.has (inst.string_operand) then
							stack.put (variables.item (inst.string_operand))
						else
							-- Uninitialized variable defaults to 0.0
							stack.put (0.0)
						end
						pc := pc + 1
					when Op_store_var then
						if stack.is_empty then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on STORE_VAR"
						else
							a := stack.item
							stack.remove
							if a_table.digital_outputs.has (inst.string_operand) or
								a_table.memory_bits.has (inst.string_operand) then
								a_table.write_digital (inst.string_operand, a > 0.5, a_timestamp_ms)
							elseif a_table.analog_outputs.has (inst.string_operand) or
								a_table.memory_registers.has (inst.string_operand) then
								a_table.write_analog (inst.string_operand, a, a_timestamp_ms)
							else
								variables.force (a, inst.string_operand)
							end
						end
						pc := pc + 1
					when Op_add then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on ADD"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							stack.put (a + b)
						end
						pc := pc + 1
					when Op_sub then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on SUB"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							stack.put (a - b)
						end
						pc := pc + 1
					when Op_mul then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on MUL"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							stack.put (a * b)
						end
						pc := pc + 1
					when Op_div then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on DIV"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if b.abs < 0.000000001 then
								has_runtime_error := True
								runtime_error_message := "Division by zero"
							else
								stack.put (a / b)
							end
						end
						pc := pc + 1
					when Op_mod then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on MOD"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if b.abs < 0.000000001 then
								has_runtime_error := True
								runtime_error_message := "Modulo by zero"
							else
								stack.put ((a.truncated_to_integer_64 \\ b.truncated_to_integer_64).to_double)
							end
						end
						pc := pc + 1
					when Op_neg then
						if stack.is_empty then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on NEG"
						else
							a := stack.item; stack.remove
							stack.put (-a)
						end
						pc := pc + 1
					when Op_and then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on AND"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if a > 0.5 and b > 0.5 then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_or then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on OR"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if a > 0.5 or b > 0.5 then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_xor then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on XOR"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if (a > 0.5) /= (b > 0.5) then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_not then
						if stack.is_empty then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on NOT"
						else
							a := stack.item; stack.remove
							if a > 0.5 then stack.put (0.0) else stack.put (1.0) end
						end
						pc := pc + 1
					when Op_eq then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on EQ"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if (a - b).abs < 0.000000001 then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_neq then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on NEQ"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if (a - b).abs >= 0.000000001 then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_lt then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on LT"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if a < b then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_le then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on LE"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if a <= b then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_gt then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on GT"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if a > b then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_ge then
						if stack.count < 2 then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on GE"
						else
							b := stack.item; stack.remove
							a := stack.item; stack.remove
							if a >= b then stack.put (1.0) else stack.put (0.0) end
						end
						pc := pc + 1
					when Op_jmp then
						pc := inst.jump_target
					when Op_jz then
						if stack.is_empty then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on JZ"
						else
							a := stack.item; stack.remove
							if a <= 0.5 then
								pc := inst.jump_target
							else
								pc := pc + 1
							end
						end
					when Op_jnz then
						if stack.is_empty then
							has_runtime_error := True
							runtime_error_message := "Stack underflow on JNZ"
						else
							a := stack.item; stack.remove
							if a > 0.5 then
								pc := inst.jump_target
							else
								pc := pc + 1
							end
						end
					else
						pc := pc + 1
					end
				end
			end
		end

feature -- Configuration

	set_max_steps (a_steps: INTEGER)
		require
			positive_steps: a_steps > 0
		do
			max_steps := a_steps
		ensure
			steps_set: max_steps = a_steps
		end

invariant
	stack_attached: stack /= Void
	variables_attached: variables /= Void
	positive_max_steps: max_steps > 0

end
