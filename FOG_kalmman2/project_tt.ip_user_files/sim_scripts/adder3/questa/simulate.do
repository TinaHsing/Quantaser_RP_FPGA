onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib adder3_opt

do {wave.do}

view wave
view structure
view signals

do {adder3.udo}

run -all

quit -force
