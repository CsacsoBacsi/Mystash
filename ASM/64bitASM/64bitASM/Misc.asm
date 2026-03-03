
option casemap:none							; Labels and func names are case-sensitive

public start								; Otherwise linker throws an error
.code										; Code section
start:

    mov rax, 2 ; Just to test if debug stepping through instructions works
    mov rbp, rsp
    mov rcx, 5
    push rbp
    pop rsp
    xor		rax, rax



end