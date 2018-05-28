ifdef SV
	EXT = sv
	SFLAG += -sv
else
	EXT = v
endif
SRC = ../src
INC = ../include
NFLAG += -max_compile_error 1000 -r 25009 -r 22117 -r 23133
# FLAG += -max_compile_error 1000 -r 25009 -r 22117 -r 23133 -r 25001 -r 25003 -r 23405

all:
	cat lint.log | sed 's/#.*#(/(/'

%: $(INC)/%_include.$(EXT)
	-rm -r lint.log nLintLog nLintDB
	nLint -nologo -sort s -out lint.log +incdir+$(SRC) $(FLAG) $(NFLAG) $(SFLAG) $<
	make all
