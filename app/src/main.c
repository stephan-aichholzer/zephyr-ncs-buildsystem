#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
	printk("Hello from %s\n", CONFIG_BOARD);

	uint32_t tick = 0;
	while (1) {
		printk("tick %u\n", tick++);
		k_msleep(1000);
	}

	return 0;
}
