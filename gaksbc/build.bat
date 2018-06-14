@echo off
ca65 gaksbc.s -o gaksbc.o -l gaksbc.lst
ld65 -o gaksbc.bin -C gaksbc.cfg gaksbc.o -m gaksbc.map
