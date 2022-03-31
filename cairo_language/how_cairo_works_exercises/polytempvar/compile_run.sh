cairo-compile $1.cairo --output=$1_compiled.json
cairo-run --program=$1_compiled.json --print_memory --print_info --trace_file $1_trace.bin --memory_file=$1_memory.bin --relocate_prints
