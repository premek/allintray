#include <stdio.h>
#include <string.h>


/* returns current CPU load in percent, 0 to 100 */
int system_cpu(void) {
	unsigned int cpuload;
	int load, total, oload, ototal;
	int ab, ac, ad, ae;
	int i;
	FILE *stat;

	stat = fopen("/proc/stat", "r");
	fscanf(stat, "%*s %Ld %Ld %Ld %Ld", &ab, &ac, &ad, &ae);
	fclose(stat);

	/* Find out the CPU load */
	/* user + sys = load
	 * total = total */
	load = ab + ac + ad;	/* cpu.user + cpu.sys; */
	total = ab + ac + ad + ae;	/* cpu.total; */

	/* "i" is an index into a load history */
	i = 0;//bm.loadIndex;
	oload = bm.load[i];
	ototal = bm.total[i];

	bm.load[i] = load;
	bm.total[i] = total;
	bm.loadIndex = (i + 1) % 16;

	/*
	   Because the load returned from libgtop is a value accumulated
	   over time, and not the current load, the current load percentage
	   is calculated as the extra amount of work that has been performed
	   since the last sample. yah, right, what the fuck does that mean?
	   */
	if (ototal == 0)		/* ototal == 0 means that this is the first time
							   we get here */
		cpuload = 0;
	else if ((total - ototal) <= 0)
		cpuload = 100;
	else
		cpuload = (100 * (load - oload)) / (total - ototal);

	return cpuload;
}


int main(void) {
	printf(system_cpu());
	return 0;
}
