/*
 *  Released under "The GNU General Public License (GPL-2.0)"
 *
 *  This program is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; either version 2 of the License, or (at your
 *  option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 *  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 *  for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 *
 */

//
// Adapted from CodecCommander:
// https://github.com/Dolnor/EAPD-Codec-Commander
//

#ifndef CodecCommander_IntelHDA_h
#define CodecCommander_IntelHDA_h

#include <IOKit/pci/IOPCIDevice.h>

#ifdef DEBUG
#	define DebugLog(args...) do { IOLog("VerbStub: " args); } while (0)
#else
#	define DebugLog(args...)
#endif

#define AlwaysLog(args...) do { IOLog("VerbStub: " args); } while (0)

#define kCodecProfile               "Codec Profile"
#define kCodecVendorID              "IOHDACodecVendorID"
#define kCodecAddress               "IOHDACodecAddress"
#define kCodecRevisionID            "IOHDACodecRevisionID"
#define kCodecFuncGroupType         "IOHDACodecFunctionGroupType"
#define kCodecSubsystemID           "IOHDACodecFunctionSubsystemID"

// Intel HDA Verbs
#define HDA_VERB_GET_PARAM		(UInt16)0xF00	// Get Parameter
#define HDA_VERB_SET_PSTATE		(UInt16)0x705	// Set Power State
#define HDA_VERB_GET_PSTATE		(UInt16)0xF05	// Get Power State
#define HDA_VERB_EAPDBTL_GET	(UInt16)0xF0C	// EAPD/BTL Enable Get
#define HDA_VERB_EAPDBTL_SET	(UInt16)0x70C	// EAPD/BTL Enable Set
#define HDA_VERB_RESET			(UInt16)0x7FF	// Function Reset Execute
#define HDA_VERB_GET_SUBSYSTEM_ID	(UInt16)0xF20	// Get codec subsystem ID

#define HDA_VERB_SET_AMP_GAIN	(UInt8)0x3		// Set Amp Gain / Mute
#define HDA_VERB_GET_AMP_GAIN	(Uint8)0xB		// Get Amp Gain / Mute

#define HDA_PARM_NULL		(UInt8)0x00	// Empty or NULL payload

#define HDA_PARM_VENDOR		(UInt8)0x00 // Vendor ID
#define HDA_PARM_REVISION	(UInt8)0x02	// Revision ID
#define HDA_PARM_NODECOUNT	(UInt8)0x04	// Subordinate Node Count
#define HDA_PARM_FUNCGRP	(UInt8)0x05	// Function Group Type
#define HDA_PARM_PINCAP		(UInt8)0x0C	// Pin Capabilities
#define HDA_PARM_PWRSTS		(UInt8)0x0F	// Supported Power States

#define HDA_PARM_PS_D0		(UInt8)0x00 // Powerstate D0: Fully on
#define HDA_PARM_PS_D1		(UInt8)0x01 // Powerstate D1
#define HDA_PARM_PS_D2		(UInt8)0x02 // Powerstate D2
#define HDA_PARM_PS_D3_HOT	(UInt8)0x03 // Powerstate D3Hot
#define HDA_PARM_PS_D3_COLD (UInt8)0x04	// Powerstate D3Cold

#define HDA_TYPE_AFG	1	// return from PARM_FUNCGRP is 1 for Audio

// Dynamic payload parameters
#define HDA_PARM_AMP_GAIN_GET(Index, Left, Output) \
	(UInt16)((Output & 0x1) << 15 | (Left & 0x01) << 13 | Index & 0xF) // Get Amp gain / mute

#define HDA_PARM_AMP_GAIN_SET(Gain, Mute, Index, SetRight, SetLeft, SetInput, SetOutput) \
	(UInt16)((SetOutput & 0x01) << 15 | (SetInput & 0x01) << 14 | (SetLeft & 0x01) << 13 | (SetRight & 0x01) << 12 | \
    (Index & 0xF) << 8 | (Mute & 0x1) << 7 | Gain & 0x7F) // Set Amp gain / mute

// Determine Immediate Command Busy (ICB) of Immediate Command Status (ICS)
#define HDA_ICS_IS_BUSY(status) ((status) & (1<<0))

// Determine Immediate Result Valid (IRV) of Immediate Command Status (ICS)
#define HDA_ICS_IS_VALID(status) ((status) & (1<<1))

// Determine if this Pin widget capabilities is marked EAPD capable
#define HDA_PINCAP_IS_EAPD_CAPABLE(capabilities) ((capabilities) & (1<<16))

typedef struct __attribute__((packed))
{
	// 00h: GCAP – Global Capabilities
	volatile UInt16 GCAP_OSS		: 4;		// Number of Output Streams Supported
	volatile UInt16 GCAP_ISS		: 4;		// Number of Input Streams Supported
	volatile UInt16 GCAP_BSS		: 5;		// Number of Bidirectional Streams Supported
	volatile UInt16 GCAP_NSDO		: 2;		// Number of Serial Data Out Signals
	volatile UInt16 GCAP_64OK		: 1;		// 64 Bit Address Supported
	// 02h: VMIN – Minor Version
	volatile UInt8  VMIN;						// Minor Version
	// 03h: VMAJ – Major Version
	volatile UInt8  VMAJ;						// Major Version
	// 04h: OUTPAY – Output	Payload Capability
	volatile UInt16 OUTPAY;						// Output Payload Capability
	// 06h: INPAY – Input Payload Capability
	volatile UInt16 INPAY;						// Input Payload Capability
	// 08h: GCTL – Global Control
	UInt32							: 23;		// Reserved
	volatile UInt32 GCTL_UNSOL		: 1;		// Accept Unsolicited Response Enable
	UInt32							: 6;		// Reserved
	volatile UInt32 GCTL_FCNTRL		: 1;		// Flush Control
	volatile UInt32 GCTL_CRST		: 1;		// Controller Reset
	// 0Ch: WAKEEN – Wake Enable
	UInt16							: 1;		// Reserved
	volatile UInt16 WAKEEN_SDIWEN	: 15;		// SDIN Wake Enable Flags
	// 0Eh: STATESTS – State Change Status
	UInt16							: 1;		// Reserved
	volatile UInt16 STATESTS_SDIWAKE: 15;		// SDIN State Change Status Flags
	// 10h: GSTS – Global Status
	UInt16							: 14;		// Reserved
	volatile UInt16 GSTS_FSTS		: 1;		// Flush Status
	UInt16							: 1;		// Reserved

	UInt32							: 32;		// Spacer
	UInt16							: 16;		// Spacer

	// 18h: OUTSTRMPAY – Output Stream Payload Capability
	volatile UInt16 OUTSTRMPAY;					// Output Stream Payload Capability
	// 1Ah: INSTRMPAY – Input Stream Payload Capability
	volatile UInt16 INSTRMPAY;					// Input Stream Payload Capability

	UInt32							: 32;		// Spacer

	// 20h: INTCTL – Interrupt Control
	volatile UInt32 INTCTL_GIE		: 1;		// Global Interrupt Enable
	volatile UInt32 INTCTL_CIE		: 1;		// Controller Interrupt Enable
	volatile UInt32 INTCTL_SIE		: 30;		// Stream Interrupt Enable
	// 24h: INTSTS – Interrupt Status
	volatile UInt32 INTSTS_GIS		: 1;		// Global Interrupt Status
	volatile UInt32 INTSTS_CIS		: 1;		// Controller Interrupt Status
	volatile UInt32 INTSTS_SIS		: 30;		// Stream Interrupt Status

	UInt32							: 32;		// Spacer
	UInt32							: 32;		// Spacer

	// 30h: Wall Clock Counter
	volatile UInt32 WALL_CLOCK_COUNTER;			// Wall Clock Counter
	UInt32							: 32;		// Spacer
	// 38h: SSYNC – Stream Synchronization
	UInt32							: 2;		// Reserved
	volatile UInt32 SSYNC			: 30;		// Stream Synchronization Bits

	UInt32							: 32;		// Spacer

	// 40h: CORB Lower Base Address
	volatile UInt32 CORBLBASE;		// CORB Lower Base Address
	// 44h: CORB Upper Base Address
	volatile UInt32 CORBUBASE;		// CORB Upper Base Address
	// 48h: CORBWP – CORB Write Pointer
	UInt16							: 8;		// Reserved
	volatile UInt16 CORBWP			: 8;		// CORB Write Pointer
	// 4Ah: CORBRP – CORB Read Pointer
	volatile UInt16 CORBRPRST		: 1;		// CORB Read Pointer Reset
	UInt16							: 7;		// Reserved
	volatile UInt16 CORBRP			: 8;		// CORB Read Pointer
	// 4Ch: CORBCTL – CORB Control
	UInt8							: 6;		// Reserved
	volatile UInt8 CORBRUN			: 1;		// Enable CORB DMA Engine
	volatile UInt8 CMEIE			: 1;		// CORB Memory Error Interrupt Enable
	// 4Dh: CORBSTS – CORB Status
	UInt8							: 7;		// Reserved
	volatile UInt8 CMEI				: 1;		// CORB Memory Error Indication
	// 4Eh: CORBSIZE – CORB Size
	volatile UInt8 CORBSZCAP		: 4;		// CORB Size Capability
	UInt8							: 2;		// Reserved
	volatile UInt8 CORBSIZE			: 2;		// CORB Size

	UInt8							: 8;		// Spacer

	// 50h: RIRBLBASE – RIRB Lower Base Address
	volatile UInt32 RIRBLBASE;					// RIRB Lower Base Address
	// 54h: RIRBUBASE – RIRB Upper Base Address
	volatile UInt32 RIRBUBASE;					// RIRB Upper Base Address
	// 58h: RIRBWP – RIRB Write Pointer
	volatile UInt16 RIRBWPRST		: 1;		// RIRB Write Pointer Reset
	UInt16							: 7;		// Reserved
	volatile UInt16 RIRBWP			: 8;		// RIRB Write Pointer
	// 5Ah: RINTCNT – Response Interrupt Count
	UInt16							: 8;
	volatile UInt16 RINTCNT			: 8;		// N Response Interrupt Count
	// 5Ch: RIRBCTL – RIRB Control
	UInt8							: 5;		// Reserved
	volatile UInt8 RINTCNT_RIRBOIC	: 1;		// Response Overrun Interrupt Control
	volatile UInt8 RINTCNT_RIRBDMAEN: 1;		// RIRB DMA Enable
	volatile UInt8 RINTCNT_RINTCTL	: 1;		// Response Interrupt Control
	// 5Dh: RIRBSTS – RIRB Status
	UInt8							: 5;		// Reserved
	volatile UInt8 RIRBSTS_RIRBOIS	: 1;		// Response Overrun Interrupt Status
	UInt8							: 1;		// Reserved
	volatile UInt8 RIRBSTS_RINTFL	: 1;		// Response Interrupt
	// 5Eh: RIRBSIZE – RIRB Size
	volatile UInt8 RIRBSIZE_RIRBSZCAP: 4;		// RIRB Size Capability
	UInt8							: 2;		// Reserved
	volatile UInt8 RIRBSIZE			: 2;		// RIRB Size

	UInt8							: 8;		// Spacer

	// 60h: Immediate Command Output Interface
	volatile UInt32 ICW;						// Immediate Command Write
	// 64h: Immediate Response Input Interface
	volatile UInt32 IRR;						// Immediate Response Read
	// 68h: Immediate Command Status
	union
	{
		volatile UInt16 ICS;					// Immediate Command Status
		UInt16							: 8;	// Reserved
		volatile UInt16 ICS_IRRADD		: 4;	// Immediate Response Result Address
		volatile UInt16 ICS_IRRUNSOL	: 1;	// Immediate Response Result Unsolicited
		volatile UInt16 ICS_ICV			: 1;	// Immediate Command Version
		volatile UInt16 ICS_IRV			: 1;	// Immediate Result Valid
		volatile UInt16 ICS_ICB			: 1;	// Immediate Command Busy
	};

	UInt32							: 32;		// Spacer
	UInt16							: 16;		// Spacer

	// 70h: DPLBASE – DMA Position Lower Base Address
	volatile UInt32 DPLBASE_ADDR	: 25;		// DMA Position Lower Base Address
	UInt32							: 6;
	volatile UInt32 DPLBASE_ENBL	: 1;		// DMA Position Buffer Enable
	// 74h: DPUBASE – DMA Position Upper Base Address
	volatile UInt32 DPUBASE;					// DMA Position Upper Base Address
} HDA_REG, *pHDA_REG;

// Global Capabilities response
struct HDA_GCAP
{
	UInt16 NumOutputStreamsSupported : 4;
	UInt16 NumInputStreamsSupported : 4;
	UInt16 NumBidirectionalStreamsSupported : 5;
	UInt16 NumSerialDataOutSignals : 2;
	UInt16 Supports64bits : 1;
};

// Global Capabilities & HDA Version response
struct HDA_GCAP_EXT : HDA_GCAP
{
	UInt8 MinorVersion;
	UInt8 MajorVersion;
};

enum HDACommandMode
{
	PIO,
	DMA
};

class IntelHDA
{
	IOPCIDevice* mDevice = NULL;
	IODeviceMemory* mDeviceMemory = NULL;
	IOMemoryMap* mMemoryMap = NULL;

	pHDA_REG mRegMap = NULL;

	// Initialized in constructor
	HDACommandMode mCommandMode;
	UInt32 mCodecVendorId;
	UInt32 mCodecSubsystemId;
    UInt32 mCodecRevisionId;
	UInt8 mCodecGroupType;
	UInt8 mCodecAddress;

	// Read-once parameters
	UInt32 mNodes = -1;
	UInt16 mAudioRoot = -1;

public:
	// Constructor
	IntelHDA(IOService *provider, HDACommandMode commandMode);
	// Destructor
	~IntelHDA();

	bool initialize();

	void applyIntelTCSEL();

	// 12-bit verb and 8-bit payload
	UInt32 sendCommand(UInt8 nodeId, UInt16 verb, UInt8 payload);
	// 4-bit verb and 16-bit payload
	UInt32 sendCommand(UInt8 nodeId, UInt8 verb, UInt16 payload);

	// Send a raw command (verb and payload combined)
	UInt32 sendCommand(UInt32 command);

	void resetCodec();

	UInt32 getCodecVendorId() { return mCodecVendorId; }
	UInt8 getCodecAddress() { return mCodecAddress; }
	UInt8 getCodecGroupType() { return mCodecGroupType; }
    UInt32 getCodecSubsystemId() { return mCodecSubsystemId; }
    UInt32 getCodecRevisionId() { return mCodecRevisionId; }

	UInt16 getVendorId();
	UInt16 getDeviceId();
	UInt32 getPCISubId();
	UInt32 getSubsystemId();
    UInt32 getRevisionId();

	UInt8 getTotalNodes();
	UInt8 getStartingNode();

private:
	UInt32 executePIO(UInt32 command);
	UInt16 getAudioRoot();
};

#endif
