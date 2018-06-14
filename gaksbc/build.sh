#tar cfz ./backups/backup-$(date +%Y%m%d_%H%M%S).tar.gz * --exclude backups
ca65 gaksbc.s -o gaksbc.o -l gaksbc.lst
ld65 -o gaksbc.bin -C gaksbc.cfg gaksbc.o -m gaksbc.map
#cp gaksbc.bin gaksbc.lst gaksbc.cfg /mnt/Projects/gaksbc
