/*
 * Accessing HD-audio verbs via hwdep interface
 * Version 0.3
 *
 * Copyright (c) 2008 Takashi Iwai <tiwai@suse.de>
 *
 * Licensed under GPL v2 or later.
 */

//
// Adapted from hda-verb from alsa-tools:
// https://www.alsa-project.org/main/index.php/Main_Page
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <stdint.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

#include "hda_hwdep.h"

#define AC_VERB_GET_STREAM_FORMAT		0x0a00
#define AC_VERB_GET_AMP_GAIN_MUTE		0x0b00
#define AC_VERB_GET_PROC_COEF			0x0c00
#define AC_VERB_GET_COEF_INDEX			0x0d00
#define AC_VERB_PARAMETERS			0x0f00
#define AC_VERB_GET_CONNECT_SEL			0x0f01
#define AC_VERB_GET_CONNECT_LIST		0x0f02
#define AC_VERB_GET_PROC_STATE			0x0f03
#define AC_VERB_GET_SDI_SELECT			0x0f04
#define AC_VERB_GET_POWER_STATE			0x0f05
#define AC_VERB_GET_CONV			0x0f06
#define AC_VERB_GET_PIN_WIDGET_CONTROL		0x0f07
#define AC_VERB_GET_UNSOLICITED_RESPONSE	0x0f08
#define AC_VERB_GET_PIN_SENSE			0x0f09
#define AC_VERB_GET_BEEP_CONTROL		0x0f0a
#define AC_VERB_GET_EAPD_BTLENABLE		0x0f0c
#define AC_VERB_GET_DIGI_CONVERT_1		0x0f0d
#define AC_VERB_GET_DIGI_CONVERT_2		0x0f0e
#define AC_VERB_GET_VOLUME_KNOB_CONTROL		0x0f0f
#define AC_VERB_GET_GPIO_DATA			0x0f15
#define AC_VERB_GET_GPIO_MASK			0x0f16
#define AC_VERB_GET_GPIO_DIRECTION		0x0f17
#define AC_VERB_GET_GPIO_WAKE_MASK		0x0f18
#define AC_VERB_GET_GPIO_UNSOLICITED_RSP_MASK	0x0f19
#define AC_VERB_GET_GPIO_STICKY_MASK		0x0f1a
#define AC_VERB_GET_CONFIG_DEFAULT		0x0f1c
#define AC_VERB_GET_SUBSYSTEM_ID		0x0f20

#define AC_VERB_SET_STREAM_FORMAT		0x200
#define AC_VERB_SET_AMP_GAIN_MUTE		0x300
#define AC_VERB_SET_PROC_COEF			0x400
#define AC_VERB_SET_COEF_INDEX			0x500
#define AC_VERB_SET_CONNECT_SEL			0x701
#define AC_VERB_SET_PROC_STATE			0x703
#define AC_VERB_SET_SDI_SELECT			0x704
#define AC_VERB_SET_POWER_STATE			0x705
#define AC_VERB_SET_CHANNEL_STREAMID		0x706
#define AC_VERB_SET_PIN_WIDGET_CONTROL		0x707
#define AC_VERB_SET_UNSOLICITED_ENABLE		0x708
#define AC_VERB_SET_PIN_SENSE			0x709
#define AC_VERB_SET_BEEP_CONTROL		0x70a
#define AC_VERB_SET_EAPD_BTLENABLE		0x70c
#define AC_VERB_SET_DIGI_CONVERT_1		0x70d
#define AC_VERB_SET_DIGI_CONVERT_2		0x70e
#define AC_VERB_SET_VOLUME_KNOB_CONTROL		0x70f
#define AC_VERB_SET_GPIO_DATA			0x715
#define AC_VERB_SET_GPIO_MASK			0x716
#define AC_VERB_SET_GPIO_DIRECTION		0x717
#define AC_VERB_SET_GPIO_WAKE_MASK		0x718
#define AC_VERB_SET_GPIO_UNSOLICITED_RSP_MASK	0x719
#define AC_VERB_SET_GPIO_STICKY_MASK		0x71a
#define AC_VERB_SET_CONFIG_DEFAULT_BYTES_0	0x71c
#define AC_VERB_SET_CONFIG_DEFAULT_BYTES_1	0x71d
#define AC_VERB_SET_CONFIG_DEFAULT_BYTES_2	0x71e
#define AC_VERB_SET_CONFIG_DEFAULT_BYTES_3	0x71f
#define AC_VERB_SET_CODEC_RESET			0x7ff

#define AC_PAR_VENDOR_ID		0x00
#define AC_PAR_SUBSYSTEM_ID		0x01
#define AC_PAR_REV_ID			0x02
#define AC_PAR_NODE_COUNT		0x04
#define AC_PAR_FUNCTION_TYPE		0x05
#define AC_PAR_AUDIO_FG_CAP		0x08
#define AC_PAR_AUDIO_WIDGET_CAP		0x09
#define AC_PAR_PCM			0x0a
#define AC_PAR_STREAM			0x0b
#define AC_PAR_PIN_CAP			0x0c
#define AC_PAR_AMP_IN_CAP		0x0d
#define AC_PAR_CONNLIST_LEN		0x0e
#define AC_PAR_POWER_STATE		0x0f
#define AC_PAR_PROC_CAP			0x10
#define AC_PAR_GPIO_CAP			0x11
#define AC_PAR_AMP_OUT_CAP		0x12
#define AC_PAR_VOL_KNB_CAP		0x13

/*
 */
#define VERBSTR(x)	{ .val = AC_VERB_##x, .str = #x }
#define PARMSTR(x)	{ .val = AC_PAR_##x, .str = #x }

struct strtbl {
	int val;
	const char *str;
};

static struct strtbl hda_verbs[] = {
	VERBSTR(GET_STREAM_FORMAT),
	VERBSTR(GET_AMP_GAIN_MUTE),
	VERBSTR(GET_PROC_COEF),
	VERBSTR(GET_COEF_INDEX),
	VERBSTR(PARAMETERS),
	VERBSTR(GET_CONNECT_SEL),
	VERBSTR(GET_CONNECT_LIST),
	VERBSTR(GET_PROC_STATE),
	VERBSTR(GET_SDI_SELECT),
	VERBSTR(GET_POWER_STATE),
	VERBSTR(GET_CONV),
	VERBSTR(GET_PIN_WIDGET_CONTROL),
	VERBSTR(GET_UNSOLICITED_RESPONSE),
	VERBSTR(GET_PIN_SENSE),
	VERBSTR(GET_BEEP_CONTROL),
	VERBSTR(GET_EAPD_BTLENABLE),
	VERBSTR(GET_DIGI_CONVERT_1),
	VERBSTR(GET_DIGI_CONVERT_2),
	VERBSTR(GET_VOLUME_KNOB_CONTROL),
	VERBSTR(GET_GPIO_DATA),
	VERBSTR(GET_GPIO_MASK),
	VERBSTR(GET_GPIO_DIRECTION),
	VERBSTR(GET_GPIO_WAKE_MASK),
	VERBSTR(GET_GPIO_UNSOLICITED_RSP_MASK),
	VERBSTR(GET_GPIO_STICKY_MASK),
	VERBSTR(GET_CONFIG_DEFAULT),
	VERBSTR(GET_SUBSYSTEM_ID),

	VERBSTR(SET_STREAM_FORMAT),
	VERBSTR(SET_AMP_GAIN_MUTE),
	VERBSTR(SET_PROC_COEF),
	VERBSTR(SET_COEF_INDEX),
	VERBSTR(SET_CONNECT_SEL),
	VERBSTR(SET_PROC_STATE),
	VERBSTR(SET_SDI_SELECT),
	VERBSTR(SET_POWER_STATE),
	VERBSTR(SET_CHANNEL_STREAMID),
	VERBSTR(SET_PIN_WIDGET_CONTROL),
	VERBSTR(SET_UNSOLICITED_ENABLE),
	VERBSTR(SET_PIN_SENSE),
	VERBSTR(SET_BEEP_CONTROL),
	VERBSTR(SET_EAPD_BTLENABLE),
	VERBSTR(SET_DIGI_CONVERT_1),
	VERBSTR(SET_DIGI_CONVERT_2),
	VERBSTR(SET_VOLUME_KNOB_CONTROL),
	VERBSTR(SET_GPIO_DATA),
	VERBSTR(SET_GPIO_MASK),
	VERBSTR(SET_GPIO_DIRECTION),
	VERBSTR(SET_GPIO_WAKE_MASK),
	VERBSTR(SET_GPIO_UNSOLICITED_RSP_MASK),
	VERBSTR(SET_GPIO_STICKY_MASK),
	VERBSTR(SET_CONFIG_DEFAULT_BYTES_0),
	VERBSTR(SET_CONFIG_DEFAULT_BYTES_1),
	VERBSTR(SET_CONFIG_DEFAULT_BYTES_2),
	VERBSTR(SET_CONFIG_DEFAULT_BYTES_3),
	VERBSTR(SET_CODEC_RESET),
	{ }, /* end */
};

static struct strtbl hda_params[] = {
	PARMSTR(VENDOR_ID),
	PARMSTR(SUBSYSTEM_ID),
	PARMSTR(REV_ID),
	PARMSTR(NODE_COUNT),
	PARMSTR(FUNCTION_TYPE),
	PARMSTR(AUDIO_FG_CAP),
	PARMSTR(AUDIO_WIDGET_CAP),
	PARMSTR(PCM),
	PARMSTR(STREAM),
	PARMSTR(PIN_CAP),
	PARMSTR(AMP_IN_CAP),
	PARMSTR(CONNLIST_LEN),
	PARMSTR(POWER_STATE),
	PARMSTR(PROC_CAP),
	PARMSTR(GPIO_CAP),
	PARMSTR(AMP_OUT_CAP),
	PARMSTR(VOL_KNB_CAP),
	{ }, /* end */
};

//
// Global Variables
//

io_service_t VerbStubIOService;
io_connect_t DataConnection;
uint32_t connectiontype = 0;

//
// Open connection to IOService
//

uint32_t OpenServiceConnection()
{
    //
    // Having a kernel-side server (VerbStub) and a user-side client (hda-verb) is really the only way to ensure that hda-
    // verb won't break when IOAudioFamily changes. This 2-component solution is necessary because we can't compile kernel
    // libraries into user-space programs on macOS and expect them to work generically.
    //
    // Additionally, if this program were made as a single executable that accessed device memory regions directly, it would
    // only be guaranteed to work for one machine on one BIOS version since memory regions change depending on hardware
    // configurations. This is why Raspberry Pis, STM32s, and other embedded platforms are nice to program on: They don't
    // change much between versions so programs can be made extremely lightweight. Linux also does a pretty good job
    // achieving a similar situation, since everything (devices, buses, etc.) on Linux is represented by an easily
    // accessible file (just look at how simple the hda-verb program in alsa-tools is! All it uses is ioctl).
    //
    
    CFMutableDictionaryRef dict = IOServiceMatching("com_XPS_VerbStub");
    
    // Use IOServiceGetMatchingService since we can reasonably expect "VerbStub" is the only IORegistryEntry of its kind.
    // Otherwise IOServiceGetMatchingServices with an iterating algorithm must be used to find the kernel extension.
    
    VerbStubIOService = IOServiceGetMatchingService(kIOMasterPortDefault, dict);
    
    // Hopefully the kernel extension loaded properly so it can be found.
    
    if (!VerbStubIOService)
    {
        fprintf(stderr, "Could not locate VerbStub kext. Ensure it is loaded; verbs cannot be sent otherwise.\n");
        return -1;
    }
    
    // Connect to the IOService object
    // Note: kern_return_t is just an int
    kern_return_t kernel_return_status = IOServiceOpen(VerbStubIOService, mach_task_self(), connectiontype, &DataConnection);
    
    if (kernel_return_status != kIOReturnSuccess)
    {
        fprintf(stderr, "Failed to open VerbStub IOService: %08x.\n", kernel_return_status);
        return -1;
    }
    
    return kernel_return_status; // 0 if successful
}

//
// Send verb command
//

static uint32_t VerbCommand(uint32_t command)
{
    //
    // Call the function ultimately responsible for sending commands in the kernel extension. That function will return the
    // response we also want.
    // https://lists.apple.com/archives/darwin-drivers/2008/Mar/msg00007.html
    //
    
    uint32_t inputCount = 1; // Number of input arguments
    uint32_t outputCount = 1; // Number of elements in output
    uint64_t input = command; // Array of input scalars
    uint64_t output; // Array of output scalars
    
    // IOConnectCallScalarMethod was introduced in Mac OS X 10.5
    
    kern_return_t kernel_return_status = IOConnectCallScalarMethod(DataConnection, connectiontype, &input, inputCount, &output, &outputCount);
    
    if (kernel_return_status != kIOReturnSuccess)
    {
        fprintf(stderr, "Error sending command.\n");
        return -1;
    }
    
    // Return command response
    return (uint32_t)output;
}

//
// Close connection to IOService
//

void CloseServiceConnection()
{
    // Done with the VerbStub IOService object, so we don't need to hold on to it anymore
    IOObjectRelease(VerbStubIOService);
}

static void list_keys(struct strtbl *tbl, int one_per_line)
{
	int c = 0;
	for (; tbl->str; tbl++) {
		size_t len = strlen(tbl->str) + 2;
		if (!one_per_line && c + len >= 80) {
			fprintf(stderr, "\n");
			c = 0;
		}
		if (one_per_line)
			fprintf(stderr, "  %s\n", tbl->str);
		else if (!c)
			fprintf(stderr, "  %s", tbl->str);
		else
			fprintf(stderr, ", %s", tbl->str);
		c += 2 + len;
	}
	if (!one_per_line)
		fprintf(stderr, "\n");
}

/* look up a value from the given string table */
static int lookup_str(struct strtbl *tbl, const char *str)
{
	struct strtbl *p, *found;
	size_t len = strlen(str);

	found = NULL;
	for (p = tbl; p->str; p++) {
		if (!strncmp(str, p->str, len)) {
			if (found) {
				fprintf(stderr, "No unique key '%s'\n", str);
				return -1;
			}
			found = p;
		}
	}
	if (!found) {
		fprintf(stderr, "No key matching with '%s'\n", str);
		return -1;
	}
	return found->val;
}

/* convert a string to upper letters */
static void strtoupper(char *str)
{
	for (; *str; str++)
		*str = toupper(*str);
}

static void usage(void)
{
	fprintf(stderr, "usage: hda-verb [option] nid verb param\n");
	fprintf(stderr, "   -l      List known verbs and parameters\n");
	fprintf(stderr, "   -L      List known verbs and parameters (one per line)\n");
}

static void list_verbs(int one_per_line)
{
	fprintf(stderr, "known verbs:\n");
	list_keys(hda_verbs, one_per_line);
	fprintf(stderr, "known parameters:\n");
	list_keys(hda_params, one_per_line);
}

//
// Main
//

int main(int argc, char **argv)
{
    // Local variables
    kern_return_t ServiceConnectionStatus;
    int version, c, timeout;
	int nid, verb, param;
	struct hda_verb_ioctl val;
	char **p;
    int trylimit = 5;

    // Check for -l or -L flag
	while ((c = getopt(argc, argv, "lL")) >= 0) {
		switch (c) {
		case 'l':
			list_verbs(0);
			return 0;
		case 'L':
			list_verbs(1);
			return 0;
		default:
			usage();
			return 1;
		}
	}
    
    // Check for correct number of command-line arguments
	if (argc - optind < 3) {
		usage();
		return 1;
	}

    // Mac version of hda-verb
	version = 0x2710; // Darwin

    // If this error appears, the program was compiled incorrectly
	if (version < HDA_HWDEP_VERSION) {
		fprintf(stderr, "Invalid version number 0x%x\n", version);
		return 1;
	}

	p = argv + optind;
	nid = strtol(*p, NULL, 0); // Don't worry about the warning here. This should never be bigger than an int.
	if (nid < 0 || nid > 0xff) {
		fprintf(stderr, "invalid nid %s\n", *p);
		return 1;
	}

	p++;
	if (!isdigit(**p)) {
		strtoupper(*p);
		verb = lookup_str(hda_verbs, *p);
		if (verb < 0)
			return 1;
	} else {
		verb = strtol(*p, NULL, 0); // Don't worry about the warning here. This should never be bigger than an int.
		if (verb < 0 || verb > 0xfff) {
			fprintf(stderr, "invalid verb %s\n", *p);
			return 1;
		}
	}
	p++;
	if (!isdigit(**p)) {
		strtoupper(*p);
		param = lookup_str(hda_params, *p);
		if (param < 0)
			return 1;
	} else {
		param = strtol(*p, NULL, 0); // Don't worry about the warning here. This should never be bigger than an int.
		if (param < 0 || param > 0xffff) {
			fprintf(stderr, "invalid param %s\n", *p);
			return 1;
		}
	}
    // Establish user-kernel connection
    timeout = 0;
    ServiceConnectionStatus = OpenServiceConnection();
    if (ServiceConnectionStatus != kIOReturnSuccess)
    {
        while (ServiceConnectionStatus != kIOReturnSuccess && timeout < trylimit)
        {
            timeout++;
            fprintf(stderr, "Error establshing IOService connection. Retrying in 1 second... (Attempt #%d/%d)\n", timeout, trylimit);
            sleep (1);
            ServiceConnectionStatus = OpenServiceConnection();
        }
    }
    
    if (timeout == trylimit)
    {
        return kIOReturnError;
    }
    
    // Parameter display indicates successful connection
	fprintf(stderr, "nid = 0x%x, verb = 0x%x, param = 0x%x\n",
		nid, verb, param);
    
    // Properly format command
	val.verb = HDA_VERB(nid, verb, param);
	fprintf(stderr, "Verb Command = 0x%x\n", val.verb);

    // Send command
	val.res = VerbCommand(val.verb);
	fprintf(stderr, "Response = 0x%x\n", val.res);

    // Clean up and exit
    CloseServiceConnection();
	return 0;
}
