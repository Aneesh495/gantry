note
	description: "Recursive-descent and operator-precedence parser constructing ASTs from tokenized IEC 61131-3 Structured Text."
	author: "Aneesh Krishna"

class
	GANTRY_ST_PARSER

inherit
	GANTRY_ST_TOKEN_TYPE

create
	make

feature {NONE} -- Initialization

	make (a_tokens: ARRAYED_LIST [GANTRY_ST_TOKEN])
			-- Initialize parser with token stream.
		require
			tokens_attached: a_tokens /= Void
			not_empty: not a_tokens.is_empty
		do
			tokens := a_tokens
			cursor := 1
			has_error := False
			error_message := ""
			create statements.make (20)
			parse_program
		ensure
			tokens_set: tokens = a_tokens
			statements_attached: statements /= Void
		end

feature -- Access

	tokens: ARRAYED_LIST [GANTRY_ST_TOKEN]
			-- Input stream of tokens.

	statements: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
			-- Parsed root statement list.

	has_error: BOOLEAN
			-- True if syntax error was encountered during parse.

	error_message: STRING
			-- Diagnostic explanation of syntax error.

feature {NONE} -- Parser State

	cursor: INTEGER

	peek: GANTRY_ST_TOKEN
		do
			if cursor <= tokens.count then
				Result := tokens.i_th (cursor)
			else
				Result := tokens.last
			end
		end

	consume
		do
			if cursor < tokens.count then
				cursor := cursor + 1
			end
		end

	advance: GANTRY_ST_TOKEN
		do
			Result := peek
			consume
		end

	match (a_type: INTEGER): BOOLEAN
		do
			if peek.type = a_type then
				consume
				Result := True
			else
				Result := False
			end
		end

	expect_token (a_type: INTEGER; a_context: STRING)
		do
			if peek.type = a_type then
				consume
			else
				has_error := True
				error_message := "Syntax error at " + peek.to_string + ": expected " + token_name (a_type) + " in " + a_context
			end
		end

	expect (a_type: INTEGER; a_context: STRING): GANTRY_ST_TOKEN
		do
			if peek.type = a_type then
				Result := advance
			else
				has_error := True
				error_message := "Syntax error at " + peek.to_string + ": expected " + token_name (a_type) + " in " + a_context
				Result := peek
			end
		end

feature {NONE} -- Program and Statements

	parse_program
		local
			stmt: detachable GANTRY_ST_STMT_NODE
		do
			from
			until
				has_error or peek.type = Tok_eof
			loop
				stmt := parse_statement
				if attached stmt as s then
					statements.extend (s)
				end
			end
		end

	parse_statement: detachable GANTRY_ST_STMT_NODE
		local
			tok: GANTRY_ST_TOKEN
		do
			tok := peek
			inspect tok.type
			when Tok_if then
				Result := parse_if_statement
			when Tok_while then
				Result := parse_while_statement
			when Tok_for then
				Result := parse_for_statement
			when Tok_repeat then
				Result := parse_repeat_statement
			when Tok_ident then
				Result := parse_assignment_or_call
			when Tok_semi then
				consume -- Empty statement
			else
				has_error := True
				error_message := "Unexpected token at statement start: " + tok.to_string
			end
		end

	parse_assignment_or_call: detachable GANTRY_ST_STMT_NODE
		local
			id_tok: GANTRY_ST_TOKEN
			expr: detachable GANTRY_ST_EXPR_NODE
			args: ARRAYED_LIST [GANTRY_ST_EXPR_NODE]
		do
			id_tok := advance -- Consume identifier

			if match (Tok_assign) then
				-- Assignment statement
				expr := parse_expression
				if attached expr as e then
					create Result.make_assignment (id_tok.lexeme, e, id_tok.line, id_tok.column)
					expect_token (Tok_semi, "assignment statement")
				end
			elseif match (Tok_lparen) then
				-- Function block call statement
				create args.make (4)
				if peek.type /= Tok_rparen then
					from
					until
						has_error or peek.type = Tok_rparen
					loop
						expr := parse_expression
						if attached expr as e then
							args.extend (e)
						end
						if peek.type = Tok_comma then
							consume
						end
					end
				end
				expect_token (Tok_rparen, "function block call arguments")
				expect_token (Tok_semi, "function block call statement")
				create Result.make_fb_call_stmt (id_tok.lexeme, args, id_tok.line, id_tok.column)
			else
				has_error := True
				error_message := "Expected ':=' or '(' after identifier: " + id_tok.to_string
			end
		end

	parse_if_statement: detachable GANTRY_ST_STMT_NODE
		local
			start_tok: GANTRY_ST_TOKEN
			cond: detachable GANTRY_ST_EXPR_NODE
			then_stmts: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
			else_stmts: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
			sub_stmt: detachable GANTRY_ST_STMT_NODE
		do
			start_tok := advance -- Consume IF
			cond := parse_expression
			expect_token (Tok_then, "IF condition")

			create then_stmts.make (5)
			from
			until
				has_error or peek.type = Tok_elsif or peek.type = Tok_else or peek.type = Tok_end_if or peek.type = Tok_eof
			loop
				sub_stmt := parse_statement
				if attached sub_stmt as s then
					then_stmts.extend (s)
				end
			end

			create else_stmts.make (5)
			if match (Tok_else) then
				from
				until
					has_error or peek.type = Tok_end_if or peek.type = Tok_eof
				loop
					sub_stmt := parse_statement
					if attached sub_stmt as s then
						else_stmts.extend (s)
					end
				end
			end

			expect_token (Tok_end_if, "IF block closure")
			expect_token (Tok_semi, "END_IF termination")

			if attached cond as c then
				create Result.make_if_stmt (c, then_stmts, else_stmts, start_tok.line, start_tok.column)
			end
		end

	parse_while_statement: detachable GANTRY_ST_STMT_NODE
		local
			start_tok: GANTRY_ST_TOKEN
			cond: detachable GANTRY_ST_EXPR_NODE
			body: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
			sub_stmt: detachable GANTRY_ST_STMT_NODE
		do
			start_tok := advance -- Consume WHILE
			cond := parse_expression
			expect_token (Tok_do, "WHILE condition")

			create body.make (5)
			from
			until
				has_error or peek.type = Tok_end_while or peek.type = Tok_eof
			loop
				sub_stmt := parse_statement
				if attached sub_stmt as s then
					body.extend (s)
				end
			end

			expect_token (Tok_end_while, "WHILE block closure")
			expect_token (Tok_semi, "END_WHILE termination")

			if attached cond as c then
				create Result.make_while_stmt (c, body, start_tok.line, start_tok.column)
			end
		end

	parse_for_statement: detachable GANTRY_ST_STMT_NODE
		local
			start_tok: GANTRY_ST_TOKEN
			var_tok: GANTRY_ST_TOKEN
			start_expr, end_expr, step_expr: detachable GANTRY_ST_EXPR_NODE
			body: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
			sub_stmt: detachable GANTRY_ST_STMT_NODE
		do
			start_tok := advance -- Consume FOR
			var_tok := expect (Tok_ident, "FOR iteration variable")
			expect_token (Tok_assign, "FOR initial assignment")
			start_expr := parse_expression
			expect_token (Tok_to, "FOR upper boundary")
			end_expr := parse_expression

			if match (Tok_by) then
				step_expr := parse_expression
			else
				create step_expr.make_int_literal (1, start_tok.line, start_tok.column)
			end

			expect_token (Tok_do, "FOR header")

			create body.make (5)
			from
			until
				has_error or peek.type = Tok_end_for or peek.type = Tok_eof
			loop
				sub_stmt := parse_statement
				if attached sub_stmt as s then
					body.extend (s)
				end
			end

			expect_token (Tok_end_for, "FOR block closure")
			expect_token (Tok_semi, "END_FOR termination")

			if attached start_expr as s and attached end_expr as e and attached step_expr as stp then
				create Result.make_for_stmt (var_tok.lexeme, s, e, stp, body, start_tok.line, start_tok.column)
			end
		end

	parse_repeat_statement: detachable GANTRY_ST_STMT_NODE
		local
			start_tok: GANTRY_ST_TOKEN
			cond: detachable GANTRY_ST_EXPR_NODE
			body: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
			sub_stmt: detachable GANTRY_ST_STMT_NODE
		do
			start_tok := advance -- Consume REPEAT

			create body.make (5)
			from
			until
				has_error or peek.type = Tok_until or peek.type = Tok_eof
			loop
				sub_stmt := parse_statement
				if attached sub_stmt as s then
					body.extend (s)
				end
			end

			expect_token (Tok_until, "REPEAT loop condition")
			cond := parse_expression
			expect_token (Tok_end_repeat, "REPEAT block closure")
			expect_token (Tok_semi, "END_REPEAT termination")

			if attached cond as c then
				create Result.make_repeat_stmt (c, body, start_tok.line, start_tok.column)
			end
		end

feature {NONE} -- Expressions

	parse_expression: detachable GANTRY_ST_EXPR_NODE
		do
			Result := parse_logical_or
		end

	parse_logical_or: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
		do
			left := parse_logical_xor
			from
			until
				has_error or else (peek.type /= Tok_or)
			loop
				tok := advance
				right := parse_logical_xor
				if attached left as l and attached right as r then
					create left.make_binary_op ("OR", l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_logical_xor: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
		do
			left := parse_logical_and
			from
			until
				has_error or else (peek.type /= Tok_xor)
			loop
				tok := advance
				right := parse_logical_and
				if attached left as l and attached right as r then
					create left.make_binary_op ("XOR", l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_logical_and: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
		do
			left := parse_equality
			from
			until
				has_error or else (peek.type /= Tok_and)
			loop
				tok := advance
				right := parse_equality
				if attached left as l and attached right as r then
					create left.make_binary_op ("AND", l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_equality: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
			op_str: STRING
		do
			left := parse_relational
			from
			until
				has_error or else (peek.type /= Tok_eq and peek.type /= Tok_neq)
			loop
				tok := advance
				if tok.type = Tok_eq then op_str := "=" else op_str := "<>" end
				right := parse_relational
				if attached left as l and attached right as r then
					create left.make_binary_op (op_str, l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_relational: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
			op_str: STRING
		do
			left := parse_additive
			from
			until
				has_error or else (peek.type /= Tok_lt and peek.type /= Tok_le and
					peek.type /= Tok_gt and peek.type /= Tok_ge)
			loop
				tok := advance
				inspect tok.type
				when Tok_lt then op_str := "<"
				when Tok_le then op_str := "<="
				when Tok_gt then op_str := ">"
				when Tok_ge then op_str := ">="
				else op_str := ""
				end
				right := parse_additive
				if attached left as l and attached right as r then
					create left.make_binary_op (op_str, l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_additive: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
			op_str: STRING
		do
			left := parse_multiplicative
			from
			until
				has_error or else (peek.type /= Tok_plus and peek.type /= Tok_minus)
			loop
				tok := advance
				if tok.type = Tok_plus then op_str := "+" else op_str := "-" end
				right := parse_multiplicative
				if attached left as l and attached right as r then
					create left.make_binary_op (op_str, l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_multiplicative: detachable GANTRY_ST_EXPR_NODE
		local
			left, right: detachable GANTRY_ST_EXPR_NODE
			tok: GANTRY_ST_TOKEN
			op_str: STRING
		do
			left := parse_unary
			from
			until
				has_error or else (peek.type /= Tok_star and peek.type /= Tok_slash and peek.type /= Tok_mod)
			loop
				tok := advance
				inspect tok.type
				when Tok_star then op_str := "*"
				when Tok_slash then op_str := "/"
				when Tok_mod then op_str := "MOD"
				else op_str := ""
				end
				right := parse_unary
				if attached left as l and attached right as r then
					create left.make_binary_op (op_str, l, r, tok.line, tok.column)
				end
			end
			Result := left
		end

	parse_unary: detachable GANTRY_ST_EXPR_NODE
		local
			tok: GANTRY_ST_TOKEN
			opnd: detachable GANTRY_ST_EXPR_NODE
		do
			if peek.type = Tok_not or peek.type = Tok_minus then
				tok := advance
				opnd := parse_unary
				if attached opnd as o then
					if tok.type = Tok_not then
						create Result.make_unary_op ("NOT", o, tok.line, tok.column)
					else
						create Result.make_unary_op ("-", o, tok.line, tok.column)
					end
				end
			else
				Result := parse_primary
			end
		end

	parse_primary: detachable GANTRY_ST_EXPR_NODE
		local
			tok: GANTRY_ST_TOKEN
			expr: detachable GANTRY_ST_EXPR_NODE
		do
			tok := advance
			inspect tok.type
			when Tok_int_lit then
				create Result.make_int_literal (tok.lexeme.to_integer_64, tok.line, tok.column)
			when Tok_real_lit then
				create Result.make_real_literal (tok.lexeme.to_double, tok.line, tok.column)
			when Tok_bool_lit then
				create Result.make_bool_literal (tok.lexeme.as_upper.is_equal ("TRUE"), tok.line, tok.column)
			when Tok_string_lit then
				create Result.make_string_literal (tok.lexeme, tok.line, tok.column)
			when Tok_ident then
				create Result.make_var_ref (tok.lexeme, tok.line, tok.column)
			when Tok_lparen then
				expr := parse_expression
				expect_token (Tok_rparen, "parenthesized expression")
				Result := expr
			else
				has_error := True
				error_message := "Unexpected primary token: " + tok.to_string
			end
		end

invariant
	tokens_attached: tokens /= Void
	statements_attached: statements /= Void

end
