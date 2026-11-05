BITS 32
GLOBAL _start

%macro PRINT 2
    mov ebx, 1
    mov ecx, %1
    mov edx, %2
    call write_all
%endmacro

%macro SAVE 2
    mov ebx, [receipt_fd]
    mov ecx, %1
    mov edx, %2
    call write_all
%endmacro

SECTION .data
    filename db "receipt.txt", 0

    menu db 10
         db "+----------------------------------------------------+", 10
         db "|                 GEORGETTE EATERY                   |", 10
         db "+----------------------------------------------------+", 10
         db "| A. Rice: Plain Rice                 Php  5.00       |", 10
         db "| B. Rice: Java Rice                  Php 10.00       |", 10
         db "| C. Ulam 1: Fish                     Php 35.00       |", 10
         db "| D. Ulam 2: Pork                     Php 50.00       |", 10
         db "| E. Ulam 3: Vegetables               Php 20.00       |", 10
         db "| F. Dessert: Saging con yelo         Php 60.00       |", 10
         db "+----------------------------------------------------+", 10
    menu_len equ $ - menu

    order_prompt db "Enter your order [A-F]: "
    order_prompt_len equ $ - order_prompt

    ordered_msg db "You ordered "
    ordered_msg_len equ $ - ordered_msg

    again_prompt db "Do you want to order again? [Y/N]: "
    again_prompt_len equ $ - again_prompt

    invalid_order db "Invalid order. Please enter A to F.", 10
    invalid_order_len equ $ - invalid_order

    invalid_again db "Invalid answer. Please enter Y or N.", 10
    invalid_again_len equ $ - invalid_again

    thanks db 10, "Thank you! Please come again!", 10, 10
    thanks_len equ $ - thanks

    file_error db "Error: Unable to read or write the receipt.", 10
    file_error_len equ $ - file_error

    input_error db "Error: Unable to read input.", 10
    input_error_len equ $ - input_error

    receipt_header db "======================================", 10
                   db "          GEORGETTE EATERY", 10
                   db "                RECEIPT", 10
                   db "======================================", 10
    receipt_header_len equ $ - receipt_header

    receipt_footer db "======================================", 10
                   db "Thank you! Please come again!", 10
    receipt_footer_len equ $ - receipt_footer

    plain_rice db "Plain Rice: Php 5.00", 10
    plain_rice_len equ $ - plain_rice

    java_rice db "Java Rice: Php 10.00", 10
    java_rice_len equ $ - java_rice

    fish db "Fish: Php 35.00", 10
    fish_len equ $ - fish

    pork db "Pork: Php 50.00", 10
    pork_len equ $ - pork

    vegetables db "Vegetables: Php 20.00", 10
    vegetables_len equ $ - vegetables

    dessert db "Saging con yelo: Php 60.00", 10
    dessert_len equ $ - dessert

    items:
        dd plain_rice, plain_rice_len
        dd java_rice, java_rice_len
        dd fish, fish_len
        dd pork, pork_len
        dd vegetables, vegetables_len
        dd dessert, dessert_len

SECTION .bss
    receipt_fd resd 1
    key resb 1
    receipt_buffer resb 512

SECTION .text

_start:
    call create_receipt

order_loop:
    call display_menu

get_order:
    PRINT order_prompt, order_prompt_len
    call read_choice

    cmp eax, -1
    je finish_ordering

    sub eax, 'A'
    cmp eax, 5
    ja bad_order

    mov esi, [items + eax * 8]
    mov edi, [items + eax * 8 + 4]

    call display_order
    call save_order

ask_again:
    PRINT again_prompt, again_prompt_len
    call read_choice

    cmp eax, 'Y'
    je order_loop

    cmp eax, 'N'
    je finish_ordering

    cmp eax, -1
    je finish_ordering

    PRINT invalid_again, invalid_again_len
    jmp ask_again

bad_order:
    PRINT invalid_order, invalid_order_len
    jmp get_order

finish_ordering:
    SAVE receipt_footer, receipt_footer_len

    mov eax, 6
    mov ebx, [receipt_fd]
    int 0x80
    test eax, eax
    js fatal_file

    PRINT thanks, thanks_len
    call display_receipt

    mov eax, 1
    xor ebx, ebx
    int 0x80

create_receipt:
    mov eax, 8
    mov ebx, filename
    mov ecx, 0o644
    int 0x80

    test eax, eax
    js fatal_file

    mov [receipt_fd], eax
    SAVE receipt_header, receipt_header_len
    ret

display_menu:
    PRINT menu, menu_len
    ret

display_order:
    PRINT ordered_msg, ordered_msg_len
    PRINT esi, edi
    ret

save_order:
    SAVE esi, edi
    ret

read_choice:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    xor esi, esi
    xor edi, edi

.read:
    mov eax, 3
    xor ebx, ebx
    mov ecx, key
    mov edx, 1
    int 0x80

    test eax, eax
    js fatal_input
    jz .eof

    movzx eax, byte [key]

    cmp al, 10
    je .line_end

    cmp al, 13
    je .read

    test esi, esi
    jnz .extra_character

    mov edi, eax
    mov esi, 1
    jmp .read

.extra_character:
    mov esi, 2
    jmp .read

.eof:
    test esi, esi
    jnz .line_end

    mov eax, -1
    jmp .done

.line_end:
    xor eax, eax
    cmp esi, 1
    jne .done

    mov eax, edi
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 32

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

write_all:
    pushad

.write:
    test edx, edx
    jz .done

    mov eax, 4
    int 0x80

    test eax, eax
    jle fatal_file

    add ecx, eax
    sub edx, eax
    jmp .write

.done:
    popad
    ret

display_receipt:
    mov eax, 5
    mov ebx, filename
    xor ecx, ecx
    int 0x80

    test eax, eax
    js fatal_file

    mov [receipt_fd], eax

.read:
    mov eax, 3
    mov ebx, [receipt_fd]
    mov ecx, receipt_buffer
    mov edx, 512
    int 0x80

    test eax, eax
    js fatal_file
    jz .close

    mov edx, eax
    mov ebx, 1
    mov ecx, receipt_buffer
    call write_all
    jmp .read

.close:
    mov eax, 6
    mov ebx, [receipt_fd]
    int 0x80

    test eax, eax
    js fatal_file
    ret

fatal_input:
    mov ecx, input_error
    mov edx, input_error_len
    jmp fatal_exit

fatal_file:
    mov ecx, file_error
    mov edx, file_error_len

fatal_exit:
    mov eax, 4
    mov ebx, 2
    int 0x80

    mov eax, 1
    mov ebx, 1
    int 0x80