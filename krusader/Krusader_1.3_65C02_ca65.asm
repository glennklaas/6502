; KRUSADER - An Editor/Assembler/Disassembler for the Replica 1

; 65C02 version 1.3 - 24 December, 2007
; (c) Ken Wessen (ken.wessen@gmail.com)

.debuginfo +
.setcpu "65C02"

;-------------------------------------------------------------------------
;  ACIA ADDRESSES
;-------------------------------------------------------------------------
ACIA 		:= $A000	;BASE ADDRESS OF THE MC68B50P
ACIAControl	:= ACIA+0	; Set operational parameters (w)     
ACIAStatus 	:= ACIA+0	; Indicates if char has been received (r)
ACIAData 	:= ACIA+1	; Data being recieved (r) or sent (w)

; Notes:
;   	- entry points:
;		SHELL = $711C($F01C)
;		MOVEDN = $7304($F204)
;		DEBUG = -($FE03)
;		SHOW = -($FE16)
;		DSMBL = $7BEA($FAEA)
; ****************************************
;	- Does not support the single bit operations BBR, BBS, SMB, RMB, or STP and WAI
;	- minimonitor does not include tracing 
;	- 49 bytes free
.segment "GAKSBC"

.segment "CODE"

.segment "KRUCODE"
;.org $F000
APPLE1  		=0
INROM			=1
TABTOSPACE 		=1
UNK_ERR_CHECK 	=0

MINIMONITOR 	=INROM & 1
BRKAS2 			=1 ; if 1, BRK will assemble to two $00 bytes
					; if set, then minimonitor will work unchanged 
					; for both hardware and software interrupts

;.if INROM				;L1
;	.org $F000
;.else					;L1
;	.org $7100
;.endif					;L0
;.start MAIN
	
.if INROM			;L1
	MONTOR	= ESCAPE
.ELSE				;L1
	MONTOR	= $FF1F
.endif				;L0

; Constants
BS		=$08		; backspace
SP		=$20		; space
CR		=$0D		; carriage return
LF		=$0A		; line feed
ESC		=$1B		; escape
INMASK  =$7F
	
LNMSZ	=$03
LBLSZ	=$06		; labels are up to 6 characters
MNESZ	=$03		; mnemonics are always 3 characters
ARGSZ	=$0E		; arguments are up to 14 characters
COMSZ	=$0A		; comments fill the rest - up to 10 characters

ENDLBL	=LNMSZ+LBLSZ+1
ENDMNE	=ENDLBL+MNESZ+1
ENDARG	=ENDMNE+ARGSZ+1
ENDLN	=ENDARG+COMSZ+1

SYMSZ	=$06		; size of labels

LINESZ	=$27		; size of a line
USESZ	=LINESZ-LNMSZ-1	; usable size of a line
CNTSZ	=COMM-LABEL-1	; size of content in a line
	
MAXSYM	=$20		; at most 32 local symbols (256B) and 
MAXFRF	=$55		; 85 forward references (896B)
					; globals are limited by 1 byte index => max of 256 (2K)
					; global symbol table grows downwards

; Symbols used in source code
IMV		='#'		; Indicates immediate mode value
HEX		='$'		; Indicates a hex value
OPEN	='('		; Open bracket for indirect addressing
CLOSE	=')'		; Close bracket for indirect addressing
PC		='*'		; Indicates PC relative addressing
LOBYTE	='<'		; Indicates lo-byte of following word
HIBYTE	='>'		; Indicates hi-byte of following word
PLUS	='+'		; Plus in simple expressions
MINUS	='-'		; Minus in simple expressions
DOT		='.'		; Indicates a local label
QUOTE	='''		; delimits a string
COMMA	=','
CMNT	=';'		; indicates a full line comment

PROMPT	='?'

EOL		=$00		; end of line marker
EOFLD	=$01		; end of field in tokenised source line
BLANK	=$02		; used to mark a blank line

PRGEND	=$FE		; used to flag end of program parsing
FAIL	=$FF		; used to flag failure in various searches

; Zero page storage	
IOBUF	=$00		; I/O buffer for source code input and analysis
LABEL	=$04		; label starts here
MNE		=$0B		; mnemonic starts here
ARGS	=$0F		; arguments start here
COMM    =$1D		; comments start here
FREFTL	=$29		; address of forward reference table
FREFTH	=$2A
NFREF	=$2B		; number of forward symbols
RECNM	=$2C		; number of table entries
RECSZ	=$2D		; size of table entries
RECSIG	=$2E		; significant characters in table entries
XSAV	=$2F
YSAV	=$30
CURMNE	=$3C		; Holds the current mne index
CURADM	=$3D		; Holds the current addressing mode
LVALL	=$3E		; Storage for a label value
LVALH	=$3F	
TBLL	=$40		; address of search table
TBLH	=$41
STRL	=$42		; address of search string
STRH	=$43
SCRTCH	=$44		; scratch location
NPTCH	=$45		; counts frefs when patching
PTCHTL	=$46		; address of forward reference being patched
PTCHTH	=$47
FLGSAV	=$48

MISCL	=$50		; Miscellaneous address pointer
MISCH	=$51		
MISC2L	=$52		; And another
MISC2H	=$53	
TEMP1	=$54		; general purpose storage
TEMP2	=$55	
TEMP3	=$56	
TEMP4	=$57
LMNE	=TEMP3		; alias for compression and expansion routines
RMNE	=TEMP4
FRFLAG	=$58		; if nonzero, disallow forward references
ERFLAG	=$59		; if nonzero, do not report error line
HADFRF	=$5A		; if nonzero, handled a forward reference
PRFLAG	=$5B

; want these to persist if possible when going into the monitor
; to test code etc, so put them right up high
; these 6 locations must be contiguous
GSYMTL	=$E9		; address of the global symbol table
GSYMTH	=$EA	
NGSYM	=$EB		; number of global symbols
LSYMTL	=$EC		; address of the local symbol table
LSYMTH	=$ED
NLSYM	=$EE		; number of local symbols

.if MINIMONITOR		;L1
	; these 7 locations must be contiguous
	REGS	=$F0
	SAVP	=REGS
	SAVS	=$F1
	SAVY	=$F2
	SAVX	=$F3
	SAVA	=$F4
.endif				;L0

CURPCL	=$F5		; Current PC
CURPCH	=$F6

CODEH	=$F8		; hi byte of code storage area (low is $00)
TABLEH	=$F9		; hi byte of symbol table area

; these 4 locations must be contiguous
LINEL	=$FA		; Current source line number (starts at 0)
LINEH	=$FB		
CURLNL	=$FC		; Current source line address
CURLNH	=$FD
		
SRCSTL	=$FE		; source code start address
SRCSTH	=$FF	
	
; for disassembler
FORMAT	=FREFTL		; re-use spare locations
LENGTH	=FREFTH
COUNT	=NFREF
PCL		=CURPCL
PCH		=CURPCH

; ****************************************
; 	COMMAND SHELL/EDITOR CODE
; ****************************************

MAIN:
.if INROM
		LDA #$03
		STA CODEH
		LDA #$20
		STA SRCSTH
		LDA #$7C
		STA TABLEH
.else
		LDA #$03
		STA CODEH
		LDA #$1D
		STA SRCSTH
		LDA #$6D
		STA TABLEH
.endif
	LDX #MSGSZ
@NEXT:	
	LDA MSG-1,X
	JSR OUTCH
	DEX
	BNE @NEXT
	DEX
	TXS		; reset stack pointer on startup
	JSR SHINIT	; default source line and address data
;	JMP SHELL
; falls through to SHELL 
  		
; ****************************************
	
SHELL:			; Loops forever
				; also the re-entry point
	CLD			; just incase
	LDA #$00
	STA PRFLAG
	JSR FILBUF
	LDX #ARGS
	STX FRFLAG	; set flags in SHELL
	STX ERFLAG
	JSR CRLF
	LDA #PROMPT
	JSR OUTCH	; prompt
	JSR OUTSP	; can drop this if desperate for 3 more bytes :-)
@KEY:	JSR GETCH
	CMP #BS
	BEQ SHELL	; start again
	CMP #CR
	BEQ @RUN
	JSR OUTCH
	STA IOBUF,X
	INX
	BNE @KEY	; always branches
@RUN:	LDA ARGS	
	BEQ SHELL	; empty command line
	LDA ARGS+1	; ensure command is just a single letter
	BEQ @OK
	CMP #SP
	BNE SHLERR
@OK:	LDX #NUMCMD
@NEXT:	LDA CMDS-1,X	; find the typed command
	CMP ARGS
	BEQ GOTCMD
	DEX
	BNE @NEXT
	PHA		; put dummy data on the stack
	PHA
SHLERR:	
	LDY #SYNTAX
ERR2:	PLA		; need to clean up the stack
	PLA
	JSR SHWERR
	BNE SHELL
GOTCMD:	JSR RUNCMD
	JMP SHELL	; ready for next command

; ****************************************

SHINIT:	
	LDA #$00
	TAY
	STA SRCSTL	; low byte zero for storage area
	STA (SRCSTL),Y	; and put a zero in it for EOP
TOSTRT:			; set LINEL,H and CURLNL,H to the start
	LDA SRCSTH
	STA CURLNH
	LDA #$00
	STA LINEL
	STA LINEH	; 0 lines
	STA CURLNL
	RTS		; leaves $00 in A 
	
; ****************************************

PANIC:
	JSR SHINIT
	LDA ARGS+2
	BNE @SKIP
	LDA #$01
@SKIP:	STA (SRCSTL),Y	; Y is $00 from SHINIT
	RTS

; ****************************************

VALUE:	
	JSR ADDARG
	BEQ SHLERR
	JSR CRLF
	LDA LVALH
	LDX LVALL
	JMP PRNTAX
	
; ****************************************

RUN:	
	JSR ADDARG
	BEQ SHLERR
	JSR CRLF
	JMP (LVALL)	; jump to the address

; ****************************************

ADDARG:			; convert argument to address
	LDX #$02
	LDA ARGS,X
	BEQ @NOARG
	PHA
	JSR EVAL
	PLA
	;CPX #FAIL
	INX
	BEQ ERR2;SHLERR
@NOARG:	RTS

; ****************************************

PCTOLV:
	LDA CURPCL
	STA LVALL
	LDA CURPCH
	STA LVALH
	RTS
	
; ****************************************

LVTOPC:	
	LDA LVALL
	STA CURPCL
	LDA LVALH
	STA CURPCH
	RTS
		
; ****************************************

FILLSP:
	LDA #SP
FILBUF:			; fill the buffer with the contents of A
	LDX #LINESZ
@CLR:	STA IOBUF-1+256,X ;GAK added 256
	DEX
	BNE @CLR
	RTS
	
; ****************************************

RUNCMD:	
	LDA CMDH-1,X
  	PHA
  	LDA CMDL-1,X
  	PHA
  	RTS

; ****************************************

NEW:	
	JSR SHINIT
	JMP INSERT
	
; ****************************************

LIST:		; L 	- list all
			; L nnn - list from line nnn
	JSR TOSTRT
	JSR GETARG
	BEQ @NEXT	; no args, list from start
	JSR GOTOLN	; deal with arguments if necessary
@NEXT:	LDY #$00
	LDA (CURLNL),Y
	BEQ @RET
	JSR PRNTLN
	JSR UPDTCL
	LDA KBDRDY
	.if APPLE1
		BPL @NEXT
	.else
		BEQ @NEXT
	.endif
	LDA KBD
@RET:	RTS
	
; ****************************************

MEM:	
	JSR TOEND	; set CURLNL,H to the end
	JSR CRLF	
	LDX #$04
@LOOP:	LDA CURLNL-1,X
	JSR OUTHEX
	CPX #$03
	BNE @SKIP
	JSR PRDASH
@SKIP:	DEX
	BNE @LOOP
RET:	RTS

; ****************************************

GETARG:			; get the one or two numeric arguments
			; to the list, edit, delete and insert commands
			; store them in TEMP1-4 as found
			; arg count in Y or X has FAIL
	LDY #$00
	STY YSAV
	LDX #$01
@NEXT:	LDA ARGS,X
	BEQ @DONE	; null terminator
	CMP #SP		; find the space
	BEQ @CVT
	CMP #HEX	; or $ symbol
	BEQ @CVT
	INX
	BNE @NEXT
@CVT:	INC YSAV	; count args
	LDA #HEX
	STA ARGS,X	; replace the space with '$' and convert
	JSR CONVRT
	;CPX #FAIL
	INX
	BEQ LCLERR
	;INX
	LDA LVALL
	STA TEMP1,Y
	INY
	LDA LVALH
	STA TEMP1,Y
	INY
	BNE @NEXT	; always branches
@DONE:	LDY YSAV
	RTS		; m in TEMP1,2, n in TEMP3,4
	
; ****************************************

EDIT:	
	JSR GETARG
	;CPY #$01
	DEY
	BNE LCLERR
	JSR DELETE	; must not overwrite the command input buffer
;	JMP INSERT
; falls through to INSERT

; ****************************************
	
INSERT:	
	JSR GETARG	; deal with arguments if necessary
	;CPX #FAIL
	INX
	BEQ LCLERR
	;CPY #$00	; no args
	TYA
	BNE @ARGS
	JSR TOEND	; insert at the end
	CLC
	BCC @IN
@ARGS:	JSR GOTOLN	; if no such line will insert at end
@IN:	JSR INPUT	; Get one line
	CPX #FAIL	; Was there an error?
	BEQ RET;
	; Save the tokenised line and update pointers
	; tokenised line is in IOBUF, size X
	; move up from CURLNL,H to make space
	STX XSAV	; save X (data size)
	LDA CURLNH
	STA MISCH
	STA MISC2H
	LDA CURLNL
	STA MISCL	; src in MISCL,H now
	CLC
	ADC XSAV
	STA MISC2L
	BCC @READY
	INC MISC2H	; MISC2L,H is destination
@READY:	JSR GETSZ
	JSR MOVEUP	; do the move
	LDY #$00
	; now move the line to the source storage area
	; Y bytes, from IOBUF to CURLN
@MOVE:	LDA IOBUF,Y
	STA (CURLNL),Y
	INY
	CPY XSAV
	BNE @MOVE
	JSR UPDTCL	; update CURLNL,H
	BNE @IN		; always branches

; ****************************************

LCLERR:			; local error wrapper
				; shared by the routines around it
	JMP SHLERR

; ****************************************

GETSZ:			; SIZE = TEMP1,2 = lastlnL,H - MISCL,H + 1
	LDX #-$04+256 ;GAK added 256
@LOOP:	LDA CURLNH+1,X
	PHA			; save CURLN and LINEN on the stack
	INX
	BNE @LOOP
	JSR TOEND
	SEC
	LDA CURLNL
	SBC MISCL
	STA TEMP1
	LDA CURLNH
	SBC MISCH
	STA TEMP2
	INC TEMP1
	BNE @SKIP
	INC TEMP2
@SKIP:	LDX #$04
@LOOP2:	PLA		; get CURLN and LINEN from the stack
	STA LINEL-1,X
	DEX
	BNE @LOOP2
	RTS
	
; ****************************************

DELETE:		; Delete the specified range
			; Moves from address of line arg2 (MISCL,H)
			; to address of line arg1 (MISC2L,H)
	JSR GETARG
;	CPY #$00
	BEQ LCLERR
	STY YSAV
@DOIT:	JSR GOTOLN	; this leaves TEMP1 in Y and TEMP2 in X
	CPX #FAIL
	BEQ LCLERR
	LDA CURLNL
	STA MISC2L
	LDA CURLNH
	STA MISC2H	; destination address is set in MISC2L,H
	LDA YSAV
	;CMP #$01
	LSR
	BEQ @INC
	LDX TEMP4
	LDY TEMP3	; Validate the range arguments
	CPX TEMP2	; First compare high bytes
	BNE @CHK	; If TEMP4 != TEMP2, we just need to check carry
	CPY TEMP1	; Compare low bytes when needed
@CHK:	BCC LCLERR	; If carry clear, 2nd argument is too low
@INC:	INY		; Now increment the second argument
	BNE @CONT
	INX
@CONT:	STX TEMP2
	STY TEMP1
	JSR GOTOLN
	LDA CURLNL
	STA MISCL
	LDA CURLNH
	STA MISCH
	JSR GETSZ
;	JMP MOVEDN
; falls through
	
; ****************************************
;	Memory moving routines
;  From http://www.6502.org/source/general/memory_move.html
; ****************************************

; Some aliases for the following two memory move routines

FROM	=MISCL		; move from MISCL,H
TO		=MISC2L		; to MISCL2,H
SIZEL	=TEMP1
SIZEH	=TEMP2

MOVEDN:			; Move memory down
	LDY #$00
	LDX SIZEH
	BEQ @MD2
@MD1:	LDA (FROM),Y ; move a page at a time
	STA (TO),Y
	INY
	BNE @MD1
	INC FROM+1
	INC TO+1
	DEX
	BNE @MD1
@MD2:	LDX SIZEL
	BEQ @MD4
@MD3:	LDA (FROM),Y ; move the remaining bytes
	STA (TO),Y
	INY
	DEX
	BNE @MD3
@MD4:	RTS
	
MOVEUP:			; Move memory up
	LDX SIZEH	; the last byte must be moved first
	CLC		; start at the final pages of FROM and TO
	TXA
	ADC FROM+1
	STA FROM+1
	CLC
	TXA
	ADC TO+1
	STA TO+1
	INX		; allows the use of BNE after the DEX below
	LDY SIZEL
	BEQ @MU3
	DEY		; move bytes on the last page first
	BEQ @MU2
@MU1:	LDA (FROM),Y
	STA (TO),Y
	DEY
	BNE @MU1
@MU2:	LDA (FROM),Y	; handle Y = 0 separately
	STA (TO),Y
@MU3:	DEY
	DEC FROM+1	; move the next page (if any)
	DEC TO+1
	DEX
	BNE @MU1
	RTS       

; ****************************************

TOEND:	
	LDA #$FF
	STA TEMP2	; makes illegal line number
;	JMP GOTOLN	; so CURLNL,H will be set to the end
; falls through

; ****************************************
	
GOTOLN:			; go to line number given in TEMP1,2
			; sets CURLNL,H to the appropriate address
			; and leaves TEMP1 in Y and TEMP2 in X
			; if not present, return #FAIL in X
			; and LINEL,H will be set to the next available line number
EOP	= LFAIL
GOTIT	= LRET
	JSR TOSTRT
@NXTLN:			; is the current line number the same 
			; as specified in TEMP1,2?
			; Z set if equal
			; C set if TEMP1,2 >= LINEL,H 
	LDY TEMP1
	CPY LINEL
	BNE @NO
	LDX TEMP2
	CPX LINEH
	BEQ GOTIT
@NO:	LDY #$FF
@NXTBT:	INY		; find EOL
	LDA (CURLNL),Y
	BNE @NXTBT
	TYA
	;CPY #$00
	BEQ EOP		; null at start of line => end of program
	INY
	JSR UPDTCL	; increment CURLNL,H by Y bytes
	BNE @NXTLN	; always branches
;.EOP	LDX #FAIL
;.GOTIT	RTS		; address is now in CURLNL,H

; ****************************************

PRNTLN:			; print out the current line (preserve X)
	JSR CRLF
	STX XSAV
	JSR DETKN
	INY
	JSR PRLNNM
	LDX #$00
@PRINT:	LDA LABEL,X
	BEQ @DONE	; null terminator
	JSR OUTCH
	INX
	;CPX #USESZ
	BNE @PRINT
@DONE:	LDX XSAV
	RTS
		
; ****************************************

NEXTCH:			; Check for valid character in A
			; Also allows direct entry to appropriate location
			; Flag success with C flag
	JSR GETCH
	.if TABTOSPACE	;L1
		CMP #$09	; is it a tab?
		BNE @SKIP
		LDA #SP
	.endif			;L0
@SKIP:	CMP #SP		; valid ASCII range is $20 to $5D
	BPL CHANM	; check alpha numeric entries
	TAY
	PLA
	PLA
	PLA
	PLA		; wipe out return addresses
	CPY #BS
	BEQ INPUT	; just do it all again
@NOBS:	CPY #CR
	BNE LFAIL
	CPX #LABEL	; CR at start of LABEL means a blank line
	BEQ DOBLNK
	LDA #EOL
	STA IOBUF,X
	BEQ GOTEOL
LFAIL:	LDX #FAIL	; may flag error or just end
LRET:	RTS
CHANM:	CPX #LINESZ	; ignore any characters over the end of the line
	BPL CHNO
;	CMP #']'+1	; is character is in range $20-$5D?
;	BPL CHNO	; branch to NO...
CHOK:	SEC		; C flag on indicates success
	RTS
CHKLBL:	CMP #DOT	; here are more specific checks
	BEQ CHOK
CHKALN:	CMP #'0'	; check alpha-numeric
	BMI CHNO	; less than 0
	CMP #'9'+1
	BMI CHOK	; between 0 and 9
CHKLET:	CMP #'A'
	BMI CHNO	; less than A
	CMP #'Z'+1	
	BMI CHOK	; between A and Z
CHNO:	CLC
	RTS		; C flag off indicates failure
	
; ****************************************

DOBLNK:	
	LDA #BLANK
	TAX		; BLANK = #$02, and that is also the
	STA IOBUF	; tokenised size of a blank line
	LDA #EOL	; (and only a blank line)
	STA IOBUF+1
ENDIN:	RTS	

INPUT:	
	JSR FILLSP
	LDA #EOL	; need this marker at the start of the comments
	STA COMM	; for when return hit in args field
	JSR CRLF
	JSR PRLNNM
	LDX #LABEL	; point to LABEL area
	LDA #ENDLBL
	JSR ONEFLD
	JSR INSSPC	; Move to mnemonic field
	LDA LABEL
	CMP #CMNT
	BEQ @CMNT
	LDA #ENDMNE
	JSR ONEFLD
	JSR INSSPC	; Move to args field
	LDA #ENDARG
	JSR ONEFLD
@CMNT:	LDA #EOL
	JSR ONEFLD
GOTEOL:	;JMP TOTKN	
; falls through

; ****************************************

TOTKN:			; tokenise to IOBUF to calc size
			; then move memory to make space
			; then copy from IOBUF into the space
	LDX #$00
	STX MISCH
	LDA #SP
	STA TEMP2
	LDA #LABEL
	STA MISCL
	LDA #EOFLD
	STA TEMP1
	JSR TKNISE
	LDY LABEL
	CPY #CMNT
	BNE @CONT
	LDA #MNE
	BNE ISCMNT	; always branches
@CONT:	TXA		; save X
	PHA		

;	JSR SRCHMN	; is it a mnemonic?

SRCHMN:  		; Search the table of mnemonics	for the mnemonic in MNE
			; Return the index in A

CMPMNE:			; compress the 3 char mnemonic
			; at MNE to MNE+2 into 2 chars
			; at LMNE and RMNE
	CLC
	ROR LMNE		
	LDX #$03
@NEXT2:	SEC
	LDA MNE-1,X
	SBC #'A'-1
	LDY #$05
@LOOP2:	LSR
	ROR LMNE
	ROR RMNE
	DEY
	BNE @LOOP2
	DEX
	BNE @NEXT2

	LDX #NUMMN	; Number of mnemonics
@LOOP:	LDA LMNETB-1,X
	CMP LMNE
	BNE @NXT
	LDA RMNETB-1,X
	CMP RMNE
	BEQ @FND
@NXT:	DEX
	BNE @LOOP
@FND:	DEX		; X = $FF for failure
;	RTS
	
	TXA
	CMP #FAIL
	BNE @FOUND
	LDA MNE		; or a directive?
	CMP #DOT
	BNE @ERR
	LDX #NUMDIR
	LDA MNE+1
@NEXT:	CMP DIRS-1,X
	BEQ @FDIR
	DEX
	BNE @NEXT
@ERR:	PLA
	LDY #INVMNE
	JMP SHWERR
@FDIR:	DEX
	ASL		; double directive code to avoid collisions
@FOUND:	TAY		; put mnemonic/directive code in Y
	INY		; offset by 1 so no code $00	
	PLA		; restore Y
	TAX
	STY IOBUF,X
	INX
	LDA #ARGS
	STA MISCL
	LDA #EOFLD
	STA TEMP1
	JSR TKNISE
	STX XSAV
	INC XSAV
	LDA #COMM
ISCMNT:	STA MISCL
	LDA #EOL
	STA TEMP1
	STA TEMP2
	JSR TKNISE
	CPX XSAV
	BNE @RET
	DEX		; no args or comments, so stop early
	STA IOBUF-1+256,X	; A already holds $00  ;GAK added 256
@RET: 	RTS	
	
ONEFLD:			; do one entry field
			; A holds the end point for the field
	STA TEMP1	; last position
@NEXT:	JSR NEXTCH	; catches ESC, CR and BS
	BCC @NEXT	; only allow legal keys
	JSR OUTCH	; echo
	STA IOBUF,X
	INX
	CMP #SP
	BEQ @FILL
	CPX TEMP1
	BNE @NEXT
@RET:	RTS
@FILL:	LDA TEMP1
	BEQ @NEXT	; just treat a space normally
	CPX TEMP1	; fill spaces
	BEQ @RET
	LDA #SP
	STA IOBUF,X
	JSR OUTCH
@CONT:	INX
	BNE @FILL	; always branches

; ****************************************
	
INSSPC:	
	LDA IOBUF-1+256,X	; was previous character a space?  ;GAK added 256
	CMP #SP
	BEQ @JUMP
@GET:	JSR NEXTCH	; handles BS, CR and ESC
	CMP #SP
	BNE @GET	; only let SP through
@JUMP:	STA IOBUF,X	; insert the space
	INX
	JMP OUTCH

TKNISE:	
	LDY #$00
@NEXT:	LDA (MISCL),Y
	BEQ @EOF
	CMP TEMP2
	BEQ @EOF	; null terminator
	STA IOBUF,X
	INX
	INC MISCL
	BNE @NEXT
@EOF:	LDA TEMP1
	STA IOBUF,X
	INX
	RTS

; ****************************************

DETKN:			; Load a line to the IOBUF
			; (detokenising as necessary)
			; On return, Y holds tokenised size
	JSR FILLSP
	LDY #$00
	LDX #LABEL
@LBL:	LDA (CURLNL),Y
	BEQ @EOP	; indicates end of program
	CMP #BLANK
	BNE @SKIP
	INY
	LDA #EOL
	BEQ @EOL
@SKIP:	CMP #EOFLD
	BEQ @CHK
	STA IOBUF,X
	INX
	INY
	BNE @LBL
@CHK:	LDA LABEL
	CMP #CMNT
	BNE @NEXT
	LDX #MNE
	BNE @CMNT	; always branches
@NEXT:	INY
	LDA (CURLNL),Y	; get mnemonic code
	TAX
	DEX		; correct for offset in tokenise
	STX CURMNE	; store mnemonic for assembler
	CPX #NUMMN
	BPL @DIR
	TYA		; save Y
	PHA	
	JSR EXPMNE
	PLA		; restore Y
	TAY
	BNE @REST
@DIR:	;STX MNE+1
	TXA
	LSR		; halve the directive codes
	STA MNE+1
	LDA #DOT
	STA MNE
@REST:	INY
	LDX #ARGS	; point to ARGS area
@LOOP:	LDA (CURLNL),Y
	BEQ @EOL	; indicates end of line
	CMP #EOFLD
	BNE @CONT
	INY
	LDX #COMM	; point to COMM area
	BNE @LOOP
@CONT:	STA IOBUF,X
	INX
@CMNT:	INY
	BNE @LOOP
@EOP:	LDX #PRGEND
@EOL:	STA IOBUF,X
	RTS

; ****************************************
; 		ASSEMBLER CODE
; ****************************************

ASSEM:			; Run an assembly
	JSR INIT	; Set the default values
	JSR CRLF
	JSR MYPRPC
@NEXT:	JSR DO1LN	; line is in the buffer - parse it
	;CPX #FAIL
	INX
	BEQ SHWERR
	CPX #PRGEND+1	; +1 because of INX above
	BNE @NEXT
	INC FRFLAG	; have to resolve them all now - this ensures FRFLAG nonzero
	JSR PATCH	; back patch any remaining forward references
	;CPX #FAIL
	INX
	BEQ SHWERR
	JMP MYPRPC	; output finishing module end address
;.ERR	JMP SHWERR

; ****************************************

SHWERR:			; Show message for error with id in Y
			; Also display line if appropriate
	JSR CRLF
	LDX #ERPRSZ
@NEXT:	LDA ERRPRE-1,X
	JSR OUTCH
	DEX
	BNE @NEXT
	TYA
.if UNK_ERR_CHECK	;L
		BEQ @SKIP
		CPY #MAXERR+1
		BCC @SHOW	; If error code valid, show req'd string
	@UNKWN:	LDY #UNKERR	; else show unknown error
		BEQ @SKIP
.endif				;L0
@SHOW:	CLC
	TXA		; sets A to zero
@ADD:	ADC #EMSGSZ
	DEY
	BNE @ADD
	TAY
@SKIP:	LDX #EMSGSZ	
.if UNK_ERR_CHECK				;L1
	@LOOP:	LDA ERRMSG,Y
.else							;L1
	@LOOP:	LDA ERRMSG-EMSGSZ,Y
.endif							;L0
	JSR OUTCH
	INY
	DEX
	BNE @LOOP
	;LDX #FAIL
	DEX		; sets X = #FAIL
	LDA ERFLAG
	BNE RET1
	JMP PRNTLN

; ****************************************
	
INIT:
	JSR TOSTRT	; leaves $00 in A
	STA FRFLAG
	STA NGSYM
	STA GSYMTL
	STA CURPCL	; Initial value of PC for the assembled code
	LDA CODEH
	STA CURPCH
	JSR CLRLCL	; set local and FREF table pointers 
	STX GSYMTH	; global table high byte - in X from CLRLCL
;	JMP INITFR
; falls through

; ****************************************

INITFR:			; initialise the FREF table and related pointers
	LDA #$00
	STA NFREF
	STA FREFTL
	STA PTCHTL
	LDY TABLEH
	INY
	STY FREFTH
	STY PTCHTH
RET1:	RTS
		
; ****************************************

DO1LN:	
	JSR DETKN
	CPX #PRGEND
	BEQ @ENDPR
	CPX #LABEL	; means we are still at the first field => blank line
	BEQ @DONE
	LDA #$00
	STA ERFLAG
	STA FRFLAG
	STA HADFRF
	JSR PARSE
	CPX #FAIL
	BEQ DORTS
@CONT:	LDY #$00
@LOOP:	LDA (CURLNL),Y
	BEQ @DONE
	INY
	BNE @LOOP
@DONE:	INY		; one more to skip the null
@ENDPR:	;JMP UPDTCL
; falls through

; ****************************************

UPDTCL:			; update the current line pointer 
			; by the number of bytes in Y
	LDA CURLNL
	STY SCRTCH
	CLC
	ADC SCRTCH	; move the current line pointer forward by 'Y' bytes
	STA CURLNL
	BCC INCLN
	INC CURLNH	; increment the high byte if necessary
INCLN:	
	INC LINEL
	BNE DORTS
	INC LINEH
DORTS:	RTS		; global label so can be shared
	
; ****************************************

MKOBJC:			; MNE is in CURMNE, addr mode is in CURADM
			; and the args are in LVALL,H
			; calculate the object code, and update PC
	LDY CURMNE	
	LDA BASE,Y	; get base value for current mnemonic
	LDX CURADM
	CLC
	ADC OFFSET,X	; add in the offset	
@NOSTZ:	CPX #ABY	; handle exceptions
	BEQ @CHABY
	CPX #IMM
	BNE @CONT
	CPY #$22	; check if BIT first
	BNE @NOBIT
	ADC #ADJBIT
@NOBIT:	CPY #$28	; immediate mode need to adjust a range
	BMI @CONT
	CPY #$2F+1
	BCS @CONT
	ADC #ADJIMM	; carry is clear
;	BNE @CONT	
@CHABY:	CPY #$35	; LDX check
	BNE @CONT
	CLC
	ADC #ADJABY
@CONT:	CPY #$23	; STZ needs special handling
	BNE @DONE
	CPX #ABS
	BMI @DONE
	BEQ @SKIP
	ADC #$1-$10+256	; carry is set   ;GAK added 256
@SKIP:	ADC #$30-1	; carry is set
@DONE:	JSR DOBYTE	; we have the object code
	.if BRKAS2
		CMP #$00
		BNE @MKARG
		JSR DOBYTE
	.endif
@MKARG:		; where appropriate, the arg value is in LVALL,H
			; copy to ARGS and null terminate
	TXA		; quick check for X=0
	BEQ DORTS	; IMP - no args
	DEX
	BEQ DORTS	; ACC - no args
	LDA LVALL	; needed for .BYT handling
	; word arg if X is greater than or equal to ABS
	CPX #ABS-1
	BMI DOBYTE	; X < #ABS	
DOWORD:	JSR DOBYTE
	LDA LVALH
DOBYTE:	LDY #$00
	STA (CURPCL),Y
;	JMP INCPC
; falls through

; ****************************************

INCPC:			; increment the PC
	INC CURPCL
	BNE @DONE	; any carry?
	INC CURPCH	; yes
@DONE:	RTS

; ****************************************
	
CALCAM:			; work out the addressing mode
	JSR ADDMOD	
	CPX #FAIL
	BNE MKOBJC
	LDY #ILLADM	; Illegal address mode error
	RTS
	
PARSE:			; Parse one line and validate
	LDA LABEL
	CMP #CMNT
	BEQ DORTS	; ignore comment lines
	LDX MNE		; first need to check for an equate
	CPX #DOT
	BNE @NOEQU
	LDX MNE+1
	CPX #MOD	; Do we have a new module?
	BNE @NOMOD
	JMP DOMOD
@NOMOD:	CPX #EQU
	BEQ DOEQU
@NOEQU:	CMP #SP		; Is there a label?
	BEQ @NOLABL	
	JSR PCSYM	; save the symbol value - in this case it is the PC
@NOLABL: LDA MNE		
	CMP #DOT	; do we have a directive?
	BNE CALCAM 	; no
	
; ****************************************
	
DODIR:	
	LDX #$00	; handle directives (except equate and module)
	LDA MNE+1
	CMP #STR
	BEQ DOSTR
	STA FRFLAG	; Disallows forward references
	JSR QTEVAL
	;CPX #FAIL
	INX
	BEQ DIRERR
	LDA LVALL
	LDX MNE+1
	CPX #WORD
	BEQ DOWORD
	LDX LVALH
	BEQ DOBYTE
DIRERR:	LDY #SYNTAX
	LDX #FAIL
	RTS
DOSTR:	LDA ARGS,X
	CMP #QUOTE
	BNE DIRERR	; String invalid
@LOOP:	INX
	LDA ARGS,X
	BEQ DIRERR	; end found before string closed - error
	CMP #QUOTE
	BEQ DIROK
	JSR DOBYTE	; just copy over the bytes
	CPX #ARGSZ	; can't go over the size limit
	BNE @LOOP
	BEQ DIRERR	; hit the limit without a closing quote - error
DIROK:	RTS

; ****************************************

DOEQU:	
	;LDA LABEL
	STA FRFLAG
	JSR CHKALN	; label must be global
	BCC DIRERR	; MUST have a label for an equate
	LDX #$00
	JSR QTEVAL	; work out the associated value
	;CPX #FAIL
	INX
	BEQ DIRERR
	JMP STRSYM
	
; ****************************************

DOMOD:			; Do we have a new module?
	;LDA LABEL
	JSR CHKALN	; must have a global label
	BCC DIRERR
	LDY #$00
	LDA ARGS
	BEQ @STORE
	CMP #SP
	BEQ @STORE
@SETPC:	JSR ATOFR	; output finishing module end address (+1)
	LDX #$00	; set a new value for the PC from the args
	LDA ARGS
	JSR CONVRT
	;CPX #FAIL
	INX
	BEQ DIRERR
	JSR LVTOPC
@STORE:	JSR PCSYM
	CPX #FAIL
	BEQ DIROK
	JSR PATCH
	CPX #FAIL
	BEQ DIROK
	JSR SHWMOD
	LDA #$00	; reset patch flag
	JSR ATOFR	; output new module start address
;	JMP CLRLCL
; falls through

; ****************************************

CLRLCL:			; clear the local symbol table
	LDX #$00	; this also clears any errors
	STX NLSYM	; to their starting values
	STX LSYMTL
	LDX TABLEH	; and then the high bytes
	STX LSYMTH
	RTS

; ****************************************

ATOFR:	STA FRFLAG
;	JMP MYPRPC
; falls through
	
; ****************************************

MYPRPC:	
	LDA CURPCH
	LDX CURPCL
	LDY FRFLAG	; flag set => print dash and minus 1
	BEQ @NODEC
	PHA
	JSR PRDASH
	PLA
	CPX #$00
	BNE @SKIP	; is X zero?
	SEC
	SBC #$01
@SKIP:	DEX
@NODEC:	JMP PRNTAX

; ****************************************

PATCH:			; back patch in the forward reference symbols
			; all are words
	LDX NFREF
	BEQ @RET	; nothing to do
	STX ERFLAG	; set flag
@STRPC:	STX NPTCH
	LDA CURPCL	; save the PC on the stack
	PHA
	LDA CURPCH
	PHA	
	JSR INITFR
@NEXT:	LDY #$00
	LDA FRFLAG
	STA FLGSAV	; so I can restore the FREF flag
	STY HADFRF
	LDA (PTCHTL),Y
	CMP #DOT
	BNE @LOOP
	STA FRFLAG	; nonzero means must resolve local symbols
@LOOP:	LDA (PTCHTL),Y	; copy symbol to COMM
	STA COMM,Y
	INY
	CPY #SYMSZ
	BNE @LOOP
	LDA (PTCHTL),Y	; get the PC for this symbol
	STA CURPCL
	INY
	LDA (PTCHTL),Y
	STA CURPCH
	INY 
	LDA (PTCHTL),Y
	STA TEMP1	; save any offset value
	JSR DOLVAL	; get the symbols true value
	CPX #FAIL	; value now in LVALL,H or error
	BEQ @ERR	
	LDA HADFRF	; if we have a persistent FREF
	BEQ @CONT	; need to copy its offset as well
	LDA TEMP1  
	STA (MISCL),Y	; falls through to some meaningless patching...
	;SEC		; unless I put these two in
	;BCS @MORE
@CONT:	JSR ADD16X	
	LDY #$00
	LDA (CURPCL),Y	; get the opcode
	CMP #$80
	BEQ @BRA
	AND #$1F	; check for branch opcode - format XXY10000
	CMP #$10
	BEQ @BRA
	JSR INCPC	; skip the opcode
@SKIP:	LDA LVALL
	JSR DOWORD
@MORE:	CLC
	LDA PTCHTL	; move to the next symbol
	ADC #SYMSZ+3
	STA PTCHTL
	BCC @DECN
	INC PTCHTH
@DECN:	LDA FLGSAV
	STA FRFLAG
	DEC NPTCH
	BNE @NEXT
@DONE:	PLA
	STA CURPCH	; restore the PC from the stack
	PLA
	STA CURPCL
@RET:	RTS
@BRA:	JSR ADDOFF	; BRA instructions have a 1 byte offset argument only
	CPX #FAIL
	BEQ @ERR
	LDY #$01	; save the offset at PC + 1
	LDA LVALL
	STA (CURPCL),Y
	JMP @MORE
@ERR:	LDY #$00
	JSR OUTSP
@LOOP2:	LDA (PTCHTL),Y	; Show symbol that failed
	JSR OUTCH
	INY
	CPY #SYMSZ
	BNE @LOOP2
	DEY		; Since #UNKSYM = #SYMSZ - 1
	BNE @DONE	; always branches
	
; ****************************************

ADDMOD:			; Check the arguments and work out the
			; addressing mode
			; return mode in X
	LDX #$FF	; default error value for mode
	STX CURADM	; save it
	LDA CURMNE
	LDX ARGS	; Start checking the format...
	BEQ @EOL
	CPX #SP
	BNE @NOTSP
@EOL:	CMP #$12	; check exception first - JSR
	BEQ @RET
	LDX #IMP	; implied mode - space
	JSR CHKMOD	; check command is ok with this mode
	CPX #FAIL	; not ok
	BEQ @NOTIMP	; may still be accumulator mode though
@RET:	RTS
@NOTIMP: LDX #ACC	; accumulator mode - space
	JMP CHKMOD	; check command is ok with this mode
@NOTSP:	CPX #IMV	; immediate mode - '#'
	BEQ @DOIMM
	LDX #REL
	JSR CHKMOD	; check if command is a branch
	CPX #FAIL
	BEQ @NOTREL
	LDA ARGS
	JMP DOREL
@DOIMM:	CMP #$2C	; check exception first - STA
	BEQ BAD
	LDX #IMM
	CMP #$35	; check inclusion - STX
	BEQ @IMMOK
	CMP #$22	; check inclusion - BIT
	BEQ @IMMOK
	JSR CHKMOD	; check command is ok with this mode
	CPX #FAIL
	BEQ @RET
@IMMOK:	STX CURADM	; handle immediate mode
	;LDX #01	; skip the '#'
	DEX		; X == IMM == 2
	JSR QTEVAL
	INX
	BEQ BAD
	LDA LVALH
	BNE BAD
	;LDX #IMM
	RTS
@NOTREL: LDX #0		; check the more complicated modes
	LDA ARGS
	CMP #OPEN	; indirection?
	BNE @CONT	; no
	INX		; skip the '('
@CONT:	JSR EVAL
	CPX #FAIL
	BEQ @RET
	JSR FMT2AM	; calculate the addressing mode from the format
	CPX #FAIL
	BEQ @RET
	STX CURADM
;	JMP CHKEXS
; falls through

; ****************************************

CHKEXS:			; Current addressing mode is in X
	CPX #ZPY	; for MNE indices 28 to 2F, ZPY is illegal
	BNE @CONT	; but ABY is ok, so promote byte argument to word
	LDA CURMNE
	CMP #$28
	BCC @CONT
	CMP #$2F+1
	BCS @CONT	
	LDX #ABY	; updated addressing mode
	BNE OK
@CONT:	LDY #SPCNT	; check special includes
@LOOP:	LDA SPINC1-1,Y	; load mnemonic code
	CMP CURMNE
	BNE @NEXT
	LDX SPINC2-1,Y	; load addressing mode
	CPX CURADM
	BEQ OK		; match - so ok
	LDX SPINC3-1,Y	; load addressing mode
	CPX CURADM
	BEQ OK		; match - so ok
@NEXT:	DEY
	BNE @LOOP
	LDX CURADM
;	BNE CHKMOD	; wasn't in the exceptions table - check normally
; falls through

; ****************************************

CHKMOD:	LDA CURMNE	; always > 0
	CMP MIN,X	; mode index in X
	BCC BAD		; mnemonic < MIN
	CMP MAX,X	; MAX,X holds actually MAX + 1
	BCS BAD		; mnemonic > MAX
OK:	STX CURADM	; save mode
	RTS
	
; ****************************************

BAD:	LDX #FAIL	; Illegal addressing mode error
	RTS
DOREL:	
	LDX #$00
	STX LVALL
	STX LVALH
	CMP #PC		; PC relative mode - '*'
	BNE DOLBL
	JSR PCTOLV
	JSR XCONT	
;	JMP ADDOFF	; just do an unnecessary EVAL and save 3 bytes
DOLBL:	JSR EVAL	; we have a label
ADDOFF:	SEC		; calculate relative offset as LVALL,H - PC
	LDA LVALL
	SBC CURPCL
	STA LVALL
	LDA LVALH
	SBC CURPCH
	STA LVALH
	BEQ DECLV	; error if high byte nonzero
	INC LVALH	
	BNE BAD		; need either $00 or $FF
DECLV:	DEC LVALL
	DEC LVALL
RELOK:	RTS		; need to end up with offset value in LVALL	
;ERROFF	LDX #FAIL
;	RTS
	
; ****************************************
	
QTEVAL:			; evaluate an expression possibly with a quote
	LDA ARGS,X
	BEQ BAD
	CMP #QUOTE
	BEQ QCHAR
	JMP EVAL
QCHAR:	INX
	LDA #$0
	STA LVALH	; quoted char must be a single byte
	LDA ARGS,X	; get the character
	STA LVALL
	INX		; check and skip the closing quote
	LDA ARGS,X	
	CMP #QUOTE
	BNE BAD
	INX
	LDA ARGS,X
	BEQ XDONE
	CMP #SP
	BEQ XDONE
;	JMP DOPLMN
; falls through

; ****************************************

DOPLMN:			; handle a plus/minus expression
			; on entry, A holds the operator, and X the location
			; store the result in LVALL,H
	PHA		; save the operator
	INX		; move forward
	LDA ARGS,X	; first calculate the value of the byte
	JSR BYT2HX
	CPX #FAIL
	BNE @CONT
	PLA
;	LDX #FAIL	; X is already $FF
@RET:	RTS
@CONT:	STA TEMP1	; store the value of the byte in TEMP1
	PLA
	CMP #PLUS
	BEQ @NONEG
	LDA TEMP1
	CLC		; for minus, need to negate it
	EOR #$FF
	ADC #$1
	STA TEMP1
@NONEG:	LDA HADFRF
	BEQ @SKIP
	LDA TEMP1	; save the offset for use when patching
	STA (MISCL),Y	
@SKIP:	;JMP ADD16X
; falls through

; ****************************************

ADD16X:			; Add a signed 8 bit number in TEMP1
			; to a 16 bit number in LVALL,H
			; preserve X (thanks leeeeee, www.6502.org/forum)
	LDA TEMP1	; signed 8 bit number
	BPL @CONT
	DEC LVALH	; bit 7 was set, so it's a negative
@CONT:	CLC	
	ADC LVALL
	STA LVALL	; update the stored number low byte
	BCC @EXIT
	INC LVALH	; update the stored number high byte
@EXIT:	RTS

; ****************************************

EVAL:			; Evaluate an argument expression
			; X points to offset from ARGS of the start
			; on exit we have the expression replaced 
			; by the required constant
	STX TEMP3	; store start of the expression
	LDA ARGS,X
	CMP #LOBYTE
	BEQ @HASOP
	CMP #HIBYTE
	BNE @DOLBL
@HASOP:	STA FRFLAG	; disables forward references when there
	INX		; is a '<' or a '>' in the expression
	LDA ARGS,X
@DOLBL:	JSR CHKLBL	; is there a label?
	BCS @LBL	; yes - get its value
	JSR CONVRT	; convert the ASCII
	CPX #FAIL
	BEQ XERR	
	BNE XCONT	
@LBL:	STX XSAV	; move X to Y
	JSR LB2VAL	; yes - get its value
	CPX #FAIL
	BEQ XDONE
	LDX XSAV
XCONT:	INX		; skip the '$'
	LDA ARGS,X	; Value now in LVALL,H for ASCII or LABEL
	JSR CHKLBL
	BCS XCONT	; Continue until end of label or digits
	;STX TEMP4	; Store end index
	CMP #PLUS
	BEQ @DOOP
	CMP #MINUS
	BNE XCHKOP
@DOOP:	JSR DOPLMN
	CPX #FAIL
	BNE XCONT
XERR:	LDY #SYNTAX	; argument syntax error
XDONE:	RTS	
XCHKOP:	LDY #$00
	LDA FRFLAG
	CMP #LOBYTE
	BEQ @GETLO
	CMP #HIBYTE
	BNE @STORE
	LDA LVALH	; move LVALH to LVALL
	STA LVALL
@GETLO:	STY LVALH	; keep LVALL, and zero LVALH
@STORE:	LDA ARGS,X	; copy rest of args to COMM
	STA COMM,Y
	BEQ @DOVAL	
	CMP #SP
	BEQ @DOVAL
	INX
	INY
	CPX #ARGSZ
	BNE @STORE
@DOVAL:	LDA #$00
	STA COMM,Y
	LDY TEMP3	; get start index 
	LDA #HEX	; put the '$" back in so subsequent code 
	STA ARGS,Y	; manages the value properly
	INY
	LDA LVALH
	BEQ @DOLO
	JSR HX2ASC
@DOLO:	LDA LVALL
	JSR HX2ASC
	LDX #$00	; bring back the rest from IOBUF
@COPY:	LDA COMM,X
	STA ARGS,Y	; store at offset Y from ARGS
	BEQ XDONE
	INX
	INY
	BNE @COPY	
		
; ****************************************

LB2VAL:			; label to be evaluated is in ARGS + X (X = 0 or 1)
	LDY #$00
@NEXT:	CPY #LBLSZ	; all chars done
	BEQ DOLVAL
	JSR CHKLBL	; has the label finished early?
	BCC @STOP
	STA COMM,Y	; copy because we need exactly 6 chars for the search
	INX		; COMM isn't used in parsing, so it
	LDA ARGS,X	; can be treated as scratch space
	INY		
	BNE @NEXT
@STOP:	LDA #SP		; label is in COMM - ensure filled with spaces
@LOOP:	STA COMM,Y	; Y still points to next byte to process 
	INY
	CPY #LBLSZ
	BNE @LOOP
DOLVAL:	LDA #<COMM	; now get value for the label
	STA STRL
	LDX #$00	; select global table (#>COMM)
	STX STRH
	LDA #SYMSZ
	STA RECSIG
	LDA #SYMSZ+2
	STA RECSZ	; size includes additional two bytes for value
	LDA COMM
	CMP #DOT
	BEQ @LOCAL	; local symbol
	JSR SYMSCH
	BEQ @FREF	; if not there, handle as a forward reference
@FOUND:	LDY #SYMSZ
	LDA (TBLL),Y	; save value
	STA LVALL
	INY
	LDA (TBLL),Y
	STA LVALH
	RTS	
@LOCAL:			; locals much the same
	LDX #$03	; select local table
	JSR SYMSCH
	BNE @FOUND	; if not there, handle as a forward reference
@FREF:	LDA FRFLAG	; set when patching
	BNE SYMERR	; can't add FREFs when patching
	JSR PCTOLV	; default value	to PC
	LDA FREFTH	; store it in the table
	STA MISCH
	LDA FREFTL	; Calculate storage address
	LDX NFREF
	BEQ @CONT	; no symbols to skip
@LOOP:	CLC		
	ADC #SYMSZ+3	; skip over existing symbols
	BCC @SKIP
	INC MISCH	; carry bit set - increase high pointer
@SKIP:	DEX
	BNE @LOOP
@CONT:	STA MISCL	; Reqd address is now in MISCL,H
	INC NFREF	; Update FREF count
	LDA NFREF
	CMP #MAXFRF	; Check for table full
	BPL OVFERR
	LDA #COMM
	STA HADFRF	; non-zero value tells that FREF was encountered
	STA MISC2L
	JSR STORE	; Store the symbol
	INY
	TXA		; X is zero after STORE
	STA (MISCL),Y	
	RTS		; No error		
	
; ****************************************
	
PCSYM:
	JSR PCTOLV
;	JMP STRSYM
	
; ****************************************
	
STRSYM:			; Store symbol - name at LABEL, value in MISC2L,H
	LDA #LABEL
	STA MISC2L
	STA STRL
	LDX #$00
	STX STRH
	LDA #SYMSZ
	STA RECSIG	
	LDA LABEL	; Global or local?
	CMP #DOT
	BNE @SRCH	; Starts with a dot, so local
	LDX #$03
@SRCH:	JSR SYMSCH
	BEQ STCONT	; Not there yet, so ok
@ERR:	PLA
	PLA
SYMERR:	LDY #UNKSYM	; missing symbol error
	BNE SBAD
	;LDX #FAIL
	;RTS
OVFERR:	LDY #OVRFLW	; Symbol table overflow	error
SBAD:	LDX #FAIL
	RTS
STCONT:	LDA #LABEL
	LDX LABEL	; Global or local?
	CPX #DOT
	BEQ @LSYM	; Starts with a dot, so local
	SEC		; Store symbol in global symbol table	
	LDA GSYMTL	; Make space for next symbol
	SBC #SYMSZ+2	; skip over existing symbols
	BCS @CONTG	; Reqd address is now in GSYMTL,H
@DWNHI:	DEC GSYMTH	; carry bit clear - decrease high pointer
@CONTG:	STA GSYMTL
	INC NGSYM	; Update Symbol count - overflow on 256 symbols
	BEQ OVFERR	; Check for table full
	STA MISCL	; put addres into MISCH,L for saving
	LDA GSYMTH
	STA MISCH
	BNE STORE	; Always branches - symbol tables cannot be on page zero
@LSYM:	LDA LSYMTH	; Store symbol in local symbol table	
	STA MISCH
	LDA LSYMTL	; Calculate storage address
	LDX NLSYM
	BEQ @CONTL	; no symbols to skip
@LOOP:	CLC
	ADC #SYMSZ+2	; skip over existing symbols
	BCC @SKIP
	INC MISCH
@SKIP:	DEX
	BNE @LOOP
@CONTL:	STA MISCL	; Reqd address is now in MISCL,H
	INC NLSYM	; Update Symbol count
	LDA NLSYM
	CMP #MAXSYM	; Check for table full
	BPL OVFERR
STORE:	LDY #0		; First store the symbol string
	STY MISC2H
   	LDX #SYMSZ
@MV:     LDA (MISC2L),Y 	; move bytes
    STA (MISCL),Y
    INY
    DEX
    BNE @MV
    LDA LVALL	; Now store the value WORD
	STA (MISCL),Y
	INY
    LDA LVALH
	STA (MISCL),Y
	RTS		; No error	
	
	
; ****************************************

CONVRT:	 		; convert an ASCII string at ARGS,X 
			; of the form $nnnn (1 to 4 digits)
			; return the result in LVALL,H, and preserves X and Y
			; uses COMM area for scratch space
	CMP #HEX	; syntax for hex constant
	BNE SBAD	; syntax error
	STY COMM+1
	JSR NBYTS
	CPX #FAIL
	BEQ SBAD
	STA COMM
	LDY #$00
	STY LVALH
@BACK:	DEX
	DEX
	LDA ARGS,X
	CMP #HEX
	BEQ @1DIG
	JSR BYT2HX
	SEC
	BCS @SKIP
@1DIG:	JSR AHARGS1	; one digit
@SKIP:	STA LVALL,Y
	INY
	CPY COMM
	BNE @BACK
@RET:	LDY COMM+1
	RTS
		
; ****************************************

SYMSCH:			; X = 0 for globals
			; X = 3 for locals
	LDA GSYMTL,X	; get global symbol value
	STA TBLL
	LDA GSYMTH,X
	STA TBLH
	LDA NGSYM,X	; Number of global symbols
	STA RECNM
	JSR SEARCH
	CPX #FAIL	; Z set if search failed
	RTS		; caller to check

; ****************************************

FMT2AM:			; calculate the addressing given
			; the format of the arguments; 
			; return format in X, and
			; location to CHKEXT from in A
			; $FF		invalid
			; #ZPG		$nn
			; #ZPX		$nn,X
			; #ZPY		$nn,Y
			; #ABS		$nnnn
			; #ABX		$nnnn,X
			; #ABY		$nnnn,Y
			; #IND		($nnnn)
			; #IDX		($nn,X)
			; #IDY		($nn),Y
			; #INZ		($nn)
			; #IAX		($nnnn,X)
;		
;	Addressing modes are organised as follows:
;
;	IMP (0)	ZPG (4) INZ (7) ABS (A) IND (D)
;	ACC (1) ZPX (5) INX (8) ABX (B) IAX (E)
;	IMM (2) ZPY (6) INY (9) ABY (C) ---
;	REL (3) ---	 ---	---	---
;
;	so algorithm below starts with 4, adds 3 if indirect
;	and adds 6 if absolute (i.e. 2 byte address), then adds 1 or 2
;	if ,X or ,Y format
;
	LDX #$00
	LDA #$04	; start with mode index of 4
	LDY ARGS,X
	CPY #OPEN
	BNE @SKIP
	CLC		; add 3 for indirect modes
	ADC #$03
	INX
@SKIP:	PHA	
	JSR NBYTS	; count bytes (1 or 2 only)
	TAY		; byte count in Y 
	DEX
	LDA CURMNE
	CMP #$12	; is it JSR?
	BEQ @JSR
	CMP #$38	; is it JMP?
	BNE @NOJMP
@JSR:	;LDY #$2		; force 2 bytes for these two situations
	INY		; following code treats Y = 3 the same as Y = 2
@NOJMP:	PLA		; mode base back in A
	INX		; check for NBYTS failure
	BEQ FERR
	DEY
	BEQ @1BYT
@2BYT:	CLC
	ADC #$06	; add 6 to base index for 2 byte modes
@1BYT:	TAY		; mode index now in Y
@CHECK:	LDA ARGS,X
	BEQ @DONE
	CMP #SP
	BNE @CONT
@DONE:	LDA ARGS
	CMP #OPEN	; brackets must match
	BEQ FERR
@RET:	CPY #$0F
	BPL FERR	; no indirect absolute Y mode
	TYA
	TAX
	RTS
@CONT:	CMP #CLOSE
	BNE @MORE
	LDA #SP
	STA ARGS	; erase brackets now they have
	INX
	LDA ARGS,X
	CMP #COMMA
	BNE @CHECK
@MORE:	LDA ARGS,X
	CMP #COMMA
	BNE FERR
	INX
	LDA ARGS,X
	CMP #'X'
	BEQ @ISX
@ISY:	CMP #'Y'
	BNE FERR
	LDA ARGS
	CMP #OPEN
	BEQ FERR
	STA ARGS-2,X	; to avoid ,X check below
	INY
@ISX:	INY
	LDA ARGS-2,X
	CMP #CLOSE
	BEQ FERR
	INX
	BNE @CHECK	; always
FERR:	LDX #FAIL	; error message generated upstream
FRET:	RTS
NBYTS:	LDY #$00	; count bytes using Y
@LOOP:	INX
	INY
	JSR AHARGS
	CMP #FAIL
	BNE @LOOP
@NEXT:	TYA
	LSR		; divide number by 2
	BEQ FERR	; zero is an error
	CMP #$03	; 3 or more is an error
	BCS FERR
@RET:	RTS		
	
; ****************************************
; *          Utility Routines            *
; ****************************************
	
SEARCH:			; TBLL,H has the address of the table to search
			; and address of record on successful return
			; STRL,H has the address of the search string
			; Search through RECNM records
			; Each of size RECSZ with RECSIG significant chars
	LDA RECNM
	BEQ FERR	; empty table
	LDX #$00	; Record number
@CHK1:	LDY #$FF	; Index into entry
@CHMTCH:	INY
	CPY RECSIG	; Have we checked all significant chars?
	BEQ FRET	; Yes
	LDA (TBLL),Y	; Load the bytes to compare
	CMP (STRL),Y
	BEQ @CHMTCH	; Check next if these match
	INX		; Else move to next record
	CPX RECNM
	BEQ FERR
	LDA TBLL	; Update address
	CLC
	ADC RECSZ
	STA TBLL
	BCC @CHK1
	INC TBLH	; Including high byte if necessary
	BCS @CHK1	; will always branch
;.FAIL	LDX #FAIL	; X = $FF indicates failure
;.MATCH	RTS		; got it - index is in X, address is in A and TBLL,H

; ****************************************

BYT2HX:			; convert the ASCII byte (1 or 2 chars) at offset X in
			; the args field to Hex
			; result in A ($FF for fail)
	
	JSR AHARGS	
	CMP #FAIL	; indicates conversion error		
	BEQ FERR
	PHA	
	JSR AHARGS1
	DEX
	CMP #FAIL
	BNE @CONT
	PLA		; just ignore 2nd character
	RTS
@CONT:	STA SCRTCH
	PLA
	ASL		; shift 
	ASL
	ASL
	ASL
	ADC SCRTCH
	RTS
	
; ****************************************

AHARGS1:	INX		; caller needs to DEX
AHARGS:	LDA ARGS,X
ASC2HX:			; convert ASCII code in A to a HEX digit
    	EOR #$30  
	CMP #$0A  
	BCC @VALID  
	ADC #$88        ; $89 - CLC  
	CMP #$FA  
	BCC @ERR  
	AND #$0F   
@VALID:	RTS
@ERR:	LDA #FAIL	; this value can never be from a single digit, 
	RTS		; so ok to indicate error
	
; ****************************************

HX2ASC:			; convert a byte in A into two ASCII characters
			; store in ARGS,Y and ARGS+1,Y
	PHA 		; 1st byte. 
	LSR
	LSR
	LSR
	LSR
	JSR DO1DIG
	PLA 
DO1DIG:	AND #$0F	; Print 1 hex digit
	ORA #$30
	CMP #$3A
	BCC @DONE
	ADC #$06
@DONE:	STA ARGS,Y
	INY
	RTS
	
; ****************************************
	
EXPMNE:			; copy the 2 chars at R/LMNETB,X
			; into LMNE and RMNE, and expand 
			; into 3 chars at MNE to MNE+2
	LDA LMNETB,X
	STA LMNE
	LDA RMNETB,X
	STA RMNE
	LDX #$00
@NEXT:	LDA #$00
	LDY #$05
@LOOP:	ASL RMNE
	ROL LMNE
	ROL
	DEY
	BNE @LOOP
	ADC #'A'-1
	STA MNE,X
	LDY PRFLAG
	BEQ @SKIP
	JSR OUTCH	; print the mnemonic as well
@SKIP:	INX
	CPX #$03
	BNE @NEXT
	RTS	

; ****************************************
;      		DISASSEMBLER
; Adapted from code in a Dr Dobbs article 
; by Steve Wozniak and Allen Baum (Sep '76)
; ****************************************
	
DISASM:	
	JSR ADDARG
	;BEQ .DODIS
	BEQ DSMBL
@COPY:	JSR LVTOPC
;.DODIS	JMP DSMBL
; fall through

; ****************************************

DSMBL:	
	;LDA #$13	; Count for 20 instruction dsmbly
	;STA COUNT
@DSMBL2:	JSR INSTDSP	; Disassemble and display instr.
	JSR PCADJ
	STA PCL		; Update PCL,H to next instr.
	STY PCH
	;DEC COUNT	; Done first 19 instrs
	;BNE @DSMBL2	; * Yes, loop.  Else DSMBL 20th
	
	LDA KBDRDY	; Now disassemble until key press

.if APPLE1	;L1
		BPL @DSMBL2
.else		;L1
		BEQ @DSMBL2
.endif		;L0

	LDA KBD

INSTDSP:	JSR PRPC	; Print PCL,H
	LDA (PCL,X)	; Get op code
	TAY   
	LSR   		; * Even/odd test
	BCC @IEVEN
	ROR  		; * Test B1
	BCS @ERR		; XXXXXX11 instr invalid
	;CMP #$A2	
	;BEQ ERR		; 10001001 instr invalid
	AND #$87	; Mask 3 bits for address mode
	;ORA #$80	; * add indexing offset
@IEVEN:	LSR   		; * LSB into carry for
	TAX   		; Left/right test below
	LDA MODE,X	; Index into address mode table
	BCC @RTMODE	; If carry set use LSD for
	LSR   		; * print format index
	LSR   		
	LSR   		; If carry clear use MSD
	LSR   
@RTMODE:	AND #$0F	; Mask for 4-bit index
	BNE @GETFMT	; $0 for invalid opcodes
@ERR:	LDY #$FC	; Substitute $FC for invalid op,
	LDA #$00	; set print format index to 0
@GETFMT:	TAX   
	LDA MODE2,X	; Index into print format table
	STA FORMAT	; Save for address field format
	AND #$03	; Mask 2-bit length.  0=1-byte
	STA LENGTH	; *  1=2-byte, 2=3 byte
	TYA   		; * op code
	JSR GETMNE
	LDY #$00
	PHA   		; Save mnemonic table index
@PROP:	LDA (PCL),Y
	JSR OUTHEX
	LDX #$01
@PROPBL:	JSR PRBL2
	CPY LENGTH	; Print instr (1 to 3 bytes)
	INY   		; *  in a 12-character field
	BCC @PROP
	LDX #$03	; char count for mnemonic print
	STX PRFLAG	; So EXPMNE prints the mnemonic
	CPY #$04
	BCC @PROPBL
	PLA   		; Recover mnemonic index
	TAX
	JSR EXPMNE
	JSR PRBLNK	; Output 3 blanks
	LDY LENGTH
	LDX #$06	; Count for 6 print format bits
@PPADR1:	CPX #$03
	BEQ @PPADR5	; If X=3 then print address val
@PPADR2:	ASL FORMAT	; Test next print format bit
	BCC @PPADR3	; If 0 don't print
	LDA CHAR1-1,X	; *  corresponding chars
	JSR OUTCH	; Output 1 or 2 chars
	LDA CHAR2-1,X	; *  (If char from char2 is 0,
	BEQ @PPADR3	; *   don't output it)
	JSR OUTCH
@PPADR3:	DEX   
	BNE @PPADR1
	STX PRFLAG	; reset flag to 0
	RTS  		; Return if done 6 format bits
@PPADR4:	DEY
	BMI @PPADR2
	JSR OUTHEX	; Output 1- or 2-byte address
@PPADR5:	LDA FORMAT
	CMP #$E8	; Handle rel addressing mode
	LDA (PCL),Y	; Special print target adr
	BCC @PPADR4	; *  (not displacement)
@RELADR:	JSR PCADJ3	; PCL,H + DISPL + 1 to A,Y
	TAX   
	INX   
	BNE PRNTYX	; *     +1 to X,Y
	INY   
PRNTYX:	TYA   
PRNTAX:	JSR OUTHEX	; Print target adr of branch
PRNTX:	TXA   		; *  and return
	JMP OUTHEX
PRPC:	JSR CRLF	; Output carriage return
	LDA PCH
	LDX PCL
	JSR PRNTAX	; Output PCL and PCH
PRBLNK:	LDX #$03	; Blank count
PRBL2:	JSR OUTSP	; Output a blank
	DEX   
	BNE PRBL2	; Loop until count = 0
	RTS   
PCADJ:	SEC
PCADJ2:	LDA LENGTH	; 0=1-byte, 1=2-byte, 2=3-byte
PCADJ3:	LDY PCH	
	TAX   		; * test displ sign (for rel
	BPL @PCADJ4	; *  branch).  Extend neg
	DEY   		; *  by decrementing PCH
@PCADJ4:	ADC PCL
	BCC @RTS	; PCL+LENGTH (or displ) + 1 to A
	INY   		; *  carry into Y (PCH)
@RTS:	RTS 
	
; lookup table for disassembly special cases
TBLSZ	= $1A
DISTBL:	.byte $80, $41, $4C, $38, $6C, $38, $7C, $38
	.byte $0A, $30, $2A, $31, $4A, $32, $6A, $33
	.byte $9C, $23, $9E, $23, $04, $20, $0C, $20
	.byte $89, $22
	
; Get the MNE index using the following rules:
; 	- lookup awkward cases in a lookup table (DISTBL)
;	- consider opcodes by category:
;		1: nnnn1000 -> nnnn
;		2: nnn10000 -> nnn + BPL
;		3: nnnn1010 or 0nn00000 -> BRK + nnnn(0nn0)
;		4: change nnnX0010 to nnnX0001
;		5: nnnXXXab -> 001abnnn if >= 23
;		6: 001abnnn + 1 otherwise
	
GETMNE:			; get mnemonic index for opcode in A
			; on completion, A holds the index 
			; into the mnemonic table
	STA TEMP1	; will need it later
	LDX #TBLSZ	; check lookup table first
@LOOP:	LDA DISTBL-2,X
	CMP TEMP1
	BNE @SKIP
	LDA DISTBL-1,X	; got it
	RTS
@SKIP:	DEX
	DEX
	BNE @LOOP
	LDA TEMP1	
	LSR
	LSR
	LSR
	LSR
	STA TEMP2	; save the high nibble
	LDA TEMP1
	AND #$0F
	CMP #$08
	BNE @NOTC1
	LDA TEMP2	; high nibble is our index
	RTS
@NOTC1:	LDA TEMP1
	AND #$1F
	CMP #$10
	BNE @NOTC2
	LDA TEMP2
	LSR
	ADC #$39-1	; since carry is set
	RTS
@NOTC2:	LDA TEMP1
	AND #$9F
	BEQ @DOC3
	AND #$0F
	CMP #$0A
	BNE @NOTC3
@DOC3:	LDA TEMP2
	CLC
	ADC #$10
	RTS
@NOTC3:	LDX TEMP1	; does this code end in 10010?
	TXA
	AND #$1F
	CMP #$12
	BNE @1
	DEX
@1:	TXA		; ? ABCD EFGH - thanks bogax, www.6502.org/forum
	ASL		; A BCDE FGH0
	ADC #$80	; B ?CDE FGHA
	ROL		; ? CDEF GHAB
	ASL		; C DEFG HAB0
	AND #$1F	; C 000G HAB0
	ADC #$20	; 0 001G HABC
	CMP #$23
	BMI @NOTC5
	RTS
@NOTC5:	TAX
	INX
	TXA
	RTS
		
; Data and related constants

MODES:			; Addressing mode constants
IMP = $00
ACC = $01
IMM = $02		; #$nn or #'<char>' or #LABEL
REL = $03		; *+nn or LABEL
ZPG = $04		; $nn or LABEL
ZPX = $05		; $nn,X or LABEL,X
ZPY = $06		; $nn,Y or LABEL,Y
IDZ = $07		; ($nn) or (LABEL)
IDX = $08		; ($nn,X) or (LABEL,X)
IDY = $09		; ($nn),Y or (LABEL),Y
ABS = $0A		; $nnnn or LABEL
ABX = $0B		; $nnnn,X or LABEL,X
ABY = $0C		; $nnnn or LABEL
IND = $0D		; ($nnnn) or (LABEL)
IAX = $0E		; ($nnnn,X) or (LABEL,X)

NUMMN 	=$42		; number of mnemonics

; Tables

LMNETB:		
	.byte $82	; PHP
	.byte $1B	; CLC
	.byte $83	; PLP
	.byte $99	; SEC
	.byte $82	; PHA
	.byte $1B	; CLI
	.byte $83	; PLA
	.byte $99	; SEI
	.byte $21	; DEY
	.byte $A6	; TYA
	.byte $A0	; TAY
	.byte $1B	; CLV
	.byte $4B	; INY
	.byte $1B	; CLD
	.byte $4B	; INX
	.byte $99	; SED
	.byte $14	; BRK
	.byte $21	; DEA
	.byte $54	; JSR
	.byte $4B	; INA
	.byte $95	; RTI
	.byte $82	; PHY
	.byte $95	; RTS
	.byte $83	; PLY
	.byte $A6	; TXA
	.byte $A6	; TXS
	.byte $A0	; TAX
	.byte $A4	; TSX
	.byte $21	; DEX
	.byte $82	; PHX
	.byte $73	; NOP
	.byte $83	; PLX
	.byte $A4	; TSB
	.byte $A4	; TRB
	.byte $12	; BIT
	.byte $9D	; STZ
	.byte $9D	; STY
	.byte $61	; LDY
	.byte $1C	; CPY
	.byte $1C	; CPX
	.byte $7C	; ORA
	.byte $0B	; AND
	.byte $2B	; EOR
	.byte $9	; ADC
	.byte $9D	; STA
	.byte $61	; LDA
	.byte $1B	; CMP
	.byte $98	; SBC
	.byte $0C	; ASL
	.byte $93	; ROL
	.byte $64	; LSR
	.byte $93	; ROR
	.byte $9D	; STX
	.byte $61	; LDX
	.byte $21	; DEC
	.byte $4B	; INC
	.byte $53	; JMP
	.byte $14	; BPL
	.byte $13	; BMI
	.byte $15	; BVC
	.byte $15	; BVS
	.byte $10	; BCC
	.byte $10	; BCS
	.byte $13	; BNE
	.byte $11	; BEQ
	.byte $14	; BRA
RMNETB:
	.byte $20	; PHP
	.byte $06	; CLC
	.byte $20	; PLP
	.byte $46	; SEC
	.byte $02	; PHA
	.byte $12	; CLI
	.byte $02	; PLA
	.byte $52	; SEI
	.byte $72	; DEY
	.byte $42	; TYA
	.byte $72	; TAY
	.byte $2C	; CLV
	.byte $B2	; INY
	.byte $08	; CLD
	.byte $B0	; INX
	.byte $48	; SED
	.byte $96	; BRK
	.byte $42	; DEA
	.byte $E4	; JSR
	.byte $82	; INA
	.byte $12	; RTI
	.byte $32	; PHY
	.byte $26	; RTS
	.byte $32	; PLY
	.byte $02	; TXA
	.byte $26	; TXS
	.byte $70	; TAX
	.byte $F0	; TSX
	.byte $70	; DEX
	.byte $30	; PHX
	.byte $E0	; NOP
	.byte $30	; PLX
	.byte $C4	; TSB
	.byte $84	; TRB
	.byte $68	; BIT
	.byte $34	; STZ
	.byte $32	; STY
	.byte $32	; LDY
	.byte $32	; CPY
	.byte $30	; CPX
	.byte $82	; ORA
	.byte $88	; AND
	.byte $E4	; EOR
	.byte $06	; ADC
	.byte $02	; STA
	.byte $02	; LDA
	.byte $60	; CMP
	.byte $86	; SBC
	.byte $D8	; ASL
	.byte $D8	; ROL
	.byte $E4	; LSR
	.byte $E4	; ROR
	.byte $30	; STX
	.byte $30	; LDX
	.byte $46	; DEC
	.byte $86	; INC
	.byte $60	; JMP
	.byte $18	; BPL
	.byte $52	; BMI
	.byte $86	; BVC
	.byte $A6	; BVS
	.byte $C6	; BCC
	.byte $E6	; BCS
	.byte $8A	; BNE
	.byte $62	; BEQ
	.byte $82	; BRA
	
MIN:			; Minimum legal value for MNE for each mode.
	.byte $00, $30, $25, $39
	.byte $20, $28, $34
	.byte $28, $28, $28
	.byte $20, $28, $28
	.byte $38, $38
MAX:			; Maximum +1 legal value of MNE for each mode. 
	.byte $1F+1, $33+1, $2F+1, $41+1
	.byte $37+1, $33+1, $35+1
	.byte $2F+1, $2F+1, $2F+1
	.byte $38+1, $33+1, $2F+1
	.byte $38+1, $38+1
BASE:			; Base value for each opcode
	.byte $08, $18, $28, $38
	.byte $48, $58, $68, $78
	.byte $88, $98, $A8, $B8
	.byte $C8, $D8, $E8, $F8
	.byte $00, $1A, $14, $3A
	.byte $40, $5A, $60, $7A
	.byte $8A, $9A, $AA, $BA
	.byte $CA, $DA, $EA, $FA	
	.byte $00, $10, $20, $60
	.byte $80, $A0, $C0, $E0
	.byte $01, $21, $41, $61
	.byte $81, $A1, $C1, $E1
	.byte $02, $22, $42, $62
	.byte $82, $A2, $C2, $E2
	.byte $40, $10, $30, $50
	.byte $70, $90, $B0, $D0
	.byte $F0, $80
OFFSET:			; Default offset values for each mode, 
			; added to BASE to get the opcode
	.byte $00, $08, $00, $00
	.byte $04, $14, $14
	.byte $11, $00, $10
	.byte $0C, $1C, $18
	.byte $2C, $3C


; offset adjustments for the mnemonic exceptions
ADJABY  =$04
ADJIMM  =$08
ADJBIT	=$68
ADJSTZ	=$D0
	
; disassembler data

; XXXXXXZ0 instrs
; * Z=0, right half-byte
; * Z=1, left half-byte
MODE:	.byte $0F, $22, $FF, $33, $CB
	.byte $62, $FF, $73, $03, $22
	.byte $FF, $33, $CB, $66, $FF
	.byte $77, $0F, $20, $FF, $33
	.byte $CB, $60, $FF, $70, $0F
	.byte $22, $FF, $39, $CB, $66
	.byte $FF, $7D, $0B, $22, $FF
	.byte $33, $CB, $A6, $FF, $73
	.byte $11, $22, $FF, $33, $CB
	.byte $A6, $FF, $87, $01, $22
	.byte $FF, $33, $CB, $60, $FF
	.byte $70, $01, $22, $FF, $33
	.byte $CB, $60, $FF, $70
; YYXXXZ01 instrs
	.byte $24, $31, $65, $78
	
MODE2:	.byte $00	; ERR
	.byte $21	; IMM
	.byte $81	; Z-PAG
	.byte $82	; ABS
	.byte $59	; (Z-PAG,X)
	.byte $4D	; (Z-PAG),Y
	.byte $91	; Z-PAG,X
	.byte $92	; ABS,X
	.byte $86	; ABS,Y
	.byte $4A	; (ABS)
	.byte $85	; Z-PAG,Y
	.byte $9D	; REL
	.byte $49	; (Z-PAG)
	.byte $5A	; (ABS,X)
CHAR2:	.byte 'Y'
	.byte $00	
	.byte 'X'
	.byte '$'
	.byte '$'
	.byte $00
CHAR1:	.byte ','
	.byte ')'
	.byte ','
	.byte '#'
	.byte '('
	.byte '$'
; Special case mnemonics	
SPCNT	= $08		; duplicate some checks so I can use the same loop above
; Opcodes
SPINC1:	.byte $12, $22, $23, $24, $25, $35, $36, $37
; 1st address mode to check
SPINC2:	.byte $0A, $0B, $0B, $05, $0B, $0C, $0B, $0B
; 2nd address mode to check
SPINC3:	.byte $0A, $05, $05, $05, $05, $0C, $05, $05
	
; commands

NUMCMD	=$0D
CMDS:	.ASCIIZ "NLXEMRDI!$AVP"  ;GAK...was ASCII

N1 = NEW-1
L1 = LIST-1
D1 = DELETE-1
E1 = EDIT-1
M1 = MEM-1
R1 = RUN-1
DIS1 = DISASM-1
I1 = INSERT-1
GL1 = GETLINE-1
MON1 = MONTOR-1
A1 = ASSEM-1
V1 = VALUE-1
P1 = PANIC-1

CMDH:	.byte	>N1
	.byte	>L1
	.byte	>D1
	.byte	>E1
	.byte	>M1
	.byte	>R1
	.byte	>DIS1
	.byte	>I1
	.byte	>GL1
	.byte	>MON1
	.byte	>A1
	.byte	>V1
	.byte	>P1

CMDL:	.byte	<N1
	.byte	<L1
	.byte	<D1
	.byte	<E1
	.byte	<M1
	.byte	<R1
	.byte	<DIS1
	.byte	<I1
	.byte	<GL1
	.byte	<MON1
	.byte	<A1
	.byte	<V1
	.byte	<P1

; Assembler directives - all entered with a leading '.'

BYTE 	='B'		; bytes
WORD	='W'		; word
STR	='S'		; string
EQU	='='		; equate
MOD	='M'		; start address for subsequent module

NUMDIR	=$05
DIRS:	.asciiz "BWS=M"   ;GAK...was .ascii

; Errors

UNKERR	=$00
INVMNE	=$01		; Invalid mnemonic
ILLADM	=$02		; Illegal addressing mode
SYNTAX	=$03		; Syntax error
OVRFLW	=$04		; Symbol table overflow
UNKSYM	=$05		; Unknown or duplicate symbol error
MAXERR	=$06

EMSGSZ	=$03		; The size of the error message strings
ERPRSZ	=$05		; The size of the error prefix string
ERRPRE:	.asciiz " :RRE"   ;GAK...was .ascii
ERRMSG:
.if UNK_ERR_CHECK	;L1
	.asciiz "UNK" ;GAK...was .ascii
.endif				;L0
	.asciiz "MNE" ;GAK...was .ascii
	.asciiz "ADD" ;GAK...was .ascii
	.asciiz "SYN" ;GAK...was .ascii
	.asciiz "OVF" ;GAK...was .ascii
	.asciiz "SYM" ;GAK...was .ascii
	
MSGSZ = $21
;MSG	.ascii "3.1 NESSEW NEK YB 20C56 REDASURK",CR
MSG:	.asciiz "3.1 NESSEW NEK YB 20C56 REDASURK"  ;GAK...was .ascii

.if MINIMONITOR	;L1
	; ****************************************
	;      		MINIMONITOR
	; A simple monitor to allow viewing and
	; altering of registers, and changing the PC
	; ****************************************
		
	NREGS	=$5
	DBGCMD:	.asciiz "PSYXALH"  ;GAK...was .ascii
	NDBGCS	=NREGS+2
	FLAGS:	.asciiz "CZIDB" ;GAK...was .ascii
		.byte $00	; A non-printing character - this flag always on
		.asciiz "VN"  ;GAK...was .ascii

	DEBUG:	
		STA SAVA
		STX SAVX
		STY SAVY
		PLA
		STA SAVP
		CLD
		PLA
		.if !BRKAS2	;L2
			SEC
			SBC #$1	
		.endif		;L1
		STA PCL
		PLA
		.if !BRKAS2	;L2
			SBC #$0
		.endif		;L1
		STA PCH
	@SKIP:	TSX
		STX SAVS
	SHOW:	JSR CRLF
		LDX #NREGS
	@LOOP:	LDA DBGCMD-1,X
		JSR OUTCH
		JSR PRDASH
		LDA REGS-1,X
		JSR OUTHEX
		JSR OUTSP
		DEX
		BNE @LOOP
		LDA SAVP	; show the flags explicitly as well
		LDX #$08
	@NEXT:	ASL
		BCC @SKIP
		PHA
		LDA FLAGS-1,X
		JSR OUTCH
		PLA
	@SKIP:	DEX
		BNE @NEXT
		JSR INSTDSP
	GETCMD:	JSR CRLF
		JSR PRDASH
		JSR GETCH1
		LDY #NDBGCS
	@LOOP:	CMP DBGCMD-1,Y
		BEQ DOCMD	; if we've found a PC or register change command, then run it
		DEY
		BNE @LOOP
		CMP #'R'	; resume?
		BEQ RESTOR
			CMP #'!'	; MONITOR COMMAND
			BNE @MON
			JSR GETLINE
			JMP SHOW
	@MON:	CMP #'$'	; monitor?
		BNE GETCMD
		JMP MONTOR
	RESTOR:	JSR CRLF
		LDX SAVS
		TXS
		LDX SAVX
		LDY SAVY
		LDA SAVP
		PHA
		PLP	
		LDA SAVA
		CLI		; enable interrupts again
	@RET:	JMP (PCL)	; Simulate the return so we can more easily manipulate the stack
	DOCMD:	LDX #$FE
	@LOOP:	JSR GETCH1
		STA ARGS+2,X
		INX
		BNE @LOOP
		JSR BYT2HX
		STA REGS-1,Y
		SEC
		BCS SHOW
.endif	;MINIMONITOR	;L0
	
; ****************************************
; I/O routines
; ****************************************

PRDASH:	
	LDA #MINUS
	JMP OUTCH
	
; ****************************************
	
.if MINIMONITOR	;L1
	GETCH1:	JSR GETCH
		JMP OUTCH
.endif			;L0

; ****************************************

SHWMOD:			; Show name of module being assembled
	JSR CRLF
	LDX #$00
@LOOP2:	LDA LABEL,X
	JSR OUTCH
	INX
	CPX #LBLSZ
	BNE @LOOP2
	JSR OUTSP
;	JMP PRLNNM	; falls through
	
; ****************************************	

PRLNNM:
	LDA LINEH
	JSR PRHEX
	LDA LINEL
	JSR OUTHEX
	;JMP OUTSP
; falls through

OUTSP:	
	LDA #SP
	JMP OUTCH
	
CRLF:			; Go to a new line.
	LDA #CR		; "CR"
.if APPLE1	;L1
		JMP OUTCH
.else		;L1
		JSR OUTCH
		LDA #LF		; "LF" - is this needed for the Apple 1?
		JMP OUTCH
.endif		;L0

GETCH:   		; Get a character from the keyboard.
; GAK -- commented this whole section and added JSR for my monitor routine
;	LDA KBDRDY
;.if APPLE1	;L
;		BPL GETCH
;		LDA KBD
;		AND #INMASK
;.else		;L1
;		BEQ GETCH
;.endif		;L0
	JSR RDKEY
	RTS
	
;-------------------------------------------------------------------------
;
;  The WOZ Monitor for the Apple 1
;  Written by Steve Wozniak 1976
;  Minor adjustments by Ken Wessen to support the minimonitor ! command
;  Standard entry points are unchanged
;
;-------------------------------------------------------------------------

.if INROM	;L1

	BSA1			=     '_';$08		; backspace

	XAML            =     $24             ;  Last "opened" location Low
	XAMH            =     $25             ;  Last "opened" location High
	STL             =     $26             ;  Store address Low
	STH             =     $27             ;  Store address High
	L               =     $28             ;  Hex value parsing Low
	H               =     $29             ;  Hex value parsing High
	YSAVM           =     $2A             ;  Used to see if hex value is given
	MODEM           =     $2B             ;  $00=XAM, $7F=STOR, $AE=BLOCK XAM

	IN              =     $0200           ;  Input buffer to $027F

	;KBD             =     $D010           ;  PIA.A keyboard input
	;KBDCR           =     $D011           ;  PIA.A keyboard control register
	DSP             =     $D012           ;  PIA.B display output register
	DSPCR           =     $D013           ;  PIA.B display control register

	MONPROMPT       =     '\'             ;  Prompt character

					;.ORG     $FF00
					
	RESET:          CLD                   ;  Clear decimal arithmetic mode
					CLI
					LDY     #$7F	      ;  Mask for DSP data direction reg
					STY     DSP           ;   (DDR mode is assumed after reset)
					LDA     #$A7          ;  KBD and DSP control register mask
					STA     KBDRDY        ;  Enable interrupts, set CA1, CB1 for
					STA     DSPCR         ;   positive edge sense/output mode.

	ESCAPE:         LDA     #MONPROMPT       ;  Print prompt character
					JSR     OUTCH         ;  Output it.
	GET:            ;JSR 	CRLF 
					JSR 	GETLINE
					BCC 	ESCAPE
					BCS 	GET
	GETLINE:        JSR 	CRLF
					LDY     #0+1          ;  Start a new input line
	BACKSPACE:      DEY                   ;  Backup text index
					BMI     GETLINE       ;  Oops, line's empty, reinitialize
	NEXTCHAR:       JSR 	GETCH1
			STA     IN,Y          ;  Add to text buffer
					CMP     #CR
					BEQ 	@CONT
			CMP     #BSA1         ;  Backspace key?
					BEQ     BACKSPACE     ;  Yes
					CMP     #ESC          ;  ESC?
					BEQ     ESCAPE        ;  Yes
					INY                   ;  Advance text index
					BPL     NEXTCHAR      ;  Auto ESC if line longer than 127
	@CONT:				      ;  Line received, now let's parse it
					LDY     #-1+256           ;  Reset text index  ;GAK added 256
					LDA     #0            ;  Default mode is XAM
					TAX                   ;  X=0
	SETSTOR:        ASL                   ;  Leaves $7B if setting STOR mode
	SETMODE:        STA     MODEM         ;  Set mode flags
	BLSKIP:         INY                   ;  Advance text index
	NEXTITEM:       LDA     IN,Y          ;  Get character
					CMP     #CR
					BNE 	@CONT
					SEC
					RTS           
	@CONT:          ORA 	#$80
					CMP     #'.'+$80
					BCC     BLSKIP        ;  Ignore everything below "."!
					BEQ     SETMODE       ;  Set BLOCK XAM mode ("." = $AE)
					CMP     #':'+$80
					BEQ     SETSTOR       ;  Set STOR mode! $BA will become $7B
					CMP     #'R'+$80
					BEQ     RUNM          ;  Run the program! Forget the rest
					STX     L             ;  Clear input value (X=0)
					STX     H
					STY     YSAVM          ;  Save Y for comparison
	NEXTHEX:        LDA     IN,Y          ;  Get character for hex test
					EOR     #$30          ;  Map digits to 0-9
					CMP     #$0A          ;  Is it a decimal digit?
					BCC     DIG           ;  Yes!
					ADC     #$88          ;  Map letter "A"-"F" to $FA-FF
					CMP     #$FA          ;  Hex letter?
					BCC     NOTHEX        ;  No! Character not hex
	DIG:            ASL
					ASL                   ;  Hex digit to MSD of A
					ASL
					ASL
					LDX     #4            ;  Shift count
	HEXSHIFT:       ASL                   ;  Hex digit left, MSB to carry
					ROL     L             ;  Rotate into LSD
					ROL     H             ;  Rotate into MSD's
					DEX                   ;  Done 4 shifts?
					BNE     HEXSHIFT      ;  No, loop
					INY                   ;  Advance text index
					BNE     NEXTHEX       ;  Always taken
	NOTHEX:         CPY     YSAVM         ;  Was at least 1 hex digit given?
					BNE 	@CONT
					CLC		      ;  No! Ignore all, start from scratch
					RTS
	@CONT:			BIT     MODEM         ;  Test MODE byte
					BVC     NOTSTOR       ;  B6=0 is STOR, 1 is XAM or BLOCK XAM
					LDA     L             ;  LSD's of hex data
					STA     (STL,X)       ;  Store current 'store index'(X=0)
					INC     STL           ;  Increment store index.
					BNE     NEXTITEM      ;  No carry!
					INC     STH           ;  Add carry to 'store index' high
	TONEXTITEM:     JMP     NEXTITEM      ;  Get next command item.
	RUNM:           JMP     (XAML)        ;  Run user's program
	NOTSTOR:        BMI     XAMNEXT       ;  B7 = 0 for XAM, 1 for BLOCK XAM
					LDX     #2            ;  Copy 2 bytes
	SETADR:         LDA     L-1,X         ;  Copy hex data to
					STA     STL-1,X       ;   'store index'
					STA     XAML-1,X      ;   and to 'XAM index'
					DEX                   ;  Next of 2 bytes
					BNE     SETADR        ;  Loop unless X = 0
	NXTPRNT:        BNE     PRDATA        ;  NE means no address to print
					JSR 	CRLF
					LDA     XAMH          ;  Output high-order byte of address
					JSR     OUTHEX
					LDA     XAML          ;  Output low-order byte of address
					JSR     OUTHEX
					LDA     #':'          ;  Print colon
					JSR     OUTCH
	PRDATA:         JSR 	OUTSP
					LDA     (XAML,X)      ;  Get data from address (X=0)
					JSR     OUTHEX        ;  Output it in hex format
	XAMNEXT:        STX     MODEM         ;  0 -> MODE (XAM mode).
					LDA     XAML          ;  See if there's more to print
					CMP     L
					LDA     XAMH
					SBC     H
					BCS     TONEXTITEM    ;  Not less! No more data to output
					INC     XAML          ;  Increment 'examine index'
					BNE     MOD8CHK       ;  No carry!
					INC     XAMH
	MOD8CHK:        LDA     XAML          ;  If address MOD 8 = 0 start new line
					AND     #$07
					BPL     NXTPRNT       ;  Always taken.
	
		.if APPLE1		;L2
			; Apple 1 I/O values
			KBD     =$D010		; Apple 1 Keyboard character read.
			KBDRDY  =$D011		; Apple 1 Keyboard data waiting when negative.

;				.ORG $FFDC
			OUTHEX:	PHA 		; Print 1 hex byte. 
				LSR
				LSR 
				LSR
				LSR 
				JSR PRHEX
				PLA 
			PRHEX:	AND #$0F	; Print 1 hex digit
				ORA #$30
				CMP #$3A
				BCC OUTCH
				ADC #$06
			OUTCH:	BIT DSP         ;  DA bit (B7) cleared yet?
					BMI OUTCH       ;  No! Wait for display ready
					STA DSP         ;  Output character. Sets DA
					RTS
		.else	;L2
			IOMEM	=$E000
			PUTCH	=IOMEM+1
			KBD		=IOMEM+4
			KBDRDY  =IOMEM+4

;				.ORG $FFDC
			OUTHEX:	
				PHA 			; Print 1 hex byte. 
				LSR
				LSR 
				LSR
				LSR 
				JSR PRHEX
				PLA 
			PRHEX:	AND #$0F	; Print 1 hex digit
				ORA #$30
				CMP #$3A
				BCC OUTCH
				ADC #$06
			OUTCH:	; GAK   --STA PUTCH
				JSR COUT
				RTS  
		.ENDIF  ;L1
		
;		.if MINIMONITOR	;L2
;			.ORG $FFFA	; INTERRUPT VECTORS
;			.WORD $0F00
;			.WORD RESET
;			.WORD DEBUG
;		.ENDIF			;L1
	
	.ELSE	;L1 - begin not in ROM
		; Apple 1 I/O values
		OUTCH	=$FFEF		; Apple 1 Echo
		PRHEX	=$FFE5		; Apple 1 Echo
		OUTHEX	=$FFDC		; Apple 1 Print Hex Byte Routine
		KBD     =$D010		; Apple 1 Keyboard character read.
		KBDRDY  =$D011		; Apple 1 Keyboard data waiting when negative.
	.ENDIF	; ;L0   inrom

;-------------------------------------------------------------------------
; CORE IO HANDLING ROUTINES
;-------------------------------------------------------------------------
.segment "IOHANDLER"
;.org $FF00

COUT:	PHA
ACIAWAIT:	LDA ACIAStatus
	AND #2			;MASK TDRE 
	CMP #2
	BNE ACIAWAIT
	PLA
	STA ACIAData
	RTS

MONRDKEY: LDA ACIAStatus
	AND #1			;MASK RDRF
	CMP #1
	BNE NoDataIn
	LDA ACIAData
	SEC				; Carry set if key available
	RTS
NoDataIn:	CLC		; Carry clear if no key pressed
	RTS

RDKEY:
	JSR	MONRDKEY	;Check if key was pressed
	BCC RDKEY		;If not, check again
	RTS

;-------------------------------------------------------------------------
;  Vector area
;-------------------------------------------------------------------------
.segment "VECTS"
;.org $FFFA

	.word MAIN		;NMI 
	.word MAIN		;RESET 
	.word MAIN		;IRQ 	