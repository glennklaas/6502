ECHO   .=  $FFEF

       LDA #'A'
.LOOP  JSR ECHO
       TAX
       INX
       TXA
       CMP #'Z'+1
       BNE .LOOP
       RTS
