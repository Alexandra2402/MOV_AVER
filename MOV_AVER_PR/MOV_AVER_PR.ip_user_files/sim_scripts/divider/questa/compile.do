vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xil_defaultlib

vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vcom -work xil_defaultlib  -93  \
"../../../../MOV_AVER_PR.gen/sources_1/ip/divider/sim/divider.vhd" \


vlog -work xil_defaultlib \
"glbl.v"

