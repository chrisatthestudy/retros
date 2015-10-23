;; ============================================================================
;; RetrOS
;; ============================================================================
;; v0.1.4
;; ----------------------------------------------------------------------------
;; A simple boot sector

	[org 0x7c00]		; Intel x86 boot sectors start at address 7c00
	
	mov bp, 0x8000		; Here we set our stack safely out of the
	mov sp, bp		; way, at 0x8000

	mov [BOOT_DRIVE], dl	; Preserve the boot-drive number
	
clear_screen:
	mov ah, 0x00		; Set video mode
	mov al, 0x03		; 720x400 VGA (?)
	int 0x10
	
load_kernel:	
	push 0x9000
	pop es
	xor bx, bx
	mov dh, 2		; Read 2 sectors
	mov dl, 1		; from floppy disk B
	mov cl, 0x01 		; Start reading from first sector
	call disk_read
	mov dl, [BOOT_DRIVE]	; Pass the boot-drive number to the kernel,
				; via the dl register
	
exit:
	jmp 0x9000:0x0000	; Jump to the start of the kernel

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
	jz .print_string_done	; If yes, we're done
	mov ah, 0x0e		; Interrupt 10, command 0e: print single character
	int 0x10		; Interrupt 10 (Video Interrupts) to print the character
	jmp .next_char		; Loop back for the next character
.print_string_done:
	pop si
	pop ax
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
jc disk_error			; Jump if error (i.e. carry flag set)
	pop dx			; Restore DX from the stack
	cmp dh, al		; if AL (sectors read) != DH (sectors expected)
jne disk_error			; display error message
	ret
	
disk_error :
	mov si, DISK_ERROR_MSG      
	call print_string
	jmp $
	
; Variables
BOOT_DRIVE db 0
	
DISK_ERROR_MSG db "Disk read error!", 0

padding:	
	times 510-($-$$) db 0	; Pad to 510 bytes with zero bytes

	dw 0xaa55		; Last two bytes (one word) form the magic number ,
				; so BIOS knows we are a boot sector.
