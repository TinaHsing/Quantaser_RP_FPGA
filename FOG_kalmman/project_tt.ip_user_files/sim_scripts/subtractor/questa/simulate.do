onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib subtractor_opt

do {wave.do}

view wave
view structure
view signals

do {subtractor.udo}

run -all

quit -force
