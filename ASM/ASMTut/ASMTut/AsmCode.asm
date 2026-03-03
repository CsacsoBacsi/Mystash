extrn CalledFromASM:proc					; Defined elsewhere. Tell this to Linker

.data?										; Un-initialized data section

			retval	qword	?				; Return value when called from C++ will be stored here

.code										; Code section

ASMFunc proc								; Procedure code

			jmp		overdata				; Jump over code-embedded data. Could have been defined in data segment or even on the Stack

			param1		qword 1d
			param2		qword 2d
			param3		qword 3d
			param4		qword 4d
			param5		qword 5d
			param6		qword 6d			; 21 (sum of params passed to C++)
			local1		qword 32d
			local2		qword 64d			; 96 (sum of local vars)

			; Called from C++
overdata:	mov		qword ptr [rsp+20h], r9	; Function Prolog Start. Set up local variables and RBP
			mov		qword ptr [rsp+18h], r8  
			mov		qword ptr [rsp+10h], rdx  
			mov		qword ptr [rsp+8], rcx 	; Because the 8 byte return address is already on the stack

			push	rbp						; Save the base pointer
			mov		rbp, rsp  				; Set RBP to point to the base of the stack frame
			push	rdi  					; Save any of the non-volatile registers (RBX, RBP, RDI, RSI, RSP, R12, R13, R14, and R15) that may be used by the function
			push	rsi
			sub		rsp, 10h  

			mov		rdi, local1
			mov		qword ptr [rsp+08h], rdi; Local variables on the stack
			mov		rdi, local2
			mov		qword ptr [rsp], rdi	; Prolog End

			; --- Stack ---
			; RBP + 40h -> param7			; Param7, 6 and 5 passed via the stack
			; RBP + 38h -> param6
			; RBP + 30h -> param5
			; RBP + 28h -> R9 (param4)		; Param4 in R9
			; RBP + 20h -> R8 (param3)		; Param3 in R8
			; RBP + 18h -> RDX (param2)		; Param2 in RDX
			; RBP + 10h -> RCX (param1)		; Param1 in RCX
			; RBP + 08h -> Return address	; to Caller
			; RBP + 00h -> RBP				; Saved RBP
			; RBP - 08h -> RDI				; Saved RDI  and RSI as non-volatile registers
			; RBP - 10h -> RSI
			; RBP - 18h -> lvar1			; Local variables
			; RBP - 20h -> lvar2
			; -------------

			mov rdi, qword ptr [rbp+40h]	; Param7 is a pointer (64 bit address of a memory location). Double the value it is pointed to
			xor rax, rax					; Clear RAX before putting an int (4 bytes) into it
			mov eax, dword ptr [rdi]		; Put the int value pointed to in RAX
			mov rsi, 2						; The multiplier is in RCX
			push rdx
			mul rsi							; Destroys RDX
			pop rdx
			mov qword ptr [rdi], rax		; Store the doubled value back

			mov		rax, qword ptr [rbp+10h]; Add the 6 parameters and the 2 local variables together - shadow space on stack is used
			add		rax, qword ptr [rbp+18h]
			add		rax, qword ptr [rbp+20h]
			add		rax, qword ptr [rbp+28h]
			add		rax, qword ptr [rbp+30h]
			add		rax, qword ptr [rbp+38h]
			add		rax, qword ptr [rbp-18h]
			add		rax, qword ptr [rbp-20h]; Result in RAX = 81 + 64 + 32 = 177

			mov		rax, rcx				; Add the 6 parameters and the 2 local variables together - alternative way using param values stored in registers
			add		rax, rdx
			add		rax, r8
			add		rax, r9
			add		rax, qword ptr [rbp+30h]
			add		rax, qword ptr [rbp+38h]
			add		rax, qword ptr [rbp-18h]
			add		rax, qword ptr [rbp-20h]; Result in RAX = 81 + 64 + 32 = 177

			lea		rsp, [rbp-10h]			; Discard local variables. Function Epilog Start
			pop		rsi
			pop		rdi
			pop		rbp						; Epilog End

			mov		qword ptr retval, rax	; Save return value

			; Calling C++

			push	rbp						; Save current RSP in RBP before 16 byte alignment
			mov		rbp, rsp
			and		rsp, -10h				; Least significant 4 bits are 0. FFFFFFFFFFFFFFF0

			sub		rsp, 30h				; 2 qword parameters plus 4 qword shadow space for the function to save the 64 bit registers
											; At least 32 bytes shadow space is always needed even if less than 4 parameters are passed

			mov		rax, [param6]			; Last two parameters go to the stack
			mov		qword ptr [rsp+28h], rax
			mov		rax, param5
			mov		qword ptr [rsp+20h], rax  
			mov		r9, qword ptr param4	; Param4 - param1 in R9, R8, RDX and RCX
			mov		r8, qword ptr param3
			mov		rdx, qword ptr param2
			mov		rcx, qword ptr param1

			call	CalledFromASM  
			
			mov		rsp, rbp
			pop		rbp						; Restore original value as RBP was used to save RSP value before stack alignment
			add		rax, qword ptr retval	; Retval was 177 from earlier + C++ function called here adds another 25 totalling to 202

			push rax
			jmp stackframe
return:		pop rax

			ret

			; *********************************************************************************************************************************
			;                                                            Summary
			; *********************************************************************************************************************************

			; *** Caller ***
			; Push decrements RSP by 8 bytes. The stack grows downwards.
			; RSP is first decremented, then the value is stored at the new location pointed to by RSP.
			; Pop does the reverse. The value at the location pointed to by RSP is read, then RSP is incremented by 8 bytes.

stackframe:	push	rbp						; Save current RSP in RBP before 16 byte alignment
			mov		rbp, rsp
			and		rsp, -10h				; Least significant 4 bits are 0. FFFFFFFFFFFFFFF0

			sub		rsp, 30h				; 2 qword parameters plus 4 qword shadow space for the function to save the 64 bit registers
											; At least 32 bytes shadow space is always needed even if less than 4 parameters are passed


			mov		rcx, qword ptr param1	; Param1 - param4 in RCX, RDX, R8, R9
			mov		rdx, qword ptr param2	
			mov		r8, qword ptr param3
			mov		r9, qword ptr param4

			mov		rax, param5				; Last two parameters go to the stack
			mov		qword ptr [rsp+20h], rax 
			mov		rax, param6
			mov		qword ptr [rsp+28h], rax
			
			; --- Stack ---
			; RSP + 28h -> param6			; Param6 and 5 passed via the stack
			; RSP + 20h -> param5
			; RSP + (20h - 00h) -> Regs		; Reserved shadow space for four 64 bit registers used to pass parameters
			; -------------

			mov		rax, continue
			push	rax 					; Push return address onto the stack. Simulate a call to the Callee. Once its job finished, the Caller continues on the continue label

			; *** Callee ***
			; Prolog

			mov		qword ptr [rsp+20h], r9	; Function Prolog Start. Set up local variables and RBP, store them in shadow space allocated by Caller
			mov		qword ptr [rsp+18h], r8  
			mov		qword ptr [rsp+10h], rdx  
			mov		qword ptr [rsp+8], rcx 	; Because the 8 byte return address is already on the stack

			push	rbp						; Save the base pointer
			mov		rbp, rsp				; Set RBP to point to stack frame. RBP + points to parameters. RBP - points to non-volatile registers used by function and local variables
			mov		rdi, 0ffffh				; Just to see where rdi is stored
			push	rdi  					; Save any of the non-volatile registers (RBX, RBP, RDI, RSI, RSP, R12, R13, R14, and R15) that may be used by the function
			sub		rsp, 10h				; Create stack space for local variables

			mov		rdi, local1
			mov		qword ptr [rsp+08h], rdi; Local variables on the stack
			mov		rdi, local2
 			mov		qword ptr [rsp], rdi	; Prolog End

			; --- Stack ---
			; RBP + 40h -> param7			; Param7, 6 and 5 passed via the stack
			; RBP + 38h -> param6
			; RBP + 30h -> param5
			; RBP + 28h -> R9 (param4)		; Param4 in R9
			; RBP + 20h -> R8 (param3)		; Param3 in R8
			; RBP + 18h -> RDX (param2)		; Param2 in RDX
			; RBP + 10h -> RCX (param1)		; Param1 in RCX
			; RBP + 08h -> Return address	; to Caller
			; RBP + 00h -> RBP				; Saved RBP
			; RBP - 08h -> RDI				; Saved RDI as non-volatile
			; RBP - 10h -> lvar1			; Local variables
			; RBP - 18h -> lvar2
			; -------------


			; Callee does its work here
			; Instruction 1
			; Instruction 2
			; ...

			; Epilog
			lea		rsp, [rbp-08h]			; Discard local variables. Function Epilog Start
			pop		rdi
			pop		rbp						; Epilog End

			ret

			; *** Caller ***
continue:	mov     rsp, rbp				; Clean up the stack after the call
			pop		rbp
			jmp     return

ASMFunc endp
end

/*
*** Caller ***
Push (save) RBP
Save current RSP in RBP before 16 byte alignment
Align stack to 16 bytes
Make space on the stack for parameters and shadow space (shadow space is at least 32 bytes even if less than 4 parameters are passed)
Extra parameters (more than 4) are passed on the stack in top-down order
Param4 - param1 in R9, R8, RDX and RCX
			; --- Stack ---
			; RBP + 28h -> param6
			; RBP + 20h -> param5
			; RBP + (20h - 00h) -> Regs
			; -------------

Call Callee function

*** Callee ***
Function prolog start
Save r9, r8, rdx, rcx in shadow space allocated by Caller
Push (save) RBP and RDI (non-volatile registers used by the function)
Allocate stack space for local variables
Set RBP to point to the base of the stack frame
Place local variables on the stack
Function prolog end

			; --- Stack ---
			; RBP + 50h -> param6			; Param6 and 5 passed via the stack
			; RBP + 48h -> param5
			; RBP + 40h -> R9 (param4)		; Param4 in R9
			; RBP + 38h -> R8 (param3)		; Param3 in R8
			; RBP + 30h -> RDX (param2)		; Param2 in RDX
			; RBP + 28h -> RCX (param1)		; Param1 in RCX
			; RBP + 20h -> Return address	; to Caller
			; RBP + 18h -> RBP				; Saved RBP
			; RBP + 10h -> RDI				; Saved RDI as non-volatile
			; RBP + 08h -> lvar1			; Local variables
			; RBP + 00h -> lvar2
			; -------------


Callee does its work here
Instruction 1
Instruction 2
...

Function epilog start
Discard local variables
Pop (restore) RDI and RBP
Function epilog end
Return to Caller

*** Caller ***
Restore original stack as RBP was used to save RSP value before stack alignment
Pop (restore) RBP

*/