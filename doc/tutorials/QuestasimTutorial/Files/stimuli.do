#Init
force -freeze sim:/questa_tutorial/Clk 1 0, 0 {5000 ns} -r 10000
force -freeze sim:/questa_tutorial/Buttons 4'b0000 0


#Push values in
force -freeze sim:/questa_tutorial/Switches 4'b0001 0
force -freeze sim:/questa_tutorial/Buttons 2'b01 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b00 0
force -freeze sim:/questa_tutorial/Switches 4'b0011 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b01 0
run 100 ms
force -freeze sim:/questa_tutorial/Switches 4'b0111 0
force -freeze sim:/questa_tutorial/Buttons 2'b00 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b01 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b00 0
run 100 ms

#Push values to LEDs
force -freeze sim:/questa_tutorial/Buttons 2'b10 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b00 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b10 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b00 0
run 100 ms
force -freeze sim:/questa_tutorial/Buttons 2'b10 0
run 100 ms
