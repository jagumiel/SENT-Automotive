/*
 ============================================================================
 Name        : sent-CRC-calculator.c
 Author      : jagumiel
 Version     : 1.0
 Date		 : Oct. 2021
 Description : CRC calculator for SENT protocol (SAE J2716).
 ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

const uint8_t crcLookup[16] = {0, 13, 7, 10, 14, 3, 9, 4, 1, 12, 6, 11, 15, 2, 8, 5};

uint8_t calculateCRC(uint8_t myData[], int length){
	uint8_t calculatedCRC, i;
	calculatedCRC = 5; // initialize checksum with seed "0101"

	//printf("Array's length is %i.\n", length);

	for (i = 0; i < length; i++){
		calculatedCRC = crcLookup[calculatedCRC];
		calculatedCRC = (calculatedCRC ^ myData[i]) & 0x0F;
	}

	// One more round with 0 as input
	calculatedCRC = crcLookup[calculatedCRC];
	return calculatedCRC;
}


int main(void) {
	//DataN: This variable contains the received data stream.
	uint8_t data1[]= {15, 5, 10, 2, 8, 0};
	uint8_t data2[]= {2, 2, 4, 3, 2, 1};
	printf("Data1 CRC is: %i\n", calculateCRC(data1, ((sizeof(data1))/(sizeof(data1[0])))));
	printf("Data2 CRC is: %i\n", calculateCRC(data2, ((sizeof(data2))/(sizeof(data2[0])))));
}
