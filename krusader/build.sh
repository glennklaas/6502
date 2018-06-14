ca65 FULL_Krusader_1.3_ca65.asm -o Krusader_1.3_65C02_ca65.o -l Krusader_1.3_65C02_ca65.lst
ld65 -o krusader.bin -C krusader_test.cfg Krusader_1.3_65C02_ca65.o -m krusader.map
