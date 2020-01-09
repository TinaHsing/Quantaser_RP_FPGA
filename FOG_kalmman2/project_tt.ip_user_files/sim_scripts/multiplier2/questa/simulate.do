onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib multiplier2_opt

do {wave.do}

view wave
view structure
view signals

do {multiplier2.udo}

run -all

quit -force
