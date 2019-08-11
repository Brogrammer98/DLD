Compilation:
We have provided a "run.py" file, which helps in execution of both FPGA and C files. This "run.py" file has to be placed inside 
"20140524/makestuff/apps/flcli". To begin compilation, just type "python run.py" in the said flcli folder. All the files provided 
in the "VHDL" and "C" folders have to be kept in the respective folders.

UART Communication:
We have done the mandatory part of the problem. The computer-side communicates using the gtk-term interface. So, we just have to
run "sudo gtkterm -p /dev/ttyXRUSB0 -s 2400" in new terminal. To initiate communication, press the "left" button during 
the 24-second window during which output is displayed on the board. After pressing the button, set the slider switches.
Pressing the right button would send the data to the backend-computer and will show up on the gtk-term interface. From the same
interface, send the hex data from the computer to the board through UART.
