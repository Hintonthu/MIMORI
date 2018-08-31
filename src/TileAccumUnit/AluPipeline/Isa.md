# The 30-bit Isa format

    (OOO)(SSSSS)(R)(DD)(T)(WWW)(AAAAA)(BBBBB)(CCCCC)
     29   26     21 20  18 17   14     9      4

# (SSSSS)
shift amount

# opcode OOO:

* `000 a + ((b+c)     >> shamt)`
* `001 a + ((b-c)     >> shamt)`
* `011 a + (|b-c|     >> shamt)`
* `100 a + ((b*c)     >> shamt)` ; only lower 16 bit of b and c is used
* `101`
	* Table interpolation, similar to texture, BBBBB must be `0pqrr`.
	* Define the lowest bits of `{c, 5'b0} >> shamt` as `yyyyzzzzz`.
	* Define `S(m, nlll...) = {m^n}lll...`, ex: `S(1, 110) = 010`.
	* This instruction gives an interpolation:
		* `T0 = LUT[rr][S(p, yyyy)]`
		* `T1 = LUT[rr][S(p, yyyy)+1]`
		* `INTERP = T0*(32-zzzzz)+T1*zzzzz`
		* result = `S(q, INTERP/32)`
* `110`
	* `shamt = 00000 bool(a) ? b : c`
	* `shamt = 00001 max(a, b)` ; CCCCC should be `0xxxx`, which has no effect
	* `shamt = 00010 min(a, c)` ; BBBBB should be `0xxxx`, which has no effect
	* `shamt = 00011 min(max(a, b), c)`
	* `shamt = 001xx` ; reserved
	* `shamt = 01xxx LOGIC_LUT[xxx](a,b,c)`
	* `shamt = 1xxxx` ; reserved
* `111`
	* `shamt = 00xxx aofs[0-5]`
	* `shamt = 01xxx bofs[0-5]`
	* other shamt values are reserved, and `xxx>5` is also invalid.
	* `AAAAA-CCCCC` must be `0xxxx`, but `xxxx` has no effect.
* `101` and `110` are partially implemented yet.

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
