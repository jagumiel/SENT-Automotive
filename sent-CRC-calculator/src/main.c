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
	uint8_t data1[]= {2, 2, 4, 3, 2, 1};
	uint8_t data2[]= {15, 5, 10, 2, 8, 0};
	uint8_t mySample[]={0, 0, 0, 0, 0, 0};
	uint8_t dataSamples[ 8/*Rows*/ ][6/*Cols*/] = {	{ 0x4 , 0x7 , 0x8 , 0x3 , 0x4 , 0x7 }/*CRC=0xD*/,
													{ 0x4 , 0x7 , 0x8 , 0x3 , 0x4 , 0x3 }/*CRC=0x3*/,
													{ 0x4 , 0x7 , 0x8 , 0x3 , 0x4 , 0x5 }/*CRC=0xA*/,
													{ 0x4 , 0x7 , 0x8 , 0x3 , 0x4 , 0x4 }/*CRC=0x7*/,
													{ 0x4 , 0x7 , 0x7 , 0x3 , 0x4 , 0x5 }/*CRC=0xC*/,
													{ 0x4 , 0x7 , 0x9 , 0x3 , 0x4 , 0x5 }/*CRC=0xE*/,
													{ 0x4 , 0x7 , 0x9 , 0x3 , 0x4 , 0x6 }/*CRC=0x4*/,
													{ 0x4 , 0x7 , 0x7 , 0x3 , 0x4 , 0x7 }/*CRC=0xB*/};

	printf("====Calculating frame from images...====\n");
	printf("\tData1 CRC is: %i\n", calculateCRC(data1, ((sizeof(data1))/(sizeof(data1[0])))));
	printf("\tData2 CRC is: %i\n", calculateCRC(data2, ((sizeof(data2))/(sizeof(data2[0])))));


	printf("====Some more frames to test...====\n");
	for(int i=0; i<8; i++){
		for(int j=0; j<6; j++){
			mySample[j]=dataSamples[i][j];
		}
		printf("\tSample%i CRC is: %i\n", i, calculateCRC(mySample, 6));
	}
}
