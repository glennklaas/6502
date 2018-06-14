xxd gaksbc.bin | xxd -r -s 0xC000 | xxd  -u -s 0xC000 -c 8
