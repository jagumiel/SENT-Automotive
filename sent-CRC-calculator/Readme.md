# SENT - CRC Calculator
## _Calculate the CRC from SENT frames_

This program was developed to calculate the Cyclyc Redundancy Check (CRC) from a SENT frame.

**Single Edge Nibble Transmission (SENT)** is an automotive communication protocol for transmitting signal values from a sensor to a controller. It is intended to allow for transmission of high resolution data with a low system cost.

## How does SENT works?
Data is transmitted in units of 4 bits (1 nibble) for which the interval between two falling edges (single edge) of the modulated signal with a constant amplitude voltage is evaluated. A SENT message is 32 bits long (8 nibbles) and consists of the following components: 24 bits of signal data (6 nibbles) that represents 2 measurement channels of 3 nibbles each (such as pressure and temperature), 4 bits (1 nibble) for CRC error detection, and 4 bits (1 nibble) of status/communication information.

### Frame Examples:

![Alt text](images/sampleFrame-1.png?raw=true "Sample Frame 1")
![Alt text](images/sampleFrame-2.png?raw=true "Sample Frame 2")

### Results:
The same frame was introduced into the main program to calculate its CRC. The result is the same as expected.

![Alt text](images/resultados.PNG?raw=true "Execution Results")

## Compilation
This function was programmed in C. All you have to do is compile it with GCC from the Linux Console or use an IDE (Eclipse for example) and a GCC toolchain, (such as MinGW).

`
gcc -o sent-CRC-calc src/main.c
`

You can modify as you want. You can use the method _calculateCRC(uint8_t Data, int length)_ to calculate the CRC in your receiver microcontroller. You can also change the _main()_ and introduce your own frames to test them. Be creative!
