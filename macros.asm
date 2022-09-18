txt macro
escape = 0
i = 0
	while i<strlen(\1)
c substr 1+i,1+i,\1
	if escape=0
		if "\c"="\"
escape = 1
		elseif ("\c"="'")
				dc.b    $26
		elseif ("\c"='"')
				dc.b    $27
		elseif ("\c"="?")
				dc.b    $2E
		elseif ("\c"=".")
				dc.b    $29
		elseif ("\c"=",")
				dc.b    $2A
		elseif ("\c"="/")
				dc.b    $2B
		elseif ("\c"="-")
				dc.b    $2C
		elseif ("\c"="!")
				dc.b    $2D
		elseif ("\c"=" ")
			dc.b	$32
		elseif ("\c"="(")
			dc.b	$34
		elseif ("\c"=")")
			dc.b	$35
		elseif ("\c">="0")&("\c"<="9")
			dc.b	("\c"-"0")
		elseif ("\c">="A")&("\c"<="Z")
			dc.b	("\c"-"A")+$0A
		endif
	else
		; newline
		if "\c"="n"
			dc.b	$FC
		else
			inform 2,"Invalid escape character '%s'", "\c"
		endif
escape = 0
	endif
i = i+1
	endw
    rept narg-1
		shift
		dc.b \1
	endr
	endm
