#include <cstdint>
#include "multiboot.h"

// Define a VGA text buffer class for output
class VGATextBuffer {
	private:
		volatile char* buffer;
		
	public:
		VGATextBuffer() : buffer(reinterpret_cast<volatile char*>(0xB8000)) {}
		
		void write(const char* str, int x = 0, int y = 0, uint8_t color = 0x0F) {
			int offset = (y * 80 + x) * 2;
			for (int i = 0; str[i] != '\0'; ++i) {
				buffer[offset] = str[i];
				buffer[offset + 1] = color;
				offset += 2;
			}
		}
};

template <typename T>
void itoa(T value, char* str, int base) {
	if (base < 2 || base > 36) {
		str[0] = '\0';
		return;
	}
	
	char* ptr = str, *ptr1 = str, tmp_char;
	T tmp_value;
	
	do {
		tmp_value = value;
		value /= base;
		*ptr++ = "0123456789abcdefghijklmnopqrstuvwxyz"[tmp_value - value * base];
	} while (value);
	
	// Apply negative sign for base 10
	if (tmp_value < 0 && base == 10) {
		*ptr++ = '-';
	}
	
	*ptr-- = '\0';
	
	while (ptr1 < ptr) {
		tmp_char = *ptr;
		*ptr-- = *ptr1;
		*ptr1++ = tmp_char;
	}
}

extern "C" void kernel_main(uint32_t magic, multiboot_info_t* mbi) {
	/*if (magic != 0x36d76289) {  // Multiboot2 magic
		// Display error message
		VGATextBuffer vga;
		vga.write("Invalid multiboot magic", 0, 0, 0x4F); // Red background
		shutdown();
		return;
	}*/ // This check fails. We did not tell GRUB to pass us the multiboot info structure
	
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
	
	/*
	if (mbi->flags & MULTIBOOT_INFO_BOOT_LOADER_NAME) {
		const char* bootloader_name = reinterpret_cast<const char*>(static_cast<uint64_t>(mbi->boot_loader_name));
		vga.write("Bootloader: ", 0, 1);
		vga.write(bootloader_name, 12, 1);
	}*/ // Will be available when we tell GRUB to pass it
}
