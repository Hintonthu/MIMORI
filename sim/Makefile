NICOTB=../nicotb/lib
IRUN=irun
SYN=syn

# Usage: TEST_CFG=X make top (default X = 0)
top:
	make COVERAGE=$(COV) Top

tops:
	make ARGS="+define+SDF=\\\"../$(SYN)/Top.sdf\\\" +define+GATE_LEVEL +define+SRAM_GEN_MODE=SYNOPSYS32 +incdir+../$(SYN)/SAED32_EDK/lib/sram/verilog/ +incdir+../$(SYN)/SAED32_EDK/lib/stdcell_rvt/verilog/ +incdir+../$(SYN)/ +nowarn+SDFNCAP:SDFNDP:MACRDF:CUVWSP:SDFNSB:SDFNL1" Top

all_sub:
	-make COVERAGE=$(COV) pbl
	-make COVERAGE=$(COV) abl
	-make COVERAGE=$(COV) simd_drv
	-make COVERAGE=$(COV) awl
	-make COVERAGE=$(COV) wc
	-make COVERAGE=$(COV) cal
	-make COVERAGE=$(COV) alloc
	-make COVERAGE=$(COV) chal

wc:
	make COVERAGE=$(COV) WriteCollector

chal:
	make COVERAGE=$(COV) ChunkAddrLooper

abl:
	make COVERAGE=$(COV) AccumBlockLooper

rmc:
	-RMC_CONF=0 make COVERAGE=$(COV) RemapCache
	-RMC_CONF=1 make COVERAGE=$(COV) RemapCache
	-RMC_CONF=2 make COVERAGE=$(COV) RemapCache
	-RMC_CONF=3 make COVERAGE=$(COV) RemapCache
	-RMC_CONF=4 make COVERAGE=$(COV) RemapCache

pbl:
	make COVERAGE=$(COV) ParallelBlockLooper

alloc:
	make COVERAGE=$(COV) Allocator

simd_drv:
	make COVERAGE=$(COV) SimdDriver

awl:
	make COVERAGE=$(COV) AccumWarpLooper

dump_scoreboard:
	@echo -e \
	".open scoreboard.db\n"\
	".header on\n"\
	".mode column\n"\
	".print ===============\n"\
	".print All Scoreboards\n"\
	".print ===============\n"\
	"select * from Scoreboard;\n"\
	".print\n"\
	".print =========\n"\
	".print All Tests\n"\
	".print =========\n"\
	"select * from Tests;\n"\
	 | sqlite3

%: %_test.sv $(NICOTB)/cpp/nicotb.so
	$(eval TOP=$(if $(TOPMODULE),$(TOPMODULE),$@)_test)
	GLOG_logtostderr=1 \
	GLOG_minloglevel=1 \
	TEST=$(if $(TEST),$(TEST),$@)_test \
	TOPMODULE=$(TOP) \
	PYTHONPATH=$(NICOTB)/python:. \
	$(IRUN) +access+rw -loadvpi $(NICOTB)/cpp/nicotb.so:VpiBoot \
	+incdir+../src/ \
	+incdir+../include/ \
	$(if $(COVERAGE),-covoverwrite -coverage block -covtest $(TOP) -covdut $(TOP),) \
	$(ARGS) $(NICOTB)/verilog/Utils.sv $<

$(NICOTB)/cpp/nicotb.so:
	make -C $(NICOTB)/cpp/

clean:
	-rm -rf ncsim* novas* irun* *.rc scoreboard.db __pycache__ INCA_libs
