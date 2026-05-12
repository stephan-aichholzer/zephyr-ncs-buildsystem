#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

#include "greet.h"

int main(void)
{
	char buf[64];

	if (greet(CONFIG_BOARD, buf, sizeof(buf)) > 0) {
		printk("%s\n", buf);
	}

	uint32_t tick = 0;
	while (1) {
		printk("tick %u\n", tick++);
		k_msleep(1000);
	}

	return 0;
}
