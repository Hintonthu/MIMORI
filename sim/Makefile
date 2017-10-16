NICOTB=../nicotb/lib
IRUN=irun

top:
	make Top

wc:
	make WriteCollector

chal:
	make ChunkAddrLooper

abl_sa0:
	make ARGS="+define+SA=0" AccumBlockLooper

abl_sa1:
	make ARGS="+define+SA=1" AccumBlockLooper

rmc:
	make ARGS="+define+DEFAULT_VSIZE=8" RemapCache

bml:
	make BlockMemoryLooper

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
