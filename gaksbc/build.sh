#tar cfz ./backups/backup-$(date +%Y%m%d_%H%M%S).tar.gz * --exclude backups
ca65 gaksbc.s -o gaksbc.o -l gaksbc.lst
ld65 -C gaksbc.cfg gaksbc.o -o gaksbc.bin -m gaksbc.map
#cp gaksbc.bin gaksbc.lst gaksbc.cfg /mnt/Projects/gaksbc
