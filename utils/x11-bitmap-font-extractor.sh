#!/bin/bash
zcat /usr/share/fonts/X11/misc/4x6.pcf.gz | pcf2bdf | grep -EA13 "^STARTCHAR (zero|one|two|three|four|five|six|seven|eight|nine)$" | awk --non-decimal-data \
	'BEGIN {
		digit=0; font_width=4; font_height=6; indent="        ";
		print "#define font_width " font_width ".0"
		print "#define font_height " font_height ".0"
	       	print "#define DigitBin(x) ( \\"
       	}
	/^STARTCHAR/ { character=0; printf indent "x==" digit "?" }
	/^BITMAP/ { line_number=font_height }
	/^..$/ { if (line_number > 0 ) {
		parsed = sprintf("%d", "0x" $1)
		line = 0
		for (i=0; i<8; i++) {
			bit = and(rshift(parsed, i),1)
			line = or(lshift(line,1), bit)
		}
		character = or(character, lshift(line,font_width*(line_number-1)));
		line_number = line_number-1;
       	} }
	/^ENDCHAR/ { print character ".0:\\"; digit = digit+1 }
	END { print indent "x==10?32.0:\\"; print indent "x==11?1792.0:\\"; print indent "0.0 )" }
'
#STARTCHAR nine
#ENCODING 57
#SWIDTH 640 0
#DWIDTH 4 0
#BBX 4 6 0 -1
#BITMAP
#40
#A0
#60
#20
#C0
#00
#ENDCHAR
