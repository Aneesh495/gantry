note
	description: "Compiles IEC 61131-3 Structured Text AST statements into flat linear bytecode."
	author: "Aneesh Krishna"

class
	GANTRY_ST_COMPILER

inherit
	GANTRY_ST_OPCODE

create
	make

feature {NONE} -- Initialization

	make
		do
			create instructions.make (50)
		ensure
			empty_code: instructions.is_empty
		end

feature -- Access

	instructions: ARRAYED_LIST [GANTRY_ST_INSTRUCTION]
			-- Linear compiled bytecode array.

feature -- Compilation

	compile_program (a_statements: ARRAYED_LIST [GANTRY_ST_STMT_NODE])
			-- Compile full AST statement list into bytecode ending with Op_halt.
		require
			stmts_attached: a_statements /= Void
		local
			halt_inst: GANTRY_ST_INSTRUCTION
		do
			instructions.wipe_out
			across a_statements as s loop
				compile_statement (s)
			end
			create halt_inst.make_simple (Op_halt)
			instructions.extend (halt_inst)
		ensure
			not_empty: not instructions.is_empty
			ends_in_halt: instructions.last.opcode = Op_halt
		end

feature {NONE} -- Statement Compilers

	compile_statement (a_stmt: GANTRY_ST_STMT_NODE)
		do
			inspect a_stmt.stmt_kind
			when 1 then -- Kind_assignment
				compile_expression (a_stmt.primary_expr)
				emit_store (a_stmt.target_variable)
			when 2 then -- Kind_if_stmt
				compile_if_statement (a_stmt)
			when 3 then -- Kind_while_stmt
				compile_while_statement (a_stmt)
			when 4 then -- Kind_for_stmt
				compile_for_statement (a_stmt)
			when 5 then -- Kind_repeat_stmt
				compile_repeat_statement (a_stmt)
			when 6 then -- Kind_fb_call_stmt
				emit_call_fb (a_stmt.target_variable)
			else
			end
		end

	compile_if_statement (a_stmt: GANTRY_ST_STMT_NODE)
		local
			jz_index, jmp_index: INTEGER
			jz_inst, jmp_inst: GANTRY_ST_INSTRUCTION
		do
			-- 1. Evaluate condition
			compile_expression (a_stmt.primary_expr)

			-- 2. Emit conditional jump to else branch (placeholder target 0)
			create jz_inst.make_with_jump (Op_jz, 0)
			instructions.extend (jz_inst)
			jz_index := instructions.count

			-- 3. Compile THEN statements
			across a_stmt.body_statements as s loop
				compile_statement (s)
			end

			if not a_stmt.else_statements.is_empty then
				-- Emit unconditional jump past else block
				create jmp_inst.make_with_jump (Op_jmp, 0)
				instructions.extend (jmp_inst)
				jmp_index := instructions.count

				-- Patch JZ to jump to start of else block
				instructions.i_th (jz_index).set_jump_target (instructions.count + 1)

				-- Compile ELSE statements
				across a_stmt.else_statements as s loop
					compile_statement (s)
				end

				-- Patch JMP to jump to instruction after else block
				instructions.i_th (jmp_index).set_jump_target (instructions.count + 1)
			else
				-- No else branch; patch JZ to instruction after then block
				instructions.i_th (jz_index).set_jump_target (instructions.count + 1)
			end
		end

	compile_while_statement (a_stmt: GANTRY_ST_STMT_NODE)
		local
			loop_start_index, jz_index: INTEGER
			jz_inst, jmp_inst: GANTRY_ST_INSTRUCTION
		do
			loop_start_index := instructions.count + 1

			-- 1. Evaluate loop condition
			compile_expression (a_stmt.primary_expr)

			-- 2. Emit JZ to jump out of loop if condition False
			create jz_inst.make_with_jump (Op_jz, 0)
			instructions.extend (jz_inst)
			jz_index := instructions.count

			-- 3. Compile body statements
			across a_stmt.body_statements as s loop
				compile_statement (s)
			end

			-- 4. Emit JMP back to condition evaluation
			create jmp_inst.make_with_jump (Op_jmp, loop_start_index)
			instructions.extend (jmp_inst)

			-- 5. Patch JZ target to first instruction after loop
			instructions.i_th (jz_index).set_jump_target (instructions.count + 1)
		end

	compile_for_statement (a_stmt: GANTRY_ST_STMT_NODE)
		local
			loop_start_index, jz_index: INTEGER
			jz_inst, jmp_inst: GANTRY_ST_INSTRUCTION
		do
			-- 1. Initialize loop counter variable
			compile_expression (a_stmt.primary_expr)
			emit_store (a_stmt.target_variable)

			loop_start_index := instructions.count + 1

			-- 2. Check upper boundary: var <= end_expr
			emit_load (a_stmt.target_variable)
			if attached a_stmt.for_end_expr as end_e then
				compile_expression (end_e)
			end
			emit_simple (Op_le)

			-- 3. Emit JZ to exit loop
			create jz_inst.make_with_jump (Op_jz, 0)
			instructions.extend (jz_inst)
			jz_index := instructions.count

			-- 4. Compile body
			across a_stmt.body_statements as s loop
				compile_statement (s)
			end

			-- 5. Step increment: var := var + step
			emit_load (a_stmt.target_variable)
			if attached a_stmt.for_step_expr as step_e then
				compile_expression (step_e)
			else
				emit_push_int (1)
			end
			emit_simple (Op_add)
			emit_store (a_stmt.target_variable)

			-- 6. Loop jump back to header
			create jmp_inst.make_with_jump (Op_jmp, loop_start_index)
			instructions.extend (jmp_inst)

			-- 7. Patch JZ target
			instructions.i_th (jz_index).set_jump_target (instructions.count + 1)
		end

	compile_repeat_statement (a_stmt: GANTRY_ST_STMT_NODE)
		local
			loop_start_index: INTEGER
			jz_inst: GANTRY_ST_INSTRUCTION
		do
			loop_start_index := instructions.count + 1

			-- 1. Compile body statements first
			across a_stmt.body_statements as s loop
				compile_statement (s)
			end

			-- 2. Evaluate termination condition
			compile_expression (a_stmt.primary_expr)

			-- 3. JZ repeats loop if condition is False
			create jz_inst.make_with_jump (Op_jz, loop_start_index)
			instructions.extend (jz_inst)
		end

feature {NONE} -- Expression Compilers

	compile_expression (a_expr: GANTRY_ST_EXPR_NODE)
		do
			inspect a_expr.expr_kind
			when 1 then -- Kind_int_lit
				emit_push_int (a_expr.int_val)
			when 2 then -- Kind_real_lit
				emit_push_real (a_expr.real_val)
			when 3 then -- Kind_bool_lit
				emit_push_bool (a_expr.bool_val)
			when 5 then -- Kind_var_ref
				emit_load (a_expr.identifier)
			when 6 then -- Kind_binary_op
				if attached a_expr.left_child as l and attached a_expr.right_child as r then
					compile_expression (l)
					compile_expression (r)
					emit_binary_operator (a_expr.operator)
				end
			when 7 then -- Kind_unary_op
				if attached a_expr.left_child as opnd then
					compile_expression (opnd)
					emit_unary_operator (a_expr.operator)
				end
			when 8 then -- Kind_fb_call
				emit_call_fb (a_expr.identifier)
			else
			end
		end

	emit_binary_operator (a_op: STRING)
		do
			if a_op.is_equal ("+") then emit_simple (Op_add)
			elseif a_op.is_equal ("-") then emit_simple (Op_sub)
			elseif a_op.is_equal ("*") then emit_simple (Op_mul)
			elseif a_op.is_equal ("/") then emit_simple (Op_div)
			elseif a_op.is_equal ("MOD") then emit_simple (Op_mod)
			elseif a_op.is_equal ("AND") then emit_simple (Op_and)
			elseif a_op.is_equal ("OR") then emit_simple (Op_or)
			elseif a_op.is_equal ("XOR") then emit_simple (Op_xor)
			elseif a_op.is_equal ("=") then emit_simple (Op_eq)
			elseif a_op.is_equal ("<>") then emit_simple (Op_neq)
			elseif a_op.is_equal ("<") then emit_simple (Op_lt)
			elseif a_op.is_equal ("<=") then emit_simple (Op_le)
			elseif a_op.is_equal (">") then emit_simple (Op_gt)
			elseif a_op.is_equal (">=") then emit_simple (Op_ge)
			end
		end

	emit_unary_operator (a_op: STRING)
		do
			if a_op.is_equal ("NOT") then
				emit_simple (Op_not)
			elseif a_op.is_equal ("-") then
				emit_simple (Op_neg)
			end
		end

feature {NONE} -- Emitter Helpers

	emit_simple (a_op: INTEGER)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_simple (a_op)
			instructions.extend (inst)
		end

	emit_push_int (a_val: INTEGER_64)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_with_int (Op_push_int, a_val)
			instructions.extend (inst)
		end

	emit_push_real (a_val: REAL_64)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_with_real (Op_push_real, a_val)
			instructions.extend (inst)
		end

	emit_push_bool (a_val: BOOLEAN)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_with_bool (Op_push_bool, a_val)
			instructions.extend (inst)
		end

	emit_load (a_var: STRING)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_with_string (Op_load_var, a_var)
			instructions.extend (inst)
		end

	emit_store (a_var: STRING)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_with_string (Op_store_var, a_var)
			instructions.extend (inst)
		end

	emit_call_fb (a_fb: STRING)
		local
			inst: GANTRY_ST_INSTRUCTION
		do
			create inst.make_with_string (Op_call_fb, a_fb)
			instructions.extend (inst)
		end

invariant
	code_attached: instructions /= Void

end
