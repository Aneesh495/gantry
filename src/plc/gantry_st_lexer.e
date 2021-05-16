note
	description: "Deterministic finite automaton lexer scanning IEC 61131-3 Structured Text programs into token streams."
	author: "Aneesh Krishna"

class
	GANTRY_ST_LEXER

inherit
	GANTRY_ST_TOKEN_TYPE

create
	make

feature {NONE} -- Initialization

	make (a_source: STRING)
			-- Initialize lexer with source code buffer.
		do
			source := a_source.twin
			cursor := 1
			line := 1
			col := 1
			create tokens.make (100)
			tokenize
		ensure
			source_set: source.is_equal (a_source)
			tokens_attached: tokens /= Void
		end

feature -- Access

	source: STRING
			-- Complete source code string.

	tokens: ARRAYED_LIST [GANTRY_ST_TOKEN]
			-- Scanned array of tokens ending in Tok_eof.

feature {NONE} -- Internal State

	cursor: INTEGER
	line: INTEGER
	col: INTEGER

feature {NONE} -- Scanning Implementation

	tokenize
			-- Scan entire source buffer into tokens list.
		local
			t: GANTRY_ST_TOKEN
		do
			from
				skip_whitespace_and_comments
			until
				is_at_end
			loop
				t := scan_token
				tokens.extend (t)
				skip_whitespace_and_comments
			end

			-- Append terminating EOF token
			create t.make (Tok_eof, "", line, col)
			tokens.extend (t)
		end

	is_at_end: BOOLEAN
			-- Has cursor reached end of source buffer?
		do
			Result := (cursor > source.count)
		end

	peek: CHARACTER
			-- Current character under cursor without consuming.
		require
			not_at_end: not is_at_end
		do
			Result := source.item (cursor)
		end

	peek_next: CHARACTER
			-- Character immediately following cursor.
		do
			if cursor + 1 <= source.count then
				Result := source.item (cursor + 1)
			else
				Result := '%U'
			end
		end

	advance: CHARACTER
			-- Consume and return current character, tracking line and column.
		require
			not_at_end: not is_at_end
		do
			Result := source.item (cursor)
			cursor := cursor + 1
			if Result = '%N' then
				line := line + 1
				col := 1
			else
				col := col + 1
			end
		end

	skip_whitespace_and_comments
			-- Advance past whitespace, newlines, and IEC comments (* ... *) and // ...
		local
			done: BOOLEAN
			c: CHARACTER
		do
			from
				done := False
			until
				done or is_at_end
			loop
				c := peek
				if c = ' ' or c = '%T' or c = '%R' or c = '%N' then
					c := advance
				elseif c = '/' and peek_next = '/' then
					-- Single-line comment
					from
					until
						is_at_end or peek = '%N'
					loop
						c := advance
					end
				elseif c = '(' and peek_next = '*' then
					-- Multi-line IEC comment (* ... *)
					c := advance
					c := advance
					from
					until
						is_at_end or (peek = '*' and peek_next = ')')
					loop
						c := advance
					end
					if not is_at_end then
						c := advance -- consume '*'
						c := advance -- consume ')'
					end
				else
					done := True
				end
			end
		end

	scan_token: GANTRY_ST_TOKEN
			-- Identify and extract the next lexical token.
		require
			not_at_end: not is_at_end
		local
			start_line: INTEGER
			start_col: INTEGER
			c: CHARACTER
		do
			start_line := line
			start_col := col
			c := advance

			if is_alpha (c) or c = '_' then
				Result := scan_identifier_or_keyword (c, start_line, start_col)
			elseif is_digit (c) then
				Result := scan_number (c, start_line, start_col)
			elseif c = '%'' then
				Result := scan_string (start_line, start_col)
			elseif c = ':' and peek = '=' then
				c := advance
				create Result.make (Tok_assign, ":=", start_line, start_col)
			elseif c = '<' and peek = '>' then
				c := advance
				create Result.make (Tok_neq, "<>", start_line, start_col)
			elseif c = '<' and peek = '=' then
				c := advance
				create Result.make (Tok_le, "<=", start_line, start_col)
			elseif c = '>' and peek = '=' then
				c := advance
				create Result.make (Tok_ge, ">=", start_line, start_col)
			elseif c = '<' then
				create Result.make (Tok_lt, "<", start_line, start_col)
			elseif c = '>' then
				create Result.make (Tok_gt, ">", start_line, start_col)
			elseif c = '=' then
				create Result.make (Tok_eq, "=", start_line, start_col)
			elseif c = '+' then
				create Result.make (Tok_plus, "+", start_line, start_col)
			elseif c = '-' then
				create Result.make (Tok_minus, "-", start_line, start_col)
			elseif c = '*' then
				create Result.make (Tok_star, "*", start_line, start_col)
			elseif c = '/' then
				create Result.make (Tok_slash, "/", start_line, start_col)
			elseif c = ';' then
				create Result.make (Tok_semi, ";", start_line, start_col)
			elseif c = ':' then
				create Result.make (Tok_colon, ":", start_line, start_col)
			elseif c = ',' then
				create Result.make (Tok_comma, ",", start_line, start_col)
			elseif c = '.' then
				create Result.make (Tok_dot, ".", start_line, start_col)
			elseif c = '(' then
				create Result.make (Tok_lparen, "(", start_line, start_col)
			elseif c = ')' then
				create Result.make (Tok_rparen, ")", start_line, start_col)
			else
				create Result.make (Tok_ident, c.out, start_line, start_col)
			end
		end

	scan_identifier_or_keyword (a_first_char: CHARACTER; a_line, a_col: INTEGER): GANTRY_ST_TOKEN
			-- Accumulate alphanumeric word and classify as keyword or identifier.
		local
			buf: STRING
			upper: STRING
			ktype: INTEGER
			c: CHARACTER
		do
			create buf.make (16)
			buf.append_character (a_first_char)

			from
			until
				is_at_end or else not (is_alpha (peek) or is_digit (peek) or peek = '_')
			loop
				c := advance
				buf.append_character (c)
			end

			upper := buf.as_upper
			ktype := keyword_type (upper)
			create Result.make (ktype, buf, a_line, a_col)
		end

	keyword_type (a_upper: STRING): INTEGER
			-- Resolve uppercase token string to keyword token constant.
		do
			if a_upper.is_equal ("IF") then Result := Tok_if
			elseif a_upper.is_equal ("THEN") then Result := Tok_then
			elseif a_upper.is_equal ("ELSIF") then Result := Tok_elsif
			elseif a_upper.is_equal ("ELSE") then Result := Tok_else
			elseif a_upper.is_equal ("END_IF") then Result := Tok_end_if
			elseif a_upper.is_equal ("CASE") then Result := Tok_case
			elseif a_upper.is_equal ("OF") then Result := Tok_of
			elseif a_upper.is_equal ("END_CASE") then Result := Tok_end_case
			elseif a_upper.is_equal ("FOR") then Result := Tok_for
			elseif a_upper.is_equal ("TO") then Result := Tok_to
			elseif a_upper.is_equal ("BY") then Result := Tok_by
			elseif a_upper.is_equal ("DO") then Result := Tok_do
			elseif a_upper.is_equal ("END_FOR") then Result := Tok_end_for
			elseif a_upper.is_equal ("WHILE") then Result := Tok_while
			elseif a_upper.is_equal ("END_WHILE") then Result := Tok_end_while
			elseif a_upper.is_equal ("REPEAT") then Result := Tok_repeat
			elseif a_upper.is_equal ("UNTIL") then Result := Tok_until
			elseif a_upper.is_equal ("END_REPEAT") then Result := Tok_end_repeat
			elseif a_upper.is_equal ("VAR") then Result := Tok_var
			elseif a_upper.is_equal ("END_VAR") then Result := Tok_end_var
			elseif a_upper.is_equal ("TRUE") or a_upper.is_equal ("FALSE") then Result := Tok_bool_lit
			elseif a_upper.is_equal ("AND") then Result := Tok_and
			elseif a_upper.is_equal ("OR") then Result := Tok_or
			elseif a_upper.is_equal ("XOR") then Result := Tok_xor
			elseif a_upper.is_equal ("NOT") then Result := Tok_not
			elseif a_upper.is_equal ("MOD") then Result := Tok_mod
			else
				Result := Tok_ident
			end
		end

	scan_number (a_first_char: CHARACTER; a_line, a_col: INTEGER): GANTRY_ST_TOKEN
			-- Accumulate integer or floating-point numerical constant.
		local
			buf: STRING
			is_float: BOOLEAN
			c: CHARACTER
		do
			create buf.make (16)
			buf.append_character (a_first_char)
			is_float := False

			from
			until
				is_at_end or else not is_digit (peek)
			loop
				c := advance
				buf.append_character (c)
			end

			if not is_at_end and then peek = '.' and then is_digit (peek_next) then
				is_float := True
				c := advance -- consume '.'
				buf.append_character (c)
				from
				until
					is_at_end or else not is_digit (peek)
				loop
					c := advance
					buf.append_character (c)
				end
			end

			if is_float then
				create Result.make (Tok_real_lit, buf, a_line, a_col)
			else
				create Result.make (Tok_int_lit, buf, a_line, a_col)
			end
		end

	scan_string (a_line, a_col: INTEGER): GANTRY_ST_TOKEN
			-- Scan single-quoted literal string.
		local
			buf: STRING
			c: CHARACTER
		do
			create buf.make (32)
			from
			until
				is_at_end or peek = '%''
			loop
				c := advance
				buf.append_character (c)
			end

			if not is_at_end then
				c := advance -- consume closing quote
			end

			create Result.make (Tok_string_lit, buf, a_line, a_col)
		end

	is_alpha (c: CHARACTER): BOOLEAN
			-- Is character an ASCII letter?
		do
			Result := (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')
		end

	is_digit (c: CHARACTER): BOOLEAN
			-- Is character an ASCII digit?
		do
			Result := (c >= '0' and c <= '9')
		end

invariant
	source_attached: source /= Void
	tokens_attached: tokens /= Void
	cursor_bounds: cursor >= 1 and cursor <= source.count + 1

end
