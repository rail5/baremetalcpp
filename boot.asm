%define MULTIBOOT2_MAGIC 0xe85250d6
%define MULTIBOOT2_ARCHITECTURE 0
%define MULTIBOOT2_HEADER_LENGTH header_end - header_start
%define MULTIBOOT2_CHECKSUM 0x100000000 -(MULTIBOOT2_MAGIC + MULTIBOOT2_ARCHITECTURE + MULTIBOOT2_HEADER_LENGTH)

section .multiboot_header
; The multiboot2 header is described at https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html#The-layout-of-Multiboot2-header
; 3.1.1: The Layout of Multiboot2 Header
header_start:
	dd MULTIBOOT2_MAGIC ; Magic number for multiboot2
	dd MULTIBOOT2_ARCHITECTURE ; Architecture (0 for i386)
	dd MULTIBOOT2_HEADER_LENGTH ; Length of header
	dd MULTIBOOT2_CHECKSUM ; Checksum: -(magic + arch + length)

	; Tags:
	dw 0
	dw 0
	dd 8
header_end:

section .text
bits 32
start:
	mov esp, stack_top ; Set up the stack pointer to the top of the stack

	; Sanity checks:
	; 1. Were we booted by a Multiboot2-compliant bootloader?
	; 2. Does the CPU support the CPUID instruction?
	; 3. Does the CPU support long mode (64-bit mode)?
	; If any of these checks fail, we can't continue to boot
	call verify_booted_by_multiboot_bootloader ; Verify that we were booted by a Multiboot2-compliant bootloader
	call verify_cpuid_instruction_available ; Check if the CPU supports the CPUID instruction
	call verify_64bit_longmode_supported ; Check if the CPU supports long mode (64-bit mode)

	; Basic setup
	call setup_page_tables ; Set up the page tables for 64-bit paging
	call enable_paging ; Enable paging, PAE, and long mode

	; Enter long mode and start up 64-bit code
	lgdt [gdt64.pointer] ; Load the Global Descriptor Table for 64-bit mode
	jmp gdt64.code_segment:long_mode_start ; Far jump to 64-bit code segment and entry point

	hlt ; Halt the CPU (should not reach here)

verify_booted_by_multiboot_bootloader:
	cmp eax, 0x36d76289 ; Check if EAX contains the Multiboot2 magic number
	jne .error_not_multiboot ; If not, quit!
	ret
.error_not_multiboot:
	lea esi, [error_msg_not_multiboot]
	jmp display_error_and_halt

verify_cpuid_instruction_available:
	; We need to check if the CPU supports the CPUID instruction
	; Because we need to use the CPUID instruction to check for long mode support (64-bit mode)
	pushfd
	pop eax ; EAX now holds the original EFLAGS
	mov ecx, eax
	xor eax, 1 << 21 ; Flip the ID bit in EFLAGS
	push eax
	popfd ; Write the modified EFLAGS back
	pushfd
	pop eax
	push ecx
	popfd
	cmp eax, ecx ; Compare the original and modified EFLAGS
	je .error_no_cpuid ; If they are the same, CPUID is not supported. If the ID bit successfully flipped, CPUID is supported.
	ret
.error_no_cpuid:
	lea esi, [error_msg_no_cpuid]
	jmp display_error_and_halt

verify_64bit_longmode_supported:
	mov eax, 0x80000000
	cpuid ; Ask the CPU: What is the highest extended function supported?
	cmp eax, 0x80000001
	jb .error_longmode_not_supported
	; We have to ask for extended function 0x80000001 to even **see** if long mode is supported
	; If the highest extended function is less than 0x80000001, the CPU won't even tell us if it supports long mode

	mov eax, 0x80000001
	cpuid ; Request info
	; EDX bit 29 is Long Mode
	test edx, 1 << 29
	jz .error_longmode_not_supported ; If bit 29 is not set, long mode is not supported
	ret
.error_longmode_not_supported:
	lea esi, [error_msg_longmode_not_supported]
	jmp display_error_and_halt

setup_page_tables:
	; Set up the L4 page table entry
	mov eax, page_table_l3 ; Load the address of the L3 page table into EAX
	or eax, 0b11 ; Set the "present" and "writable" flags (bits 0 and 1)
	mov [page_table_l4], eax ; Store the L3 page table address as the first entry in the L4 page table
	
	; Set up the L3 page table entry
	mov eax, page_table_l2 ; Load the address of the L2 page table into EAX
	or eax, 0b11 ; Again: set the "present" and "writable" flags
	mov [page_table_l3], eax ; Store the L2 page table address as the first entry in the L3 page table

	mov ecx, 0 ; Set up a counter register for the following loop
.loop:
	mov eax, 0x200000 ; Start mapping at 2 MiB
	mul ecx ; Multiply by the counter to get the address to map
	; Ie, the 2nd entry maps 4 MiB, the 3rd entry maps 6 MiB, etc
	; This maps the first 1 GiB of memory (512 loop iterations * 2 MiB = 1 GiB)
	or eax, 0b10000011 ; Set the flags: "present", "writable", and "page size" (2 MiB page)
	mov [page_table_l2 + ecx * 8], eax ; Write the entry into the L2 page table

	inc ecx ; Move to the next entry
	cmp ecx, 512 ; Only run 512 times (to map 1 GiB of memory)
	jne .loop

	ret

enable_paging:
	; Set the page table base address
	mov eax, page_table_l4
	mov cr3, eax ; Load the address of the L4 page table into CR3

	; Enable PAE in CR4
	mov eax, cr4
	or eax, 1 << 5 ; Set bit 5 (PAE enable)
	mov cr4, eax

	; Enable long mode in EFER MSR
	mov ecx, 0xC0000080
	rdmsr
	or eax, 1 << 8 ; Bit 8: Long Mode Enable (LME)
	wrmsr

	; Enable paging in CR0
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax

	ret

display_error_and_halt:
	; The ESI register should point to a null-terminated string to display
	%define VGA_ATTRIBUTE 0x4f ; Light red on black
	mov edi, 0xb8000 ; Start writing the error message after "ERROR: "
	mov ax, 0 ; Clear AX to prepare for STOSW
	mov es, ax ; Set ES to 0 to point to the start of video memory segment
.print_loop:
		lodsb ; Load the next byte from the string at ESI into AL, and increment ESI
		cmp al, 0 ; Check for null terminator
		je .done ; If we hit the null terminator, we're done
		mov ah, VGA_ATTRIBUTE
		stosw ; Write the character and attribute to video memory at ES:DI, and increment DI by 2
		jmp .print_loop
.done:
	; Halt the CPU
	cli
	hlt

section .bss
align 4096
page_table_l4:
	resb 4096
page_table_l3:
	resb 4096
page_table_l2:
	resb 4096
stack_bottom:
	resb 4096 * 4
stack_top:

section .rodata
gdt64:
	dq 0 ; Null segment
.code_segment: equ $ - gdt64
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; Code segment: base=0, limit=0, type=code, S=1 (code/data), DPL=0, P=1, L=1 (64-bit), D/B=0, G=1 (4KiB granularity)
.pointer:
	dw $ - gdt64 - 1 ; Length
	dq gdt64 ; Address
error_msg_not_multiboot db "ERROR: Not booted by a Multiboot2-compliant bootloader", 0
error_msg_no_cpuid db "ERROR: CPU does not support the CPUID instruction", 0
error_msg_longmode_not_supported db "ERROR: CPU does not support 64-bit long mode", 0
bits 64
extern kernel_main
long_mode_start:
    ; Set up segment registers by nulling them out
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    call kernel_main ; kernel_main is defined in kernel.cpp
    hlt
