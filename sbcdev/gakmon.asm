
				.org $600

cout 		= $ffd2
rdkey		= $fff1

DPL			=	$20
DPH			=	$21
t1      = $22

cr 			= $0d
CR			= $0d
lf 			= $0a
sp 			= $20
esc 		= $1b
endl		= $00

					jsr crout 
					jsr crout

					jsr putstri
					.byte "This is is a test",cr,lf,"Do you know what I mean?",cr,lf,endl
					lda #<Help
					ldy #>Help
					jsr PrintString

					rts	


crout:		pha	
					lda #$0d
					jsr cout 
					lda #$0a
					jsr cout 
					pla
					rts

;Put the string following in-line until a NULL out to the console
putstri: 	pla											; Get the low part of "return" address
                  								; (data start address)
        	sta     DPL
        	pla
        	sta     DPH             ; Get the high part of "return" address
                                	; (data start address)
        ; Note: actually we're pointing one short
PSINB:   	ldy     #1
        	lda     (DPL),y         ; Get the next string character
        	inc     DPL             ; update the pointer
        	bne     PSICHO          ; if not, we're pointing to next character
        	inc     DPH             ; account for page crossing
PSICHO:  	ora     #0              ; Set flags according to contents of
                                	;    Accumulator
       		beq     PSIX1           ; don't print the final NULL
        	jsr     cout         		; write it out
        	jmp     PSINB           ; back around
PSIX1:   	inc     DPL             ;
        	bne     PSIX2           ;
        	inc     DPH             ; account for page crossing
PSIX2:   	jmp     (DPL)           ; return to byte following final NULL

Help:
        .byte "Breakpoint  B <n or ?> <address>", CR
        .byte "Copy        C <start> <end> <dest>", CR
        .byte "Dump        D <start>", CR
        .byte "Fill        F <start> <end> <data>...", CR
        .byte "Go          G <address>", CR
        .byte "Hex to dec  H <address>", CR
        .byte "Checksum    K <start> <end>",CR
        .byte "Clr screen  L", CR
        .byte "Info        N", CR
        .byte "Options     O", CR
        .byte "Registers   R", CR
        .byte "Search      S <start> <end> <data>...", CR
        .byte "Test        T <start> <end>", CR
        .byte "Unassemble  U <start>", CR
        .byte "Verify      V <start> <end> <dest>", CR
        .byte "Monitor     $", CR
        .byte "Write       : <address> <data>...", CR
        .byte "Math        = <address> +/- <address>", CR
        .byte "Trace       .", CR
        .byte "Help        ?", CR
        .byte 0

WelcomeMessage:
        .byte CR,"JMON Monitor 1.3.3 by Jeff Tranter", CR, 0

PrintString:
				pha
				tya
				pha
				stx t1
				sty t1+1
				ldy #0
@loop:	lda(t1),y
				beq done
				jsr cout
				clc
				lda t1
				adc #1
				sta t1
				bcc @nocarry
				inc t1+1
@nocarry:
				jmp @loop
done:
				pla
				tay
				pla
				rts

