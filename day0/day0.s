.intel_syntax noprefix

.section .rodata
msg:
    .ascii "Hello, world!\n"
msglen = . - msg

.section .text
.global _start

_start:
    # write(STDOUT_FILENO, msg, msglen)
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + msg]
    mov rdx, OFFSET msglen    # Use OFFSET to get immediate value
    syscall

    # exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall
