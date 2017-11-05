# The 30-bit Isa format

    (OOO)(SSSSS)(R)(DD)(T)(WWW)(AAAAA)(BBBBB)(CCCCC)
     29   26     21 20  18 17   14     9      4

# (SSSSS)
shift amount

# opcode OOO:

* 000 a + ((b+c)     >> shamt)
* 001 a + ((b-c)     >> shamt)
* 010 a + ((b-c)^2   >> shamt)  * only lower 16 bit of b and c is used
* 011 a + (|b-c|     >> shamt)
* 100 a + ((b*c)     >> shamt)  * only lower 16 bit of b and c is used
* 101 a+LUT[b](c>>shamt)        * similar to texture, BBBBB must be 0~7
* 110
	* shamt = 00000 bool(a) ? b : c
	* shamt = 00001 reserved
	* shamt = 00010 b>c     ? b : c , AAAAA should be 0XXXX, but XXXX has no effect
	* shamt = 00011 b<c     ? b : c , AAAAA should be 0XXXX, but XXXX has no effect
	* shamt = 001XX reserved
	* shamt = 01XXX LOGIC_LUT[XXX](a,b,c)
	* shamt = 1XXXX reserved
* 111
	* shamt = 00XXX aofs[0-5]
	* shamt = 01XXX bofs[0-5]
	* other shamt values are reserved, and XXX>5 is also invalid.
	* AAAAA-CCCCC must be 0XXXX, but XXXX has no effect
* 101 and 110 are not implemented yet

# src operand format (AAAAA)~(CCCCC)

There are 5 address spaces:

* 0XXXX constant [0-F]
* 1000X from ReadPipeline [0-1]
* 1001X temporary delay [0-1]
* 101XX constant lut [0-4]
* 11XXX register [0-7]
	* (no more than one register at once), that is:
	* ex: 11000, 11000, 11000 = OK
	* ex: 11000, 11000, 11001 = undefined

After the decode/operand stage, the register space is:

* constant [0]
* register [1]
* read pipeline [23]
* temporary delay [45]

# dst oprand format (DD)(T)(R)(WWW)

* (R) The results are written to register
* (DD) The results are also written to DRAM+shift, 0~2 = shift 0,2,4 or disabled
* (T) The results are written to temporary delay
* (WWW) The register to write, warp_id * reg_per_warp + (WWW) = actual address

The temporary buffer is necessary since register
write requires 2 cycles to take effect.
