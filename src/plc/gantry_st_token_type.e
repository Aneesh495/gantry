note
	description: "Lexical token type constants conforming to IEC 61131-3 Structured Text grammar."
	author: "Aneesh Krishna"

class
	GANTRY_ST_TOKEN_TYPE

feature -- Token Types

	Tok_eof: INTEGER = 0
	Tok_ident: INTEGER = 1
	Tok_int_lit: INTEGER = 2
	Tok_real_lit: INTEGER = 3
	Tok_bool_lit: INTEGER = 4
	Tok_string_lit: INTEGER = 5

	-- Operators
	Tok_plus: INTEGER = 10
	Tok_minus: INTEGER = 11
	Tok_star: INTEGER = 12
	Tok_slash: INTEGER = 13
	Tok_mod: INTEGER = 14

	-- Relational Operators
	Tok_eq: INTEGER = 20
	Tok_neq: INTEGER = 21
	Tok_lt: INTEGER = 22
	Tok_le: INTEGER = 23
	Tok_gt: INTEGER = 24
	Tok_ge: INTEGER = 25

	-- Logical Operators
	Tok_and: INTEGER = 30
	Tok_or: INTEGER = 31
	Tok_xor: INTEGER = 32
	Tok_not: INTEGER = 33

	-- Assignment and Punctuation
	Tok_assign: INTEGER = 40        -- :=
	Tok_semi: INTEGER = 41          -- ;
	Tok_colon: INTEGER = 42         -- :
	Tok_comma: INTEGER = 43         -- ,
	Tok_dot: INTEGER = 44           -- .
	Tok_lparen: INTEGER = 45        -- (
	Tok_rparen: INTEGER = 46        -- )

	-- Keywords
	Tok_if: INTEGER = 50
	Tok_then: INTEGER = 51
	Tok_elsif: INTEGER = 52
	Tok_else: INTEGER = 53
	Tok_end_if: INTEGER = 54
	Tok_case: INTEGER = 55
	Tok_of: INTEGER = 56
	Tok_end_case: INTEGER = 57
	Tok_for: INTEGER = 58
	Tok_to: INTEGER = 59
	Tok_by: INTEGER = 60
	Tok_do: INTEGER = 61
	Tok_end_for: INTEGER = 62
	Tok_while: INTEGER = 63
	Tok_end_while: INTEGER = 64
	Tok_repeat: INTEGER = 65
	Tok_until: INTEGER = 66
	Tok_end_repeat: INTEGER = 67
	Tok_var: INTEGER = 68
	Tok_end_var: INTEGER = 69

feature -- Diagnostics

	token_name (a_type: INTEGER): STRING
			-- Human-readable mnemonic for given token type.
		do
			inspect a_type
			when Tok_eof then Result := "EOF"
			when Tok_ident then Result := "IDENT"
			when Tok_int_lit then Result := "INT_LIT"
			when Tok_real_lit then Result := "REAL_LIT"
			when Tok_bool_lit then Result := "BOOL_LIT"
			when Tok_string_lit then Result := "STRING_LIT"
			when Tok_plus then Result := "+"
			when Tok_minus then Result := "-"
			when Tok_star then Result := "*"
			when Tok_slash then Result := "/"
			when Tok_mod then Result := "MOD"
			when Tok_eq then Result := "="
			when Tok_neq then Result := "<>"
			when Tok_lt then Result := "<"
			when Tok_le then Result := "<="
			when Tok_gt then Result := ">"
			when Tok_ge then Result := ">="
			when Tok_and then Result := "AND"
			when Tok_or then Result := "OR"
			when Tok_xor then Result := "XOR"
			when Tok_not then Result := "NOT"
			when Tok_assign then Result := ":="
			when Tok_semi then Result := ";"
			when Tok_colon then Result := ":"
			when Tok_comma then Result := ","
			when Tok_dot then Result := "."
			when Tok_lparen then Result := "("
			when Tok_rparen then Result := ")"
			when Tok_if then Result := "IF"
			when Tok_then then Result := "THEN"
			when Tok_elsif then Result := "ELSIF"
			when Tok_else then Result := "ELSE"
			when Tok_end_if then Result := "END_IF"
			when Tok_for then Result := "FOR"
			when Tok_to then Result := "TO"
			when Tok_by then Result := "BY"
			when Tok_do then Result := "DO"
			when Tok_end_for then Result := "END_FOR"
			when Tok_while then Result := "WHILE"
			when Tok_end_while then Result := "END_WHILE"
			when Tok_repeat then Result := "REPEAT"
			when Tok_until then Result := "UNTIL"
			when Tok_end_repeat then Result := "END_REPEAT"
			else
				Result := "UNKNOWN_TOKEN"
			end
		ensure
			name_not_empty: not Result.is_empty
		end

end
