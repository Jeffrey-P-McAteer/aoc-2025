# add_ten_debug.s - Simplified version with debugging
.intel_syntax noprefix

.section .data
    usage_msg: .ascii "Usage: ./add_ten <filename>\n"
    usage_len = . - usage_msg

    plus_ten_msg: .ascii " + 10 = "
    plus_ten_len = . - plus_ten_msg

    sum_msg: .ascii "\nTotal sum: "
    sum_len = . - sum_msg

    newline: .byte 10
    error_msg: .ascii "Error: Could not open file\n"
    error_len = . - error_msg

.section .bss
    .lcomm file_buffer, 4096
    .lcomm line_buffer, 256
    .lcomm num_buffer, 32
    .lcomm total_sum, 8

.section .text
    .global _start

_start:
    # Check argc
    mov rax, [rsp]
    cmp rax, 2
    jne usage_error

    # Get argv[1]
    mov r15, [rsp + 16]

    # Initialize sum
    mov qword ptr [rip + total_sum], 0

    # Open file
    mov rax, 2
    mov rdi, r15
    mov rsi, 0
    mov rdx, 0
    syscall

    cmp rax, 0
    jl open_error
    mov r12, rax              # Save fd in r12

    # Read file
    mov rax, 0
    mov rdi, r12              # fd
    lea rsi, [rip + file_buffer]
    mov rdx, 4096
    syscall

    cmp rax, 0
    jle close_file
    mov r13, rax              # bytes read in r13

    # Close file
    mov rax, 3
    mov rdi, r12
    syscall

    # Process lines
    xor r14, r14              # position in file_buffer

process_lines:
    cmp r14, r13
    jge print_sum

    # Extract line
    xor r15, r15              # position in line_buffer
    lea rsi, [rip + file_buffer]
    lea rdi, [rip + line_buffer]

extract_line:
    cmp r14, r13
    jge line_done

    mov al, byte ptr [rsi + r14]
    inc r14

    cmp al, 10
    je line_done

    cmp r15, 255
    jge extract_line

    mov byte ptr [rdi + r15], al
    inc r15
    jmp extract_line

line_done:
    cmp r15, 0
    je process_lines

    mov byte ptr [rdi + r15], 0

    # Parse number
    lea rdi, [rip + line_buffer]
    mov rsi, r15
    call parse_int

    mov rbx, rax              # save number
    add [rip + total_sum], rax

    # Print number
    mov rdi, rbx
    call print_num

    # Print " + 10 = "
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + plus_ten_msg]
    mov rdx, plus_ten_len
    syscall

    # Print number + 10
    add rbx, 10
    mov rdi, rbx
    call print_num

    # Print newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + newline]
    mov rdx, 1
    syscall

    jmp process_lines

print_sum:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + sum_msg]
    mov rdx, sum_len
    syscall

    mov rdi, [rip + total_sum]
    call print_num

    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + newline]
    mov rdx, 1
    syscall

    jmp exit_ok

parse_int:
    push rbx
    push rcx
    push rdx

    xor rax, rax
    xor rcx, rcx
    mov r8, 1

    cmp byte ptr [rdi], '-'
    jne .parse_loop
    inc rcx
    mov r8, -1

.parse_loop:
    cmp rcx, rsi
    jge .parse_done

    movzx rbx, byte ptr [rdi + rcx]
    cmp rbx, '0'
    jl .parse_done
    cmp rbx, '9'
    jg .parse_done

    sub rbx, '0'
    imul rax, 10
    add rax, rbx
    inc rcx
    jmp .parse_loop

.parse_done:
    imul rax, r8
    pop rdx
    pop rcx
    pop rbx
    ret

print_num:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov rax, rdi
    lea rsi, [rip + num_buffer]
    add rsi, 31
    mov byte ptr [rsi], 0
    dec rsi

    mov r8, 1
    cmp rax, 0
    jge .convert
    neg rax
    mov r8, -1

.convert:
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add dl, '0'
    mov byte ptr [rsi], dl
    dec rsi
    cmp rax, 0
    jne .convert

    cmp r8, -1
    jne .print
    mov byte ptr [rsi], '-'
    dec rsi

.print:
    inc rsi
    lea rdx, [rip + num_buffer]
    add rdx, 31
    sub rdx, rsi

    mov rax, 1
    mov rdi, 1
    syscall

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

usage_error:
    mov rax, 1
    mov rdi, 2
    lea rsi, [rip + usage_msg]
    mov rdx, usage_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

open_error:
    mov rax, 1
    mov rdi, 2
    lea rsi, [rip + error_msg]
    mov rdx, error_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

close_file:
    mov rax, 3
    mov rdi, r12
    syscall

exit_ok:
    mov rax, 60
    xor rdi, rdi
    syscall
