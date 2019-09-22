CA=ca65
LD=ld65

all:krusader

krusader: Krusader_1.3_65C02_ca65.o
	$(LD) -o krusader.bin -C krusader_test.cfg Krusader_1.3_65C02_ca65.o -m krusader.map

Krusader_1.3_65C02_ca65.o:
	$(CA) FULL_Krusader_1.3_ca65.asm -o Krusader_1.3_65C02_ca65.o -l Krusader_1.3_65C02_ca65.lst

clean:
	rm -f *.o *.rom *.map *.lst
