; This function performs integer division with remainder. It treats the dividend, divisor, quotient, and remainder as numbers 
; encoded in two's complement. The first two parameters define the dividend: x is a pointer to a non-empty array of n 64-bit 
; numbers, where the dividend occupies 64 * n bits and is stored in little-endian format. The third parameter y is the divisor. 
; The function returns the remainder of the division, and the quotient is stored back in the array.

section .text
global mdiv

mdiv:
    ; Arguments:
    ; rdi - pointer to the array (x)
    ; rsi - size of the array (n)
    ; rdx - divisor (y)
    
    ; r11 - holds sign of divisor and dividend (+, +) - 0; (-, +) - 1; (+, -) - 2; (-, -) - 3
    xor r11, r11                ; Clearing r11 to store sign information
    mov r9, rdx                 ; Storing divisor in r9
    xor rdx, rdx                ; Clearing rdx to use it for division

    ; Check if the divisor is zero
    test r9, r9
    jz .div_by_zero

    ; Check if the divisor is negative and adjust its sign
    test r9, r9
    jns .check_array            ; If divisor is positive, jump to array check

    ; Divisor is negative, invert its sign
    inc r11                     ; Marking negative divisor
    neg r9

.check_array:
    ; Check if the last value in the array is negative, indicating the dividend is negative
    mov r8, rsi                 ; r8 is the iterator
    dec r8                       ; Move to the last element in the array

    mov rax, [rdi + r8*8]       ; Load the last value in the array into rax
    test rax, rax
    js .invert_bits

.loop_start:
    cmp r8, 0                   ; Check if we are done with the array
    jl .return_result

    ; Load the current value from the array
    mov rax, [rdi + r8*8]

    ; Perform division (128-bit division of rax by the divisor in r9)
    div r9

    ; Store the quotient back in the array
    mov [rdi + r8*8], rax

    dec r8                       ; Move to the next element in the array
    jmp .loop_start

.return_result:
    ; Check and adjust the sign of the quotient and remainder
    cmp r11, 0
    je .done

    cmp r11, 1
    je .status_1

    cmp r11, 2
    je .status_2

    cmp r11, 3
    je .status_3

.status_1:
    jmp .neg_array

.status_2:
    neg rdx                      ; Invert the sign of the remainder
    jmp .neg_array

.status_3:
    neg rdx
    jmp .done

.done:
    ; Return the remainder
    mov rax, rdx
    mov rdx, r9                 ; Restore divisor for future use

    ret

.invert_bits:
    ; Inverts the bits of the number in the array if the last value is negative
    add r11, 2                  ; Mark array as negative
    mov rcx, 1                  ; rcx - carry flag holder
    mov r8, 0                   ; Iterator

.invert_loop:
    cmp r8, rsi
    jge .return

    test rcx, rcx
    jz .set_carry               ; Set carry flag if rcx is 0
    stc

.set_carry:
    ; Invert the bits of the current value in the array
    mov rax, [rdi + r8*8]
    not rax
    adc rax, 0                  ; Add carry flag to the inversion
    jc .carry_set               ; If CF == 1, set carry flag

    xor rcx, rcx                ; If CF == 0, reset carry flag

.carry_set:
    mov [rdi + r8*8], rax
    inc r8
    jmp .invert_loop

.return:
    ; Check for potential overflow
    cmp r9, -1
    je .potential_overflow
    mov r8, rsi
    dec r8
    jmp .loop_start

.potential_overflow:
    ; Handle overflow by setting a special value
    mov rax, 0x8000000000000000 ; Overflow indication value
    mov r8, rsi
    dec r8
    cmp rax, [rdi + r8*8]
    je .div_by_zero             ; Check if last value overflows
    jmp .loop_start

.neg_array:
    ; Invert the sign of all elements in the array
    mov rcx, 1                  ; Carry flag holder
    mov r8, 0                   ; Iterator

.neg_loop:
    cmp r8, rsi
    jge .done

    test rcx, rcx
    jz .set1_carry
    stc

.set1_carry:
    ; Invert the sign of the current element
    mov rax, [rdi + r8*8]
    not rax
    adc rax, 0
    jc .carry1_set              ; If carry flag is set, adjust the carry

    xor rcx, rcx                ; Reset carry flag

.carry1_set:
    mov [rdi + r8*8], rax
    inc r8
    jmp .neg_loop

.div_by_zero:
    ; Handle division by zero or overflow errors
    mov r9, 0
    div r9                      ; Trigger division by zero error
