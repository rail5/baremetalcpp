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
