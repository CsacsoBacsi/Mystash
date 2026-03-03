
extern CreateThread: proc
extern ResumeThread: proc
extern GetStdHandle: proc
extern WriteConsoleA: proc
extern CreateFileA: proc
extern GetLastError: proc
extern WriteFile: proc
extern ReadFile: proc
extern CloseHandle: proc
extern SetFilePointer: proc

.data
    j           qword   0				; Pointer to integer variable to be incremented by the thread
    msg         db 'Hello world!', 0    ; Message to be sent to console output
    Num1        qword   43.75
    Num2        qword   458.25
    Filename    db 'D:/Actual/Myfile.txt', 0
    Filename2    db    'G:/"Visual Studio"/VS2019Projects/Tutorial/ASM/ASMTut/ASMTut/MyFile.txt', 0
    fHNDL       qword   0               ; File handle
    fbuffer    db      'This is a test file created using Assembly language.', 0
    fbyteswritten  dword   0            ; Number of bytes written to file
    fbufferIn db      52 dup(0)         ; Buffer to read file contents into
    fbytesread     dword   0            ; Number of bytes read from file


.code
CreateThreadInASM proc ; Gets called from C++. Creates a thread that runs ThreadStartProc
    ; RCX - pointer to integer to be incremented by the thread (variable j in C++ code))
    ; *** Create the thread ***
    mov qword ptr j, rcx         ; Store the pointer to integer in global variable j - incremented later by the thread proc. Indirect method
    push rbp
    mov rbp, rsp
    push 0                       ; Thread id (last parameters through stack)
    push 04h                     ; Creation flags (0x04h means the thread runs suspended))
    sub rsp, 20h                 ; Shadow space
    ; mov r9, rcx                ; Pass pointer to integer as parameter to thread start proc. Direct method
    mov r9, 0                    ; No parameter to thread start proc
    mov rcx, 0                   ; Default security attributes
    mov rdx, 0                   ; Default stack size
    mov r8, ThreadStartProc      ; Address of thread start procedure

    call CreateThread            ; Call CreateThread API
    mov rsp, rbp
    pop rbp
    mov rcx, rax                 ; Get thread handle returned in RAX

    push rbp
    mov rbp, rsp
    sub rsp, 20h                 ; Shadow space
    call ResumeThread            ; Resume the thread (it was created in suspended state)
    mov rsp, rbp
    pop rbp

    ; *** Get std handle to write to console *** 
    push rbp
    mov rbp, rsp
    sub rsp, 20h                 ; Shadow space
    mov rcx, -11d                ; Standard output handle
    call GetStdHandle            ; Get standard output handle
    mov rsp, rbp
    pop rbp

    push rbp
    mov rbp, rsp
    push 0                       ; 5th parameter is reserved (NULL)
    sub rsp, 20h                 ; Shadow space
    mov r9, 0                    ; Characters written (out param)
    mov r8, 0Ch                  ; Characters to write (12)
    lea rdx, msg                 ; Char buffer that stores the message
    mov rcx, rax                 ; RAX from previous call holds the handle to std output
    call WriteConsoleA
    mov rsp, rbp
    pop rbp

    ; *** Add two floating point numbers and return the result in XMM0 *** 
    movsd    xmm0, Num1
    addsd    xmm0, Num2

    ; *** Create a file ***
    push rbp
    mov rbp, rsp
    ;and  rsp, -10h		         ; Least significant 4 bits are 0. FFFFFFFFFFFFFFF0


    mov rax, 0h
    ;push rax                     ; File template
    mov rax, 080h
    push rax                     ; Flags and attributes - default
    mov rax, 01h
    push rax                     ; Creation disposition - CREATE_NEW
    sub rsp, 20h                 ; Shadow space

    mov rcx, offset Filename     ; File name
    mov rdx, 040000000h ; Desired access - GENERIC_WRITE
    mov r8, 0h                   ; Share mode - FILE_SHARE_READ | FILE_SHARE_WRITE
    mov r9, 0h                   ; Security attributes - default
    call CreateFileA
    mov fHNDL, rax               ; Store file handle in global variable fHNDL
    call GetLastError            ; Get error details
    mov rsp, rbp
    pop rbp

    ; *** Write to file ***
    push rbp
    mov rbp, rsp
    mov rcx, fHNDL               ; File handle
    mov rdx, offset fbuffer      ; Data buffer
    mov r8, 52                   ; Number of bytes to write
    mov r9, offset fbyteswritten ; Number of bytes written (out param)
    push 0                       ; Overlapped structure - NULL
    sub rsp, 20h                 ; Shadow space
    call WriteFile
    mov rsp, rbp
    pop rbp

    ; *** Close handle ***
    push rbp
    mov rbp, rsp
    mov rcx, fHNDL               ; File handle
    call CloseHandle

    ; *** Open file for read ***
    push rbp
    mov rbp, rsp

    mov rax, 0h
    push rax                     ; File template
    mov rax, 080h
    push rax                     ; Flags and attributes - default
    mov rax, 03h
    push rax                     ; Creation disposition - OPEN_EXISTING
    sub rsp, 20h                 ; Shadow space

    mov rcx, offset Filename     ; File name
    mov rdx, 080000000h          ; Desired access - GENERIC_READ
    mov r8, 1h                   ; Share mode - FILE_SHARE_READ | FILE_SHARE_WRITE
    mov r9, 0h                   ; Security attributes - default
    call CreateFileA
    mov fHNDL, rax               ; Store file handle in global variable fHNDL
    call GetLastError            ; Get error details
    mov rsp, rbp
    pop rbp

    ; *** Set file pointer ***
    push rbp
    mov rbp, rsp
    mov rcx, fHNDL               ; File handle
    mov rdx, 0
    mov r8, 0
    mov r9, 0
    call SetFilePointer
    mov rsp, rbp
    pop rbp

    ; *** Read from file ***
    push rbp
    mov rbp, rsp
    mov rcx, fHNDL               ; File handle
    mov rdx, offset fbufferIn    ; Data buffer to read into
    mov r8, 5                    ; Number of bytes to read
    mov r9, offset fbytesread    ; Number of bytes read (out param)
    push 0                       ; Overlapped structure - NULL
    sub rsp, 20h                 ; Shadow space
    call ReadFile
    call GetLastError            ; Get error details
    mov rsp, rbp
    pop rbp

    ret

CreateThreadInASM endp

ThreadStartProc proc
    push rcx
    ; inc dword ptr [rcx]	; Increment the integer value pointed to by RCX - direct method
    mov rcx, [j]            ; Get pointer to integer variable from global variable j
    inc dword ptr [rcx]     ; Indirect method
    pop rcx
    ret
ThreadStartProc endp




end