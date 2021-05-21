note
	description: "Abstract syntax tree node representing an IEC 61131-3 Structured Text statement."
	author: "Aneesh Krishna"

class
	GANTRY_ST_STMT_NODE

inherit
	GANTRY_ST_AST_NODE

create
	make_assignment,
	make_if_stmt,
	make_while_stmt,
	make_for_stmt,
	make_repeat_stmt,
	make_fb_call_stmt

feature {NONE} -- Initializers

	make_assignment (a_var_name: STRING; a_expr: GANTRY_ST_EXPR_NODE; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			stmt_kind := Kind_assignment
			target_variable := a_var_name.twin
			primary_expr := a_expr
			create body_statements.make (5)
			create else_statements.make (5)
		ensure
			kind_set: stmt_kind = Kind_assignment
			target_set: target_variable.is_equal (a_var_name)
		end

	make_if_stmt (a_cond: GANTRY_ST_EXPR_NODE; a_then_stmts: ARRAYED_LIST [GANTRY_ST_STMT_NODE];
			a_else_stmts: ARRAYED_LIST [GANTRY_ST_STMT_NODE]; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			stmt_kind := Kind_if_stmt
			target_variable := ""
			primary_expr := a_cond
			body_statements := a_then_stmts
			else_statements := a_else_stmts
		ensure
			kind_set: stmt_kind = Kind_if_stmt
		end

	make_while_stmt (a_cond: GANTRY_ST_EXPR_NODE; a_body: ARRAYED_LIST [GANTRY_ST_STMT_NODE]; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			stmt_kind := Kind_while_stmt
			target_variable := ""
			primary_expr := a_cond
			body_statements := a_body
			create else_statements.make (0)
		ensure
			kind_set: stmt_kind = Kind_while_stmt
		end

	make_for_stmt (a_var: STRING; a_start, a_end, a_step: GANTRY_ST_EXPR_NODE;
			a_body: ARRAYED_LIST [GANTRY_ST_STMT_NODE]; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			stmt_kind := Kind_for_stmt
			target_variable := a_var.twin
			primary_expr := a_start
			for_end_expr := a_end
			for_step_expr := a_step
			body_statements := a_body
			create else_statements.make (0)
		ensure
			kind_set: stmt_kind = Kind_for_stmt
		end

	make_repeat_stmt (a_cond: GANTRY_ST_EXPR_NODE; a_body: ARRAYED_LIST [GANTRY_ST_STMT_NODE]; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			stmt_kind := Kind_repeat_stmt
			target_variable := ""
			primary_expr := a_cond
			body_statements := a_body
			create else_statements.make (0)
		ensure
			kind_set: stmt_kind = Kind_repeat_stmt
		end

	make_fb_call_stmt (a_fb_name: STRING; a_args: ARRAYED_LIST [GANTRY_ST_EXPR_NODE]; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			stmt_kind := Kind_fb_call_stmt
			target_variable := a_fb_name.twin
			create primary_expr.make_fb_call (a_fb_name, a_args, a_line, a_col)
			create body_statements.make (0)
			create else_statements.make (0)
		ensure
			kind_set: stmt_kind = Kind_fb_call_stmt
		end

feature -- Classification Constants

	Kind_assignment: INTEGER = 1
	Kind_if_stmt: INTEGER = 2
	Kind_while_stmt: INTEGER = 3
	Kind_for_stmt: INTEGER = 4
	Kind_repeat_stmt: INTEGER = 5
	Kind_fb_call_stmt: INTEGER = 6

feature -- Access

	stmt_kind: INTEGER
	target_variable: STRING
	primary_expr: GANTRY_ST_EXPR_NODE
	for_end_expr: detachable GANTRY_ST_EXPR_NODE
	for_step_expr: detachable GANTRY_ST_EXPR_NODE
	body_statements: ARRAYED_LIST [GANTRY_ST_STMT_NODE]
	else_statements: ARRAYED_LIST [GANTRY_ST_STMT_NODE]

feature -- Visualization

	to_tree_string (a_indent: INTEGER): STRING
		local
			pfx: STRING
		do
			pfx := indent_spaces (a_indent)
			inspect stmt_kind
			when Kind_assignment then
				Result := pfx + "AssignStmt(" + target_variable + " :=)%N"
				Result.append (primary_expr.to_tree_string (a_indent + 1))
			when Kind_if_stmt then
				Result := pfx + "IfStmt%N"
				Result.append (pfx + "  Condition:%N")
				Result.append (primary_expr.to_tree_string (a_indent + 2))
				Result.append (pfx + "  Then:%N")
				across body_statements as s loop
					Result.append (s.to_tree_string (a_indent + 2))
				end
				if not else_statements.is_empty then
					Result.append (pfx + "  Else:%N")
					across else_statements as s loop
						Result.append (s.to_tree_string (a_indent + 2))
					end
				end
			when Kind_while_stmt then
				Result := pfx + "WhileStmt%N"
				Result.append (pfx + "  Condition:%N")
				Result.append (primary_expr.to_tree_string (a_indent + 2))
				Result.append (pfx + "  Body:%N")
				across body_statements as s loop
					Result.append (s.to_tree_string (a_indent + 2))
				end
			when Kind_for_stmt then
				Result := pfx + "ForStmt(" + target_variable + ")%N"
				across body_statements as s loop
					Result.append (s.to_tree_string (a_indent + 1))
				end
			when Kind_repeat_stmt then
				Result := pfx + "RepeatStmt%N"
				across body_statements as s loop
					Result.append (s.to_tree_string (a_indent + 1))
				end
			when Kind_fb_call_stmt then
				Result := pfx + "FBCallStmt(" + target_variable + ")%N"
			else
				Result := pfx + "UnknownStmt%N"
			end
		end

invariant
	valid_kind: stmt_kind >= Kind_assignment and stmt_kind <= Kind_fb_call_stmt
	body_attached: body_statements /= Void
	else_attached: else_statements /= Void

end
