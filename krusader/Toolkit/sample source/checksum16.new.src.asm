PRBYTE .=  $FFDC

CRCLO  .=  $C0
CRCHI  .=  $C1
STARTL .=  $C2
STARTH .=  $C3
ENDL   .=  $C4
ENDH   .=  $C5

DATA   .M  $C0
       .W  $FFFF          INIT
       .W  $F000          START ADD
       .W  $FEFF          END ADD

MAIN   .M  $300
.LOOP  LDY #$0
       LDA (STARTL),Y
CRC16  EOR CRCHI
       STA CRCHI
       LSR
       LSR
       LSR
       LSR
       TAX
       ASL
       EOR CRCLO
       STA CRCLO
       TXA
       EOR CRCHI
       STA CRCHI
       ASL
       ASL
       ASL
       TAX
       ASL
       ASL
       EOR CRCHI
       TAY
       TXA
       ROL
       EOR CRCLO
       STA CRCHI
       STY CRCLO
CONT   INC STARTL
       BNE .SKIP2
       INC STARTH
.SKIP2 LDA STARTH
       CMP ENDH
       BNE .LOOP
       LDA STARTL
       CMP ENDL
       BNE .LOOP
OUTPUT LDA CRCHI
       JSR PRBYTE
       LDA CRCLO
       JSR PRBYTE
       RTS

