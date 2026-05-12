#include <zephyr/ztest.h>
#include <string.h>

#include "greet.h"

ZTEST_SUITE(greet_suite, NULL, NULL, NULL, NULL, NULL);

ZTEST(greet_suite, formats_basic_name)
{
	char buf[32];
	int n = greet("Zephyr", buf, sizeof(buf));

	zassert_equal(n, 14, "wrote %d bytes, expected 14", n);
	zassert_str_equal(buf, "Hello, Zephyr!");
}

ZTEST(greet_suite, rejects_null_name)
{
	char buf[32];
	zassert_equal(greet(NULL, buf, sizeof(buf)), -1);
}

ZTEST(greet_suite, rejects_null_buffer)
{
	zassert_equal(greet("x", NULL, 32), -1);
}

ZTEST(greet_suite, rejects_undersized_buffer)
{
	char buf[4];
	int n = greet("World", buf, sizeof(buf));
	zassert_equal(n, -1, "should reject truncation, got %d", n);
}
