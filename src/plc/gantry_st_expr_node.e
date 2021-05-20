note
	description: "Abstract syntax tree node representing an IEC 61131-3 expression."
	author: "Aneesh Krishna"

class
	GANTRY_ST_EXPR_NODE

inherit
	GANTRY_ST_AST_NODE

create
	make_int_literal,
	make_real_literal,
	make_bool_literal,
	make_string_literal,
	make_var_ref,
	make_binary_op,
	make_unary_op,
	make_fb_call

feature {NONE} -- Initializers

	make_int_literal (a_val: INTEGER_64; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_int_lit
			int_val := a_val
			identifier := ""
			operator := ""
		ensure
			kind_set: expr_kind = Kind_int_lit
			val_set: int_val = a_val
		end

	make_real_literal (a_val: REAL_64; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_real_lit
			real_val := a_val
			identifier := ""
			operator := ""
		ensure
			kind_set: expr_kind = Kind_real_lit
			val_set: real_val = a_val
		end

	make_bool_literal (a_val: BOOLEAN; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_bool_lit
			bool_val := a_val
			identifier := ""
			operator := ""
		ensure
			kind_set: expr_kind = Kind_bool_lit
			val_set: bool_val = a_val
		end

	make_string_literal (a_val: STRING; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_string_lit
			str_val := a_val.twin
			identifier := ""
			operator := ""
		ensure
			kind_set: expr_kind = Kind_string_lit
		end

	make_var_ref (a_name: STRING; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_var_ref
			identifier := a_name.twin
			operator := ""
		ensure
			kind_set: expr_kind = Kind_var_ref
			id_set: identifier.is_equal (a_name)
		end

	make_binary_op (a_op: STRING; a_left, a_right: GANTRY_ST_EXPR_NODE; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_binary_op
			operator := a_op.twin
			left_child := a_left
			right_child := a_right
			identifier := ""
		ensure
			kind_set: expr_kind = Kind_binary_op
			op_set: operator.is_equal (a_op)
		end

	make_unary_op (a_op: STRING; a_operand: GANTRY_ST_EXPR_NODE; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_unary_op
			operator := a_op.twin
			left_child := a_operand
			identifier := ""
		ensure
			kind_set: expr_kind = Kind_unary_op
			op_set: operator.is_equal (a_op)
		end

	make_fb_call (a_fb_name: STRING; a_args: ARRAYED_LIST [GANTRY_ST_EXPR_NODE]; a_line, a_col: INTEGER)
		do
			make_node (a_line, a_col)
			expr_kind := Kind_fb_call
			identifier := a_fb_name.twin
			call_arguments := a_args
			operator := ""
		ensure
			kind_set: expr_kind = Kind_fb_call
			id_set: identifier.is_equal (a_fb_name)
		end

feature -- Classification Constants

	Kind_int_lit: INTEGER = 1
	Kind_real_lit: INTEGER = 2
	Kind_bool_lit: INTEGER = 3
	Kind_string_lit: INTEGER = 4
	Kind_var_ref: INTEGER = 5
	Kind_binary_op: INTEGER = 6
	Kind_unary_op: INTEGER = 7
	Kind_fb_call: INTEGER = 8

feature -- Access

	expr_kind: INTEGER
	int_val: INTEGER_64
	real_val: REAL_64
	bool_val: BOOLEAN
	str_val: detachable STRING
	identifier: STRING
	operator: STRING
	left_child: detachable GANTRY_ST_EXPR_NODE
	right_child: detachable GANTRY_ST_EXPR_NODE
	call_arguments: detachable ARRAYED_LIST [GANTRY_ST_EXPR_NODE]

feature -- Visualization

	to_tree_string (a_indent: INTEGER): STRING
		local
			pfx: STRING
		do
			pfx := indent_spaces (a_indent)
			inspect expr_kind
			when Kind_int_lit then
				Result := pfx + "IntLit(" + int_val.out + ")%N"
			when Kind_real_lit then
				Result := pfx + "RealLit(" + real_val.out + ")%N"
			when Kind_bool_lit then
				Result := pfx + "BoolLit(" + bool_val.out + ")%N"
			when Kind_string_lit then
				if attached str_val as s then
					Result := pfx + "StringLit('" + s + "')%N"
				else
					Result := pfx + "StringLit('')%N"
				end
			when Kind_var_ref then
				Result := pfx + "VarRef(" + identifier + ")%N"
			when Kind_binary_op then
				Result := pfx + "BinaryOp('" + operator + "')%N"
				if attached left_child as l then
					Result.append (l.to_tree_string (a_indent + 1))
				end
				if attached right_child as r then
					Result.append (r.to_tree_string (a_indent + 1))
				end
			when Kind_unary_op then
				Result := pfx + "UnaryOp('" + operator + "')%N"
				if attached left_child as opnd then
					Result.append (opnd.to_tree_string (a_indent + 1))
				end
			when Kind_fb_call then
				Result := pfx + "FBCall(" + identifier + ")%N"
				if attached call_arguments as args then
					across args as a loop
						Result.append (a.to_tree_string (a_indent + 1))
					end
				end
			else
				Result := pfx + "UnknownExpr%N"
			end
		end

invariant
	valid_kind: expr_kind >= Kind_int_lit and expr_kind <= Kind_fb_call

end
