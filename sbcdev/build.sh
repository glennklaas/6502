ca65 gakmon.asm -l gakmon.lst -v
ld65 gakmon.o -C sbc.cfg -o gakmon.bin
xxd gakmon.bin | xxd -r -s 0x0600 | xxd -u -s 0x0600 -g 1 -c 8 |cut -b -34 |cut -b -34 |cut -b 5-100 | tee gakmon.mon
