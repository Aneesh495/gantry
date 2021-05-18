note
	description: "Abstract base class for all IEC 61131-3 Structured Text abstract syntax tree nodes."
	author: "Aneesh Krishna"

deferred class
	GANTRY_ST_AST_NODE

feature {NONE} -- Initialization

	make_node (a_line, a_col: INTEGER)
			-- Initialize node with source location.
		require
			valid_line: a_line >= 1
			valid_col: a_col >= 1
		do
			line := a_line
			column := a_col
		ensure
			line_set: line = a_line
			column_set: column = a_col
		end

feature -- Access

	line: INTEGER
			-- Source file line where syntax element begins.

	column: INTEGER
			-- Source file column offset where syntax element begins.

feature -- Visualization

	to_tree_string (a_indent: INTEGER): STRING
			-- Structured text representation of AST node subtree for diagnostics.
		require
			indent_non_negative: a_indent >= 0
		deferred
		ensure
			not_empty: not Result.is_empty
		end

	indent_spaces (a_indent: INTEGER): STRING
			-- Helper generating indentation whitespace.
		require
			indent_non_negative: a_indent >= 0
		local
			i: INTEGER
		do
			create Result.make (a_indent * 2)
			from
				i := 1
			until
				i > a_indent * 2
			loop
				Result.append_character (' ')
				i := i + 1
			end
		end

invariant
	valid_location: line >= 1 and column >= 1

end
