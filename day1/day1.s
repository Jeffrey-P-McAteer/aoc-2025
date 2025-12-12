# add_ten.s - Read file from ARG1, add 10 to each number, print sum
# Intel syntax for x86-64 Linux (Zig-compatible)

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
    .lcomm file_buffer, 4096      # Buffer for file contents
    .lcomm line_buffer, 256       # Buffer for current line
    .lcomm num_buffer, 32         # Buffer for number to string conversion
    .lcomm fd, 8                  # File descriptor
    .lcomm total_sum, 8           # Running sum of all numbers

.section .text
    .global _start

_start:
    # At entry: rsp points to argc
    # [rsp] = argc
    # [rsp+8] = argv[0]
    # [rsp+16] = argv[1]
    # [rsp+24] = argv[2]
    # etc.

    # Check argc
    mov rax, [rsp]                # Load argc
    cmp rax, 2                    # Need exactly 2 args (program name + filename)
    jne usage_error

    # Get argv[1] (the filename)
    mov r15, [rsp + 16]           # Load pointer to filename string

    # Initialize total sum to 0
    mov qword ptr [rip + total_sum], 0

    # Open file
    mov rax, 2                    # sys_open
    mov rdi, r15                  # filename from argv[1]
    mov rsi, 0                    # O_RDONLY
    mov rdx, 0
    syscall

    cmp rax, 0
    jl open_error                 # Exit if open failed
    mov [rip + fd], rax           # Save file descriptor

    # Read entire file into buffer
    mov rax, 0                    # sys_read
    mov rdi, [rip + fd]
    lea rsi, [rip + file_buffer]
    mov rdx, 4096
    syscall

    cmp rax, 0
    jle close_and_exit            # Exit if read failed or empty
    mov r12, rax                  # Save bytes read in r12

    # Close file
    mov rax, 3                    # sys_close
    mov rdi, [rip + fd]
    syscall

    # Process buffer line by line
    xor r13, r13                  # r13 = current position in file_buffer

process_lines:
    cmp r13, r12
    jge print_sum                 # Done if we've processed all bytes

    # Extract one line
    xor r14, r14                  # r14 = position in line_buffer
    lea rsi, [rip + file_buffer]
    lea rdi, [rip + line_buffer]

extract_line:
    cmp r13, r12
    jge line_complete             # End of file

    mov al, byte ptr [rsi + r13]
    inc r13

    cmp al, 10                    # Check for newline
    je line_complete

    cmp r14, 255                  # Prevent buffer overflow
    jge extract_line

    mov byte ptr [rdi + r14], al
    inc r14
    jmp extract_line

line_complete:
    # Null terminate the line
    mov byte ptr [rdi + r14], 0

    # Check if line is empty
    cmp r14, 0
    je process_lines

    # Parse line as integer
    push r12                      # Save registers
    push r13
    push r14

    lea rdi, [rip + line_buffer]
    mov rsi, r14                  # Line length
    call parse_integer

    pop r14
    pop r13
    pop r12

    # rax now contains the parsed number
    mov rbx, rax                  # Save original number in rbx

    # Add to total sum
    add [rip + total_sum], rax

    # Print: "number + 10 = result"
    # First print the original number
    push r12
    push r13
    push r14

    mov rdi, rbx
    call print_number

    # Print " + 10 = "
    mov rax, 1                    # sys_write
    mov rdi, 1                    # stdout
    lea rsi, [rip + plus_ten_msg]
    mov rdx, plus_ten_len
    syscall

    # Print the number + 10
    add rbx, 10
    mov rdi, rbx
    call print_number

    # Print newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + newline]
    mov rdx, 1
    syscall

    pop r14
    pop r13
    pop r12

    jmp process_lines

print_sum:
    # Print "Total sum: "
    mov rax, 1                    # sys_write
    mov rdi, 1                    # stdout
    lea rsi, [rip + sum_msg]
    mov rdx, sum_len
    syscall

    # Print the total sum
    mov rdi, [rip + total_sum]
    call print_number

    # Print newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + newline]
    mov rdx, 1
    syscall

    jmp exit_success

# Function: parse_integer
# Input: rdi = pointer to string, rsi = length
# Output: rax = parsed integer
parse_integer:
    push rbx
    push rcx

    xor rax, rax                  # Result accumulator
    xor rcx, rcx                  # Index
    xor rbx, rbx                  # Temp for digit
    mov r8, 1                     # Sign (1 = positive, -1 = negative)

    # Check for negative sign
    cmp byte ptr [rdi], '-'
    jne parse_loop
    inc rcx                       # Skip the '-'
    mov r8, -1

parse_loop:
    cmp rcx, rsi
    jge parse_done

    movzx rbx, byte ptr [rdi + rcx]

    # Check if digit
    cmp rbx, '0'
    jl parse_done                 # Stop at non-digit
    cmp rbx, '9'
    jg parse_done                 # Stop at non-digit

    # Convert ASCII to digit
    sub rbx, '0'

    # result = result * 10 + digit
    imul rax, 10
    add rax, rbx

    inc rcx
    jmp parse_loop

parse_done:
    # Apply sign
    imul rax, r8

    pop rcx
    pop rbx
    ret

# Function: print_number
# Input: rdi = number to print
# Output: none
print_number:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov rax, rdi                  # Number to convert
    lea rsi, [rip + num_buffer]
    add rsi, 31                   # Point to end of buffer
    mov byte ptr [rsi], 0         # Null terminate
    dec rsi

    # Handle negative numbers
    mov r8, 1                     # Sign flag
    cmp rax, 0
    jge convert_loop
    neg rax                       # Make positive
    mov r8, -1                    # Remember it was negative

convert_loop:
    xor rdx, rdx
    mov rbx, 10
    div rbx                       # rax = rax / 10, rdx = remainder

    add dl, '0'                   # Convert to ASCII
    mov byte ptr [rsi], dl
    dec rsi

    cmp rax, 0
    jne convert_loop

    # Add negative sign if needed
    cmp r8, -1
    jne print_it
    mov byte ptr [rsi], '-'
    dec rsi

print_it:
    inc rsi                       # Move to first character

    # Calculate length
    lea rdx, [rip + num_buffer]
    add rdx, 31
    sub rdx, rsi

    # Print the number
    push rax                      # Save rax before syscall
    mov rax, 1                    # sys_write
    mov rdi, 1                    # stdout
    # rsi already points to start of number
    # rdx already has length
    syscall
    pop rax

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

usage_error:
    mov rax, 1                    # sys_write
    mov rdi, 2                    # stderr
    lea rsi, [rip + usage_msg]
    mov rdx, usage_len
    syscall

    mov rax, 60                   # sys_exit
    mov rdi, 1                    # Error code
    syscall

open_error:
    mov rax, 1                    # sys_write
    mov rdi, 2                    # stderr
    lea rsi, [rip + error_msg]
    mov rdx, error_len
    syscall

    mov rax, 60                   # sys_exit
    mov rdi, 1                    # Error code
    syscall

close_and_exit:
    mov rax, 3                    # sys_close
    mov rdi, [rip + fd]
    syscall
    jmp exit_success

exit_success:
    mov rax, 60                   # sys_exit
    xor rdi, rdi                  # Success code
    syscall
