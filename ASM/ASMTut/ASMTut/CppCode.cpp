#include <iostream>
#include <conio.h>
#include <ctime>
#include <Windows.h>
#include <WinCon.h>

using namespace std ;

/*int MyASMFunc ()
{
	_asm { // Inline assembly
		mov eax, 100 // 32 bit Assembly only!
	}
}*/

extern "C" long long ASMFunc (long long, long long, long long, long long, long long, long long, int *) ; // No name mangling just an underscore
extern "C" long long CalledFromCpp (long long, long long, long long, long long, long long, long long) ;
extern "C" long long CalledFromASM (long long, long long, long long, long long, long long, long long) ;
long long caller (long long, long long, long long, long long, long long, long long, int *) ; // Prototype

extern "C" void CreateThreadInASM (int* j) ;

int i;

int main()
{
	long long p1 = 1l, p2 = 2l, p3 = 3l, p4 = 4l, p5 = 5l, p6 = 6l ;
	long long ap1 = 11l, ap2 = 12l, ap3 = 13l, ap4 = 14l, ap5 = 15l, ap6 = 16l ; // 81
	
	long long retvalC ;
	long long retvalASM ;

	// Calling C++ from C++
	retvalC = CalledFromCpp (p1, p2, p3, p4, p5, p6) ; // 42			
	cout << "Returning value from C++ function: " << retvalC << endl ;

	// Calling ASM from C++ (which in turn calls C++)
	i = 16;
    retvalASM = caller (ap1, ap2, ap3, ap4, ap5, ap6, &i) ; // 202
	cout << "Returning value from ASM function: " << retvalASM << endl ;
	cout << "Value of i after ASM function call: " << i << endl;

	int j = 4;
	CreateThreadInASM (&j) ; // The thread will increment j 

    while (j == 4) {} // Wait for the thread to change j
    cout << "Value of j after ASM thread: " << j << endl ;

	_getch() ; // Press any key
	return 0 ;
}

long long caller (long long ap1, long long ap2, long long ap3, long long ap4, long long ap5, long long ap6, int * p)
{ 
	return ASMFunc (ap1, ap2, ap3, ap4, ap5, ap6, p) ; // 81 (params to ASM) + 96 (ASM local vars) + 21 (ASM params for C++) + 4 (C++ local vars) = 202
}

long long CalledFromCpp (long long rp1, long long rp2, long long rp3, long long rp4, long long rp5, long long rp6)
{
	long long lv1 = 10 ;
	long long lv2 = 11 ;
	
	return rp1 + rp2 + rp3 + rp4 + rp5 + rp6 + lv1 + lv2 ; // 42
}

long long CalledFromASM (long long rp1, long long rp2, long long rp3, long long rp4, long long rp5, long long rp6)
{
	long long lv1 = 1;
	long long lv2 = 3;

	return rp1 + rp2 + rp3 + rp4 + rp5 + rp6 + lv1 + lv2 ; // 21 (ASM params for C++) + 4 (local vars) = 25
}