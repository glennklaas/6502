
				.org $600

cout 		= $ffd2
rdkey		= $fff1

				jsr crout 
				jsr crout 

				ldx #$00
loop:		lda msg1,x
				beq end 
				jsr cout
				inx	
				bne loop
end: 	  jsr crout
				jsr crout
				rts	

msg1: 	.byte "HELLO, WORLD!",$00	
		
CROUT:	pha	
				lda #$0d
				jsr cout 
				lda #$0a
				jsr cout 
				pla
				rts
