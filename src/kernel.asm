;; ============================================================================
;; RetrOS
;; ============================================================================
;; v0.1.4
;; ----------------------------------------------------------------------------
;; Retros kernel

	[org 0x0000]

	push cs
	pop ds			; Align the data segment with the code segment

	mov bp, 0x7DFF		; We'll overwrite the boot sector with the
	mov sp, bp		; stack, giving us about 30k for the stack,
				; from 00500 - 07DFF

	mov [BOOT_DRIVE], dl	; Store the boot-drive number

	;; ===================================================================
	;; Initialise OS Call Interrupt
	;; ===================================================================
	;; Create an interrupt (0xF0) to handle system call. System calls will
	;; be done by calling this interrupt with bx holding the number of
	;; the required command (see OS Call Handler below).
	;; -------------------------------------------------------------------
os_init_interrupt:
	push word 0		; BIOS interrupt table is in segment 0x0000
	pop es
	mov [es:4 * 0xF0], word os_call ; Store the offset address of the handler
	mov [es:4 * 0xF0 + 2], cs 	; The handler is in the current code segment

	;; Initialisation complete -- jump to the actual starting-point
	jmp start_os

	;; ===================================================================
	;; OS Call Handler & OS Call Table
	;; ===================================================================
	;; Calls made via the OS Call interrupt will go via this handler,
	;; which uses the table of routine addresses (os_call_table) to route
	;; the call to the required function.
	;;
	;; Put the OS Call Number into bx, then call INT 0xF0
	;; -------------------------------------------------------------------
os_call:
	cmp bx, os_call_max	; Check that the call number is within range
	jg os_invalid_call	; Report an error if it isn't
	shl bx, 1		; Each entry in the call table is two bytes,
				; so multiply the call number by two to get
				; the correct offset
	jmp near [cs:os_call_table + bx] ; Jump to the location of actual routine

	os_call_max equ 1	; Highest OS Call number. Update this
				; whenever a new entry is added to the
				; call table
	
os_call_table:
				; OS Call : Action
				; --------:-----------------------------------
	dw os_no_op		; 0x00	  : Null call, does nothing
	dw os_clear_screen	; 0x01	  : Clear Screen

	;; ===================================================================
	;; OS Call Redirection functions
	;; ===================================================================
	;; These are the functions listed in the OS Call Table above, and in
	;; the main they simply call the matching internal functions. This
	;; allows the internal functions to be called from within the kernel
	;; without having the extra setup and overhead of calling them via the
	;; interrupt.
	;; -------------------------------------------------------------------
os_no_op:
	iret

os_clear_screen:
	call clear_screen
	iret
	
os_invalid_call:
	mov si, MSG_INVALID_OS_CALL
	call print_string
	push dx
	mov dx, bx
	call print_hex
	call print_crlf
	pop dx
	iret

	;; ===================================================================
	;; Clear Screen
	;; ===================================================================
	;; This actually sets the video mode, which has the inevitable
	;; side-effect of resetting the screen display.
	;; -------------------------------------------------------------------
clear_screen:
	push ax
	push bx
	mov ah, 0x00		; Set video mode
	mov al, 0x03		; Alternatives: 0x03 (text), 0x12 or 0x13 (graphics)
	int 0x10

	mov ah, 0x0B		; Set background colour
	xor bh, bh
	mov bl, CL_BLUE		; Select colour
	int 0x10
	pop bx
	pop ax
	ret

	;; ===================================================================
	;; Main Entry Point
	;; ===================================================================
	;; Everything should be set up before jumping to this point -- see the
	;; top of this file.
	;; -------------------------------------------------------------------
start_os:
	mov bx, 0x01		; Test of the OS Call system
	int 0xF0
	;; call clear_screen
	
print_version_number:
	mov si, version		; Fetch the address of the start of the version string
	call print_string	; Print the version string
	call print_crlf

	;; Test for pixel-plotting. Only works if a graphics mode was selected
	;; in clear_screen (above).
	
	mov dx, 0x0020		; Pixel row
	mov cx, 0x0020		; Pixel column
	mov al, CL_RED		; Pixel colour
	call plot		; Plot the pixel
	
	mov dx, 0x0300		; Row 3, col 0
	call cursor_at
get_input:
	call get_char
exit:
	jmp get_input		; Loop forever

	;; ===================================================================
	;; Print Character
	;; ===================================================================
	;; Prints the character in AL at the current cursor position
	;; -------------------------------------------------------------------
print_char:
	push ax
	push bx
	push cx
	mov cx, 0x0001	 	; Only write the character once
	;; First check for special characters and handle them
	cmp al, 0x0D		; Carriage return
	je .do_carriage_return
	cmp al, 0x0A		; Line-feed
	je .do_line_feed
	cmp al, 0x08		; Backspace
	je .do_backspace
	cmp al, 0x20		; Low-range non-printable characters
	jl .do_non_printable
	cmp al, 0x7F		; High-range non-printable characters
	jg .do_non_printable
	jmp .do_print		; We have a standard ASCII character
.do_carriage_return:
	call cursor_down
	call cursor_line_feed
	jmp .exit
.do_line_feed:
	call cursor_line_feed
	jmp .exit
.do_backspace:
	call cursor_left
	;; Print a space (overwriting any existing character on-screen)
	mov al, " "
	mov ah, 0x09
	int 0x10
	jmp .exit
.do_non_printable:
	mov al, "."		; For non-printable characters, print a .
.do_print:	
	mov bx, CL_SILVER	; Grey text
	mov ah, 0x09		; Print Character command
	int 0x10		; Interrupt 10 -- video commands
	call cursor_right
.exit:
	pop cx
	pop bx
	pop ax
	ret
	
	;; ===================================================================
	;; Print String
	;; ===================================================================
	;; Prints the zero-terminated string pointed to by si
	;; -------------------------------------------------------------------
print_string:
	push ax
	push si
.next_char:
	cld			; Clear the direction flag (print forwards)
	lodsb			; Get the character from the string
	or al, al		; Is it zero (end of string indicator)?
	jz .exit		; If yes, we're done
	call print_char
	jmp .next_char		; Loop back for the next character
.exit:
	pop si
	pop ax
	ret

	;; ===================================================================
	;; Print Hex
	;; ===================================================================
	;; Prints (in hex) the value held in dx
	;; -------------------------------------------------------------------
print_hex:
	push dx
	mov bl, dh              ; Print the high-byte  
	call print_hex_byte
	mov bl, dl		; Print the low-byte
	call print_hex_byte
	pop dx
	ret
                    
	;; ===================================================================
	;; Print Hex Byte
	;; ===================================================================
	;; Prints (in hex) the value held in bl
	;; -------------------------------------------------------------------
print_hex_byte:                                     
	push ax    
	push bx
	push di
	push si
	mov di, .hex_buffer + 1	; Point di to the end of the buffer
	std			; Set the direction flag (we are decrementing)
.next_nybble:
	mov al, bl		; Copy the low-byte of the number
	and al, 0x0F		; Zero the high-nybble
	cmp al, 0x0A		; Is the result greater than 10?
	jnc .use_alpha_chars	; Yes, use 'A' - 'F' for 10 - 15
	add al, 0x30		; Convert to ASCII (add 48)
	jmp .put_char		; Put the resulting character into the buffer
.use_alpha_chars:
	add al, 0x37		; Convert to hex (A-F) ASCII values (add 55)
.put_char:
	stosb			; Copy al to [di] and decrement di
	shr bl, 0x04		; Next nybble fo the number we're printing
	cmp di, .hex_buffer - 1	; Start of buffer?
	jnz .next_nybble	; No -- get the next nybble
	mov si, .hex_buffer	; Done. Print the result
	call print_string
	pop si
	pop di
	pop bx
	pop ax
	ret
.hex_buffer:
	db '00', 0

	;; ===================================================================
	;; Hex Dump
	;; -------------------------------------------------------------------
	;; Prints out the hex values of the bytes from address si for a total 
	;; of cx bytes.
	;; -------------------------------------------------------------------
hex_dump:
	push ax
	push bx
	push cx
	push si
.next_byte:
	lodsb
	mov bl, al
	call print_hex_byte
	call print_space
	loop .next_byte, cx
	pop si
	pop cx
	pop bx
	pop ax
	ret
	
print_crlf:
	push si
	mov si, CRLF
	call print_string
	pop si
	ret
	
print_space:
	push si
	mov si, SPACE
	call print_string
	pop si
	ret
	
	;; ===================================================================
	;; Disk Read
	;; -------------------------------------------------------------------
	;; Loads DH sectors to ES:BX from drive DL sector CL
	;; -------------------------------------------------------------------
disk_read:
	push dx 		; Store DX on stack so later we can recall
				; how many sectors were request to be read,
				; even if it is altered in the meantime
	mov ah, 0x02 		; BIOS read sector function
	mov al, dh 		; Read DH sectors
	mov ch, 0x00 		; Select cylinder 0
	mov dh, 0x00 		; Select head 0
	int 0x13 		; BIOS interrupt
	jc disk_error		; Jump if error (i.e. carry flag set)
	pop dx			; Restore DX from the stack
	cmp dh, al		; if AL (sectors read) != DH (sectors expected)
	jne disk_error		; display error message
	ret
	
disk_error :
	mov si, DISK_ERROR_MSG      
	call print_string
	jmp $

	;; ===================================================================
	;; Get Char
	;; -------------------------------------------------------------------
	;; Reads a single character from the keyboard into AL and echoes it
	;; to the screen.
	;; -------------------------------------------------------------------
get_char:
	xor ah, ah		; AH = 0: input a single character
	int 0x16		; Interrupt, inputs single character into AL
	call print_char		; Echo the returned character
.exit:
	ret
	
	;; ===================================================================
	;; Cursor At
	;; -------------------------------------------------------------------
	;; Positions the cursor at row dh, col dl
	;; -------------------------------------------------------------------
cursor_at:
	push ax
	push bx
	mov ah, 0x02
	xor bh, bh
	int 0x10
	mov [CURSOR_ROW], dh
	mov [CURSOR_COL], dl
	pop bx
	pop ax
	ret

	;; ===================================================================
	;; Cursor Movement
	;; -------------------------------------------------------------------
	;; Sub-routines to move the cursor
	;; -------------------------------------------------------------------
cursor_left:
	push dx
	mov dx, [CURSOR]
	cmp dl, 0
	jz .exit
	dec dl
	call cursor_at
.exit:
	pop dx
	ret
	
cursor_right:
	push dx
	mov dx, [CURSOR]
	inc dl
	cmp dl, 79		; Right-hand edge of screen?
	jc .exit
	call cursor_down
	call cursor_line_feed
.exit:
	call cursor_at
	pop dx
	ret

cursor_up:
	push dx
	mov dx, [CURSOR]
	dec dh
	cmp dl, 0		; Do nothing if we hit the top of the screen
	jz .exit
	call cursor_at
.exit:
	pop dx
	ret

cursor_down:
	push dx
	mov dx, [CURSOR]
	inc dh
	cmp dh, 25		; Bottom of the screen?
	jl .continue		; No, carry on
	push ax			; Yes, scroll the entire window
	push cx
	push dx
	mov cx, 0x0000		; Top-left
	mov dx, 0x184F		; Bottom-left
	mov ah, 0x06		; Scroll window up
	mov al, 0x01		; by one row
	int 0x10
	pop dx
	pop cx
	pop ax
	mov dh, 24		; Reset to the bottom row of the screen.
.continue:
	call cursor_at
	pop dx
	ret

cursor_line_feed:
	push dx
	mov dx, [CURSOR]
	xor dl, dl
	call cursor_at
	pop dx
	ret

plot:
	push ax
	mov ah, 0x0C		; Write pixel command
	int 0x10		; Call the interrupt
	pop ax
	ret

; Variables

BOOT_DRIVE: db 0, 0
BOOT_DRIVE_LABEL: db "Drive ", 0

HEX_DUMP_LABEL: db "Hex Dump", 0

CRLF: db 0x0D, 0x0A, 0
SPACE: db 0x20, 0
	
DISK_ERROR_MSG db "Disk read error!", 0

CURSOR:	
CURSOR_COL:	db 0
CURSOR_ROW:	db 0

CL_BLACK	equ	0x00
CL_NAVY		equ 	0x01
CL_OLIVE  	equ 	0x02
CL_CYAN  	equ 	0x03
CL_MAROON  	equ 	0x04
CL_MAGENTA	equ 	0x05
CL_BROWN  	equ 	0x06
CL_SILVER  	equ 	0x07
CL_GREY  	equ 	0x08
CL_BLUE  	equ 	0x09
CL_GREEN  	equ 	0x0A
CL_AQUA  	equ 	0x0B
CL_RED  	equ 	0x0C
CL_PURPLE  	equ 	0x0D
CL_YELLOW  	equ 	0x0E
CL_WHITE  	equ 	0x0F

MSG_INVALID_OS_CALL:	db "Invalid OS call: ", 0

version:
	db 'RetrOS, v0.1.3', 0x0D, 0x0A, 'Because 640k should be enough for anybody', 0x0D, 0x0A, 0
	
	times 1024-($-$$) db 0	; Pad to 1024 bytes with zero bytes
