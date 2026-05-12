#include "greet.h"

#include <stdio.h>

int greet(const char *name, char *out, size_t out_size)
{
	if (name == NULL || out == NULL || out_size == 0) {
		return -1;
	}

	int n = snprintf(out, out_size, "Hello, %s!", name);
	if (n < 0 || (size_t)n >= out_size) {
		return -1;
	}
	return n;
}
