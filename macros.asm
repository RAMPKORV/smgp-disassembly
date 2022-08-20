txt macro text

escape = 0
i = 0
	while i<strlen(\text)
c substr 1+i,1+i,\text
	if escape=0
		; Escape character
		if "\c"="\"
escape = 1
		; Space
		elseif ("\c"=" ")
			dc.b	$32

                elseif ("\c"=".")
                        dc.b    $29

                elseif ("\c"="'")
                        dc.b    $26

                elseif ("\c"="!")
                        dc.b    $2D

                elseif ("\c"="?")
                        dc.b    $28

		; 0-9
		elseif ("\c">="0")&("\c"<="9")
			dc.b	("\c"-"0")

		; A-Z
		elseif ("\c">="A")&("\c"<="Z")
			dc.b	("\c"-"A")+$0A

		; Small "x" (large font)
		elseif ("\c"="x")
			dc.b	$4A


		endif
	else
		; Custom character
		if "\c"="n"
			dc.b	$FC
		; Invalid
		else
			inform 2,"Invalid escape character '%s'", "\c"
		endif
escape = 0
	endif
i = i+1
	endw

    dc.b $FF

	endm
