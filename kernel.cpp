#include <cstdint>
#include "multiboot.h"

#include "kernel_include/vga.h"
#include "kernel_include/itoa.h"


extern "C" void kernel_main(uint32_t magic, multiboot_info_t* mbi) {
	if (magic != 0x36d76289) {  // Multiboot2 magic
		// Display error message
		VGATextBuffer vga;
		vga.write("Invalid multiboot magic", 0, 0, 0x4F); // Red background
		char num_str[32];
		itoa<uint32_t>(magic, num_str, 16);
		vga.write(" Magic: 0x", 0, 1, 0x4F);
		vga.write(num_str, 9, 1, 0x4F);
		// Halt the system
		return;
	}

	if (mbi == nullptr) {
		// Display error message
		VGATextBuffer vga;
		vga.write("No multiboot info provided", 0, 0, 0x4F); // Red background
		// Halt the system
		return;
	}
	
	// Initialize VGA text buffer
	VGATextBuffer vga;
	
	// Display hello world message
	vga.write("Hello World!", 0, 0);

	int line = 1;

	if (magic == 0) {
		vga.write("No magic number provided", 0, line++, 0x4F);
	}

	if (mbi == nullptr) {
		vga.write("No multiboot info provided", 0, line++, 0x4F);
	}

	vga.write("Here's a big 64-bit number to prove we're in 64-bit mode:", 0, line++);
	char num_str[32]; // Enough for 64-bit number in decimal
	itoa<uint64_t>(UINT64_MAX, num_str, 10);
	vga.write(num_str, 0, line++);

	while (true) {}
}
