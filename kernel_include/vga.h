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
