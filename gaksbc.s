;GAKMON v1.0 - 6502 Monitor

.debuginfo +
.setcpu "6502"

;GENERAL EQUATES
ACIA 		:= $A000	;BASE ADDRESS OF THE MC68B50P
ACIAControl 	:= ACIA+0	; Set operational parameters (w)     
ACIAStatus 	:= ACIA+0	; Indicates if char has been received (r)
ACIAData 		:= ACIA+1	; Data being recieved (r) or sent (w)

;-------------------------------------------------------------------------
;  Memory declaration
;-------------------------------------------------------------------------

XAML		= $10		;LAST "OPENED" LOCATION LOW
XAMH		= $11		;LAST "OPENED" LOCATION HIGH
STL		= $12		;STORE ADDRESS LOW
STH		= $13		;STORE ADDRESS HIGH
L		= $14		;HEX VALUE PARSING LOW
H		= $15		;HEX VALUE PARSING HIGH
YSAV		= $16		;USED TO SEE IF HEX VALUE IS GIVEN
MODE		= $17		;$00=XAM, $7F=STOR, $AE=BLOCK XAM
MSGL		= $18		;MSG START ADDRESS
MSGH		= $19		;MSG END ADDRESS

IN		= $200		;INPUT BUFFER

;-------------------------------------------------------------------------
;  Constants
;-------------------------------------------------------------------------

BS		= $08		;CODE-BACKSPACE KEY
CR		= $0D		;CODE-CARRIAGE RETURN
LF		= $0A 		;CODE-LINE FEED
ESC		= $1B		;CODE-ESC KEY
PROMPT		= '\'		;PROMPT
STACK_TOP		= $FF		;TOP OF THE STACK

.segment "CODE"
.org $C000

RESET:
	CLD	                    ; clear decimal mode
	LDX #STACK_TOP
	TXS
	LDA #$95      		;Set ACIA:CLK/16,8-bits,1 stop
				; RTS low TX INT disabled
	STA ACIAControl

;DISPLAY WELCOME MESSAGE
	LDA #<MSG1		;DETERMINE LOW
	STA MSGL			;SET LOW
	LDA #>MSG1		;DETERMINE HI
	STA MSGH			;SET HI
   	JSR SHWMSG		;SHOW WELCOME

;-------------------------------------------------------------------------
; The GETLINE process
;-------------------------------------------------------------------------

SFTRST:	LDA #ESC       		;AUTO ESCAPE
NOTCR:	CMP #BS        		;BACKSPACE KEY?
	BEQ BAKSPACE   		;YES
	CMP #ESC       		;ESC?
	BEQ ESCAPE     		;YES
	INY            		;ADVANCE TEXT INDEX
	BPL NEXTCHAR   		;IF LINE LONGER THAN 127 FALL THRU

ESCAPE:	LDA #PROMPT    		;PRINT PROMPT CHARACTER
	JSR ECHO       		;OUTPUT IT

GETLINE:  JSR CRLF			;SEND CRLF TO SCREEN

	LDY #$01       		;INITIALIZE TEXT INDEX
BAKSPACE: DEY
	BMI GETLINE    		;REINIT BEYOND START OF LINE
	LDA #' '       		;SPACE, OVERWITE CHAR
	JSR ECHO
	LDA #BS        		;BACKSPACE AGAIN
	JSR ECHO

NEXTCHAR: JSR RDKEY      		;WAIT FOR KEYPRESS
	STA IN,Y       		;ADD TO TEXT BUFFER
	JSR ECHO       		;DISPLAY CHARACTER
	;JSR PRBYTE    		;DEBUG - PRINT HEX KEYVALUE
	CMP #CR        		;CR?
	BNE NOTCR      		;NO.

;LINE RECEIVED, NOW LET'S PARSE IT

	LDY #$FF       		;RESET TEXT INDEX
	LDA #$00       		;FOR XAM MODE
	TAX            		;0->X

SETSTOR:	ASL			;LEAVES $7B IF SETTING STOR MODE

SETMODE:	STA MODE			;SET MODE FLAGS

BLSKIP:	INY			;ADVACE TEXT INDEX

NEXTITEM:	LDA IN,Y			;GET CHARACTER
	CMP #CR
	BEQ GETLINE		;WE'RE DONE IF IT'S CR!
	CMP #'.'
	BCC BLSKIP		;IGNORE EVERYTHING BELOW "."!
	BEQ SETMODE		;SET BLOCK XAM MODE ("."=$AE)
	CMP #':'
	BEQ SETSTOR		;SET STOR MODE! #BA WILL BECOM $7B
	CMP #'R'
	BEQ RUN			;RUN THE PROGRAM! FORGET THE REST
	STX L			;CLEAR INPUT VALUE (X=0)
	STX H
	STY YSAV			;SAVE Y FOR COMPARISON

; HERE WE'RE TRYING TO PARSE A NEW HEX VALUE

NEXTHEX:	LDA IN,Y			;GET CHARACTER FOR HEX TEST
	EOR #$30			;MAP DIGITS 0-9
	CMP #$0A			;IS IT A DECIMAL DIGIT?
	BCC DIG			;YES!
	ADC #$88			;MAP LETTER "A"-"F" TO $FA-FF
	CMP #$FA			;HEX LETTER?
	BCC NOTHEX		;NO! CHARACTER NOT HEX

DIG:	ASL
	ASL			;HEX DIGIT TO MSD OF A
	ASL
	ASL

	LDX #$04			;SHIFT COUNT
HEXSHIFT:	ASL			;HEX DIGIT LEFT, MSB TO CARRY
	ROL L			;ROTATE INTO LSD
	ROL H			;ROTATE INTO MSD'S
	DEX			;DONE 4 SHIFTS?
	BNE HEXSHIFT		;NO, LOOP
	INY			;ADVANCE TEXT INDEX
	BNE NEXTHEX		;ALWAYS TAKEN
  
NOTHEX:	CPY YSAV			;WAS AT LEAST 1 HEX DIGIT GIVEN?
	BNE NOESCAPE		;NO! IGNORE ALL,START FROM SCRATCH
	JMP ESCAPE

NOESCAPE:	BIT MODE	
	BVC NOTSTOR
	LDA L			;LSD'S OF HEX DATA
	STA (STL,X)		;STORE CUR 'STORE INDEX'(X=0)
	INC STL			;INCREMENT STORE INDEX
	BNE NEXTITEM		;NO CARRY!
	INC STH			;ADD CARRY TO 'STORE INDEX' HIGH
TONXTITM: JMP NEXTITEM		;GET NEXT COMMAND ITEM

;-------------------------------------------------------------------------
;  RUN user's program from last opened location
;-------------------------------------------------------------------------

RUN:	JSR ACTRUN		;RUN USER'S PRORAM
	JMP SFTRST

ACTRUN:	JMP (XAML)

;-------------------------------------------------------------------------
;  We're not in Store mode
;-------------------------------------------------------------------------

NOTSTOR:	BMI XAMNEXT		;B7=0 FOR XAM, 1 FOR BLOCK XAM

;WE'RE IN XAM MODE NOW

	LDX #$02			;COPY 2 BYTES
SETADR:	LDA L-1,X			;COPY HEX DATA TO
	STA STL-1,X		;store index'
	STA XAML-1,X		;AND TO 'XAM INDEX'
	DEX			;NEXT OF 2 BYTES
	BNE SETADR		;LOOP UNLESS X=0

; PRINT ADDR & DATA FROM THIS ADDR, FALL THRU NEXT BNE

NXTPRNT:	BNE PRDATA		;NE MEANS NO ADDRESS TO PRINT
	JSR CRLF
	LDA XAMH			;OUTPUT HIGH-ORDER BYTE OF ADDR
	JSR PRBYTE
	LDA XAML			;OUTPUT LOW-ORDER BYTE OF ADDR
	JSR PRBYTE
	LDA #':'			;PRINT COLON
	JSR ECHO

PRDATA:	LDA #' '			;PRINT SPACE
	JSR ECHO
	LDA (XAML,X)		;GET DATA FROM ADDRESS(X=0)
	JSR PRBYTE		;OUTPUT IT IN HEX FORMAT
XAMNEXT:	STX MODE			;0->MODE(XAM MODE)
	LDA XAML			;SEE IF THERE'S MORE TO PRINT
	CMP L
	LDA XAMH
	SBC H
	BCS TONXTITM		;NOT LESS! NO MORE DATA TO OUTPUT

	INC XAML			;INCREMENT 'EXAMING INDEX'
	BNE MOD8CHK		;NO CARRY!
	INC XAMH

MOD8CHK:	LDA XAML			;IF ADDRESS MOD8=0 START NEW LINE
	AND #%00000111		;8 VALUES PER ROW
	BPL NXTPRNT		;ALWAYS TAKEN

;-------------------------------------------------------------------------
;  Subroutine to print a byte in A in hex form (destructive)
;-------------------------------------------------------------------------

PRBYTE:	PHA			;SAVE A FOR LSD
	LSR
	LSR
	LSR			;MSD TO LSD
	LSR
	JSR PRHEX			;OUTPUT HEX DIGIT
	PLA			;RESTORE A

; FALL THROUGH TO PRINT HEX ROUTING

;-------------------------------------------------------------------------
;  Subroutine to print a hexadecimal digit
;-------------------------------------------------------------------------

PRHEX:	AND #$0F			;MASK LSD FOR HEX PRINT
	ORA #'0'			;ADD "0"
	CMP #'9'+1		;DIGIT?
	BCC ECHO			;YES, OUTPUT IT
	ADC #$06			;ADD OFFSET FOR LETTER

; Fall through to print routine

;-------------------------------------------------------------------------
;  Subroutine to print a character to the terminal
;-------------------------------------------------------------------------

ECHO:	PHA			;SAVE A
	JSR COUT			;COUT
  	PLA			;RESTORE A
	RTS

SHWMSG:	LDY #$0
PRINT:	LDA (MSGL),Y
	BEQ DONE
	JSR ECHO
	INY
	BNE PRINT
DONE:	RTS

CRLF:	LDA #LF       
	JSR ECHO			;SEND LF
	LDA #CR
	JSR ECHO			;SEND CR
	RTS

MSG1:	.byte CR,LF
	.byte "WELCOME TO GAKMON V1.0"
	.byte CR,LF
	.byte "    By Glenn Klaas"
	.byte CR,LF,CR,LF,0

.segment "IOHANDLER"
.org $FF00

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
	SEC			; Carry set if key available
	RTS
NoDataIn:	CLC			; Carry clear if no key pressed
	RTS

RDKEY:	JSR MONRDKEY		;Check if key was pressed
	BCC RDKEY			;If not, check again
	RTS

;-------------------------------------------------------------------------
;  Vector area
;-------------------------------------------------------------------------

.segment "VECTS"
.org $FFFA
	.word RESET		;NMI 
	.word RESET		;RESET 
	.word RESET		;IRQ 
