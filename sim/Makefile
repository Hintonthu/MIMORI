NICOTB=../nicotb/lib
IRUN=irun
SYN=syn

top:
	make Top

tops:
	make ARGS="+define+SDF=\\\"../$(SYN)/Top.sdf\\\" +define+GATE_LEVEL +define+SRAM_GEN_MODE=SYNOPSYS32 +incdir+../$(SYN)/SAED32_EDK/lib/sram/verilog/ +incdir+../$(SYN)/SAED32_EDK/lib/stdcell_rvt/verilog/ +incdir+../$(SYN)/ +nowarn+SDFNCAP:SDFNDP:MACRDF:CUVWSP" Top

wc:
	make WriteCollector

chal:
	make ChunkAddrLooper

abl:
	make AccumBlockLooper

rmc:
	make ARGS="+define+DEFAULT_VSIZE=8" RemapCache

pbl:
	make ParallelBlockLooper

alloc:
	make Allocator

simd_drv:
	make SimdDriver

awl:
	make AccumWarpLooper

cal:
	make CoreAccumLooper

%: %_test.sv $(NICOTB)/cpp/nicotb.so
	GLOG_logtostderr=1 \
	GLOG_minloglevel=1 \
	TEST=$(if $(TEST),$(TEST),$@)_test \
	TOPMODULE=$(if $(TOPMODULE),$(TOPMODULE),$@)_test \
	PYTHONPATH=$(NICOTB)/python:. \
	$(IRUN) +access+rw -loadvpi $(NICOTB)/cpp/nicotb.so:VpiBoot \
	+incdir+../src/ \
	+incdir+../include/ \
	$(ARGS) $(NICOTB)/verilog/Utils.sv $<

$(NICOTB)/cpp/nicotb.so:
	make -C $(NICOTB)/cpp/
