#ifndef GREET_H
#define GREET_H

#include <stddef.h>

/* Format "Hello, <name>!" into out. Returns the number of bytes written
 * (excluding the trailing NUL), or -1 on bad input / truncation. */
int greet(const char *name, char *out, size_t out_size);

#endif /* GREET_H */
