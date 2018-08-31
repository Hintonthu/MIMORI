NICOTB=$(shell pwd)/../nicotb/lib
VERI=verilator
PY=python
MKFLAG=-j
NPY_CFLAGS=-I$(shell $(PY) -c "from numpy import get_include as i; print(i())") \
           $(shell $(PY)-config --includes) -DNPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION

# Usage: TEST_CFG=X make top_xx (default X = 0)
top_sc:
	make CFLAGS="-DSC" VERI_FLAGS="+define+SC" VF_PATH="Top.sv" Top

all_sub:
	-make fifo
	-make pbl
	-make pbl_mc
	-make abl
	-make alloc
	-make chal
	-make simd_drv
	-make wc
	-make awl
	-make rmc

awl:
	make VF_PATH="TileAccumUnit/common/AccumWarpLooper/AccumWarpLooper.sv" \
		VERI_FLAGS="-GUSE_LOFS=1 -GSTENCIL=1" AccumWarpLooper

wc:
	make \
		VF_PATH="TileAccumUnit/WritePipeline/DramWriteCollector/DramWriteCollector.sv" \
		TOP=DramWriteCollector WriteCollector

simd_drv:
	make VF_PATH="TileAccumUnit/AluPipeline/SimdDriver.sv" SimdDriver

chal:
	make VF_PATH="TileAccumUnit/ReadPipeline/ChunkAddrLooper/ChunkAddrLooper.sv" ChunkAddrLooper

alloc:
	make VF_PATH="TileAccumUnit/ReadPipeline/Allocator.sv" Allocator

abl:
	make VF_PATH="TileAccumUnit/AccumBlockLooper.sv" AccumBlockLooper

pbl:
	make VF_PATH="ParallelBlockLooper.sv" ParallelBlockLooper

pbl_mc:
	make VF_PATH="ParallelBlockLooper_mc.sv" \
		VERI_FLAGS="+define+MC" ParallelBlockLooper_mc

fifo:
	make VF_PATH="common/SFifo.sv" SFifo

rmc:
	RMC_CONF=0 make                VF_PATH="TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv" RemapCache
	RMC_CONF=1 make COMPILE_ONLY=1 VF_PATH="TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv" RemapCache
	RMC_CONF=2 make COMPILE_ONLY=1 VF_PATH="TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv" RemapCache
	RMC_CONF=3 make COMPILE_ONLY=1 VF_PATH="TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv" RemapCache
	RMC_CONF=4 make COMPILE_ONLY=1 VF_PATH="TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv" RemapCache
	RMC_CONF=5 make COMPILE_ONLY=1 VF_PATH="TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv" RemapCache

%: TEST ?= $@_test
%: TOP ?= $@
%: MDIR ?= VOBJ_$(TOP)
%: EXE = V$(TOP)
%: %_tb.cpp $(NICOTB)/cpp/nicotb_verilator.so
	-test -z "${COMPILE_ONLY}" && $(VERI) $(VERI_FLAGS) -I../src --trace -cc ../src/$(VF_PATH) \
	 --exe $@_tb.cpp $(NICOTB)/cpp/nicotb_verilator.so \
	 --Mdir $(MDIR) --top-module $(TOP) -DVERI_TOP_$(TOP) \
	 -LDFLAGS "-lz" -CFLAGS "-O2 --std=c++11 $(CFLAGS) $(NPY_CFLAGS) -I$(NICOTB)/cpp"
	make -j $(MKFLAG) -C $(MDIR) -f $(EXE).mk
	GLOG_logtostderr=1 \
	GLOG_minloglevel=0 \
	PYTHONPATH=$(NICOTB)/python:`pwd`/../sim/ \
	TEST=$(TEST) \
	$(GDB) ./$(MDIR)/$(EXE)

$(NICOTB)/cpp/nicotb_verilator.so:
	make -C $(NICOTB)/cpp/

clean:
	rm -rf VOBJ_* *.vcd scoreboard.db

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
