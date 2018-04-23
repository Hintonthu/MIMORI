echo "setup..."
source ./read_all.tcl > ./rpt/00_setup.txt
echo "ungroup..."
source ./ungroup.tcl > ./rpt/05_ungroup.txt
echo "link & check..."
source ./link.tcl > ./rpt/10_link.txt
echo "compile..."
source ./compile.tcl > ./rpt/15_compile.txt
echo "output..."
source ./write_all.tcl > ./rpt/20_report.txt
echo "done"
