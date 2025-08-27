# Makefile
CXX = g++
CXXFLAGS = -m64 -ffreestanding -nostdlib -fno-exceptions -fno-rtti -Wall -Wextra
ASM = nasm
ASMFLAGS = -f elf64
LD = ld
LDFLAGS = -n -m elf_x86_64 -T linker.ld -nostdlib

OBJS = boot.o kernel.o

all: os.iso

os.iso: kernel.bin grub.cfg
	mkdir -p isodir/boot/grub
	cp kernel.bin isodir/boot/
	cp grub.cfg isodir/boot/grub/
	grub-mkrescue /usr/lib/grub/i386-pc -o os.iso isodir

kernel.bin: $(OBJS)
	$(LD) $(LDFLAGS) -o kernel.bin $(OBJS)

boot.o: boot.asm
	$(ASM) $(ASMFLAGS) -o boot.o boot.asm

kernel.o: kernel.cpp multiboot.h
	$(CXX) $(CXXFLAGS) -c kernel.cpp -o kernel.o

run: os.iso
	qemu-system-x86_64 -cdrom os.iso

clean:
	rm -f *.o *.bin *.iso
	rm -rf isodir

.PHONY: all run clean
