# ungroup the inner of the cells (no-parameter and parametered cells)
foreach_in_collection d [get_designs { \
	ParallelBlockLooper \
	DramArbiter DramWriteCollectorAddrDecode DramWriteCollectorOutput \
	SimdOperand Alu SimdTmpBuffer SimdDriver \
	AccumWarpLooper AccumWarpLooper_* \
	ChunkAddrLooper ChunkAddrLooper_* \
	ChunkHead ChunkHead_* \
	LinearCollector LinearCollector_* \
	Allocator Allocator_* \
	RemapCache RemapCache_*
}] {
	current_design $d
	ungroup -all -flatten
}

# return to the top level
current_design Top

# ungroup the cells itself
set ungroup_cells {}
foreach_in_collection d [get_designs { \
	OffsetStage OffsetStage_* \
	Semaphore Semaphore_* \
	ForwardIf ForwardIf_* \
	AcceptIf AcceptIf_* \
	IgnoreIf IgnoreIf_* \
	Reverse Reverse_* \
	FindFromLsb FindFromLsb_* \
	FindFromMsb FindFromMsb_* \
	SFifoCtrl SFifoCtrl_* \
	BroadcastInorder BroadcastInorder_* \
	Broadcast Broadcast_* \
	ForwardMulti ForwardMulti_* \
	SRAMDualPort SRAMDualPort_* \
	IdSelect IdSelect_* \
	OneCycleInit Forward ForwardSlow
}] {
	set dname [get_object_name $d]
	echo $dname
	foreach_in_collection c [get_cells -hier -filter ref_name==$dname] {
		lappend ungroup_cells [get_object_name $c]
	}
}
uniquify
ungroup -flatten $ungroup_cells
