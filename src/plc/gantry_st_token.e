note
	description: "Lexical token representing a scanned symbol in IEC 61131-3 Structured Text."
	author: "Aneesh Krishna"

class
	GANTRY_ST_TOKEN

inherit
	GANTRY_ST_TOKEN_TYPE

create
	make

feature {NONE} -- Initialization

	make (a_type: INTEGER; a_lexeme: STRING; a_line, a_col: INTEGER)
			-- Initialize token with classification, raw text, and source coordinates.
		require
			valid_line: a_line >= 1
			valid_col: a_col >= 1
		do
			type := a_type
			lexeme := a_lexeme.twin
			line := a_line
			column := a_col
		ensure
			type_set: type = a_type
			lexeme_set: lexeme.is_equal (a_lexeme)
			line_set: line = a_line
			column_set: column = a_col
		end

feature -- Access

	type: INTEGER
			-- Token classification constant from GANTRY_ST_TOKEN_TYPE.

	lexeme: STRING
			-- Scanned source text snippet.

	line: INTEGER
			-- 1-based source line index.

	column: INTEGER
			-- 1-based source column offset.

feature -- Query

	is_type (a_expected_type: INTEGER): BOOLEAN
			-- Does this token match the specified type code?
		do
			Result := (type = a_expected_type)
		ensure
			consistent: Result = (type = a_expected_type)
		end

	to_string: STRING
			-- Diagnostic representation of token.
		do
			Result := "[" + line.out + ":" + column.out + "] " + token_name (type) + " ('" + lexeme + "')"
		ensure
			not_empty: not Result.is_empty
		end

invariant
	lexeme_attached: lexeme /= Void
	valid_coordinates: line >= 1 and column >= 1

end
