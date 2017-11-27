# GAKSBC - Single Board Computer 

Description: This monitor is for a 65C02 based single board computer with an MC68B50P ACIA, 32K ROM and 32K RAM.  The memory layout is as follows:

**Memory Map / Decoding**
- 0000-7FFF  RAM 32K
- 8000-9FFF  Free 8K
- A000-BFFF  Serial Interface 8K
- C000-FFFF  ROM 16K

A15|A14|A13
0|0|0
0|1|1
1|0|0
1|0|1
1|1|0
1|1|1
