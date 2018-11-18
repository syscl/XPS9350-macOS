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

#include "IntelHDA.h"

#define kIntelVendorID              0x8086
#define kIntelRegTCSEL              0x44

static IOPCIDevice* getPCIDevice(IORegistryEntry* registryEntry)
{
    IOPCIDevice* result = NULL;
    while (registryEntry)
    {
        result = OSDynamicCast(IOPCIDevice, registryEntry);
        if (result)
            break;
        registryEntry = registryEntry->getParentEntry(gIOServicePlane);
    }
    return result;
}

static UInt32 getPropertyValue(IORegistryEntry* registryEntry, const char* propertyName)
{
    UInt32 result = -1;
    while (registryEntry)
    {
        if (OSNumber* value = OSDynamicCast(OSNumber, registryEntry->getProperty(propertyName)))
        {
            result = value->unsigned32BitValue();
            break;
        }
        registryEntry = registryEntry->getParentEntry(gIOServicePlane);
    }
    return result;
}

IntelHDA::IntelHDA(IOService* provider, HDACommandMode commandMode)
{
    mCommandMode = commandMode;
    mDevice = getPCIDevice(provider);

    mCodecVendorId = getPropertyValue(provider, kCodecVendorID);
    mCodecGroupType = getPropertyValue(provider, kCodecFuncGroupType);
    mCodecAddress = getPropertyValue(provider, kCodecAddress);
    mCodecSubsystemId = getPropertyValue(provider, kCodecSubsystemID);
    mCodecRevisionId = getPropertyValue(provider, kCodecRevisionID);

    // defaults for VoodooHDA...
    if (0xFF == mCodecGroupType) mCodecGroupType = 1;
    if (0xFF == mCodecAddress) mCodecAddress = 0;
}

IntelHDA::~IntelHDA()
{
    OSSafeReleaseNULL(mMemoryMap);
}

bool IntelHDA::initialize()
{
    DebugLog("IntelHDA::initialize\n");
    
    if (mDevice == NULL)
    {
        AlwaysLog("mDevice is NULL in IntelHDA::initialize\n");
        return false;
    }
    if (mDevice->getDeviceMemoryCount() == 0)
    {
        AlwaysLog("getDeviceMemoryCount returned 0 in IntelHDA::initialize\n");
        return false;
    }
    if (mCodecAddress == 0xFF)
    {
        AlwaysLog("mCodecAddress is 0xFF in IntelHDA::initialize\n");
        return false;
    }
    if (mCodecGroupType != HDA_TYPE_AFG)
    {
        DebugLog("mCodecGroupType is %d (must be 1) in IntelHDA::initialize\n", mCodecGroupType);
        return false;
    }

    mDevice->setMemoryEnable(true);
    
    mDeviceMemory = mDevice->getDeviceMemoryWithIndex(0);
    
    if (mDeviceMemory == NULL)
    {
        AlwaysLog("Failed to access device memory.\n");
        return false;
    }
    
    DebugLog("Device memory @ 0x%08llx, size 0x%08llx\n", mDeviceMemory->getPhysicalAddress(), mDeviceMemory->getLength());
        
    mMemoryMap = mDeviceMemory->map();

    if (mMemoryMap == NULL)
    {
        AlwaysLog("Failed to map device memory.\n");
        return false;
    }
    
    DebugLog("Memory mapped at @ 0x%08llx\n", mMemoryMap->getVirtualAddress());
        
    mRegMap = (pHDA_REG)mMemoryMap->getVirtualAddress();
    
    char devicePath[1024];
    int pathLen = sizeof(devicePath);
    bzero(devicePath, sizeof(devicePath));
    
    uint32_t deviceInfo = mDevice->configRead32(0);
    
    if (mDevice->getPath(devicePath, &pathLen, gIOServicePlane))
        AlwaysLog("Evaluating device \"%s\" [%04x:%04x].\n",
                  devicePath,
                  deviceInfo & 0xFFFF,
                  deviceInfo >> 16);

    // Note: Must reset the codec here for getVendorId to work.
    //  If the computer is restarted when the codec is in fugue state (D3cold),
    //  it will not respond without the Double Function Group Reset.
    if (mCodecVendorId == -1 && this->getVendorId() == 0xFFFF)
        this->resetCodec();

    if (mRegMap->VMAJ == 1 && mRegMap->VMIN == 0 && this->getVendorId() != 0xFFFF)
    {
        UInt16 vendor = this->getVendorId();
        UInt16 device = this->getDeviceId();
        UInt32 subsystem = this->getSubsystemId();
        UInt32 revision = this->getRevisionId();

        if (mCodecVendorId == (UInt32)-1)
            mCodecVendorId = (UInt32)vendor << 16 | device;

        // avoid logging HDMI audio (except in DEBUG build) as it is disabled anyway
#ifndef DEBUG
        if (vendor != 0x8086)
#endif
        {
            AlwaysLog("....Codec Vendor ID: 0x%08x\n", mCodecVendorId);
            AlwaysLog("....Codec Address: %d\n", mCodecAddress);
            AlwaysLog("....Subsystem ID: 0x%08x\n", subsystem);
            AlwaysLog("....Revision ID: 0x%08x\n", revision);
            AlwaysLog("....PCI Sub ID: 0x%08x\n", getPCISubId());
            DebugLog("....Output Streams: %d\n", mRegMap->GCAP_OSS);
            DebugLog("....Input Streams: %d\n", mRegMap->GCAP_ISS);
            DebugLog("....Bidi Streams: %d\n", mRegMap->GCAP_BSS);
            DebugLog("....Serial Data: %d\n", mRegMap->GCAP_NSDO);
            DebugLog("....x64 Support: %d\n", mRegMap->GCAP_64OK);
            DebugLog("....Codec Version: %d.%d\n", mRegMap->VMAJ, mRegMap->VMIN);
            DebugLog("....Vendor ID: 0x%04x\n", vendor);
            DebugLog("....Device ID: 0x%04x\n", device);
        }
    
        return true;
    }
    
    return false;
}

void IntelHDA::resetCodec()
{
    /*
     Reset is created by sending two Function Group resets, potentially separated
     by an undefined number of idle frames, but no other valid commands.
     This Function Group “Double” reset shall do a full initialization and reset
     most settings to their power on defaults.
     */

    DebugLog("--> resetting codec\n");

    UInt16 audioRoot = getAudioRoot();
    this->sendCommand(audioRoot, HDA_VERB_RESET, HDA_PARM_NULL);
    IOSleep(1);
    this->sendCommand(audioRoot, HDA_VERB_RESET, HDA_PARM_NULL);
    IOSleep(220); // per-HDA spec, device must respond (D0) within 200ms

    // forcefully set power state to D3
    this->sendCommand(audioRoot, HDA_VERB_SET_PSTATE, HDA_PARM_PS_D3_HOT);
    DebugLog("--> hda codec power restored\n");
}

void IntelHDA::applyIntelTCSEL()
{
    if (mDevice && mDevice->configRead16(kIOPCIConfigVendorID) == kIntelVendorID)
    {
        /* Clear bits 0-2 of PCI register TCSEL (at offset 0x44)
         * TCSEL == Traffic Class Select Register, which sets PCI express QOS
         * Ensuring these bits are 0 clears playback static on some HD Audio
         * codecs.
         * The PCI register TCSEL is defined in the Intel manuals.
         */
        UInt8 value = mDevice->configRead8(kIntelRegTCSEL);
        UInt8 newValue = value & ~0x07;
        if (newValue != value)
        {
            mDevice->configWrite8(kIntelRegTCSEL, newValue);
            DebugLog("Intel TCSEL: 0x%02x -> 0x%02x\n", value, newValue);
        }
    }
}

UInt16 IntelHDA::getVendorId()
{
    if (mCodecVendorId == -1)
        mCodecVendorId = this->sendCommand(0, HDA_VERB_GET_PARAM, HDA_PARM_VENDOR);
    
    return mCodecVendorId >> 16;
}

UInt16 IntelHDA::getDeviceId()
{
    if (mCodecVendorId == -1)
        mCodecVendorId = this->sendCommand(0, HDA_VERB_GET_PARAM, HDA_PARM_VENDOR);
    
    return mCodecVendorId & 0xFFFF;
}

UInt16 IntelHDA::getAudioRoot()
{
    if (mAudioRoot == (UInt16)-1)
    {
        UInt32 nodes = this->sendCommand(0, HDA_VERB_GET_PARAM, HDA_PARM_NODECOUNT);
        if (nodes != -1)
        {
            UInt16 start = nodes & 0xFF;
            UInt16 end = start + ((nodes & 0xFF0000) >> 16);
            for (UInt16 node = start; node < end; node++)
            {
                UInt32 type = this->sendCommand(node, HDA_VERB_GET_PARAM, HDA_PARM_FUNCGRP);
                if ((type & 0xFF) == HDA_TYPE_AFG)
                {
                    DebugLog("getAudioRoot found audio root = 0x%02x\n", node);
                    mAudioRoot = node;
                    break;
                }
            }
        }
        if (mAudioRoot == (UInt16)-1)
        {
            DebugLog("getAudioRoot failed to find audio root... using default root of 1\n");
            mAudioRoot = 1;
        }
    }
    return mAudioRoot;
}

UInt8 IntelHDA::getTotalNodes()
{
    if (mNodes == -1)
    {
        UInt16 audioRoot = getAudioRoot();
        mNodes = this->sendCommand(audioRoot, HDA_VERB_GET_PARAM, HDA_PARM_NODECOUNT);
        // in the case of an invalid response, use zero
        if (mNodes == -1) mNodes = 0;
    }
    return mNodes & 0x0000FF;
}

UInt8 IntelHDA::getStartingNode()
{
    if (mNodes == -1)
    {
        UInt16 audioRoot = getAudioRoot();
        mNodes = this->sendCommand(audioRoot, HDA_VERB_GET_PARAM, HDA_PARM_NODECOUNT);
        // in the case of an invalid response, use zero
        if (mNodes == -1) mNodes = 0;
    }
    return (mNodes & 0xFF0000) >> 16;
}

UInt32 IntelHDA::getSubsystemId()
{
    if (mCodecSubsystemId == -1)
    {
        UInt16 audioRoot = getAudioRoot();
        mCodecSubsystemId = this->sendCommand(audioRoot, HDA_VERB_GET_SUBSYSTEM_ID, HDA_PARM_NULL);
        // in the case of an invalid response, use zero
        if (mCodecSubsystemId == -1) mCodecSubsystemId = 0;
    }
    return mCodecSubsystemId;
}

UInt32 IntelHDA::getPCISubId()
{
    UInt32 result = mDevice->configRead32(kIOPCIConfigSubSystemVendorID);
    // flip words to be consistent with other 32-bit identifiers
    return ((result & 0xFFFF) << 16) | result >> 16;
}

UInt32 IntelHDA::getRevisionId()
{
    if (mCodecRevisionId == -1)
    {
        UInt16 audioRoot = getAudioRoot();
        mCodecRevisionId = this->sendCommand(audioRoot, HDA_VERB_GET_PARAM, HDA_PARM_REVISION);
        // in the case of an invalid response, use zero
        if (mCodecRevisionId == -1) mCodecRevisionId = 0;
    }
    return mCodecRevisionId;
}

UInt32 IntelHDA::sendCommand(UInt8 nodeId, UInt16 verb, UInt8 payload)
{
    DebugLog("SendCommand: node 0x%02x, verb 0x%06x, payload 0x%02x.\n", nodeId, verb, payload);
    return this->sendCommand((nodeId & 0xFF) << 20 | (verb & 0xFFF) << 8 | payload);
}

UInt32 IntelHDA::sendCommand(UInt8 nodeId, UInt8 verb, UInt16 payload)
{
    DebugLog("SendCommand: node 0x%02x, verb 0x%02x, payload 0x%04x.\n", nodeId, verb, payload);
    return this->sendCommand((nodeId & 0xFF) << 20 | (verb & 0xF) << 16 | payload);
}

UInt32 IntelHDA::sendCommand(UInt32 command)
{
    UInt32 fullCommand = (mCodecAddress & 0xF) << 28 | (command & 0x0FFFFFFF);
    
    if (mDeviceMemory == NULL)
        return -1;
    
    DebugLog("SendCommand: (w) --> 0x%08x\n", fullCommand);
  
    UInt32 response = -1;
    
    switch (mCommandMode)
    {
        case PIO:
            response = this->executePIO(fullCommand);
            break;
        case DMA:
            AlwaysLog("Unsupported command mode DMA requested.\n");
            response = -1;
            break;
        default:
            response = -1;
            break;
    }
    
    DebugLog("SendCommand: (r) <-- 0x%08x\n", response);
    
    return response;
}

UInt32 IntelHDA::executePIO(UInt32 command)
{
    UInt16 status;
    
    status = 0x1; // Busy status
    
    for (int i = 0; i < 1000; i++)
    {
        status = mRegMap->ICS;
        
        if (!HDA_ICS_IS_BUSY(status))
            break;
        
        ::IODelay(100);
    }
    
    // HDA controller was not ready to receive PIO commands
    if (HDA_ICS_IS_BUSY(status))
    {
        DebugLog("ExecutePIO timed out waiting for ICS readiness.\n");
        return -1;
    }
    
    //DEBUG_LOG("IntelHDA::ExecutePIO ICB bit clear.\n");
    
    // Queue the verb for the HDA controller
    mRegMap->ICW = command;
    
    status = 0x1; // Busy status
    mRegMap->ICS = status;
    
    //DEBUG_LOG("IntelHDA::ExecutePIO Wrote verb and set ICB bit.\n");
    
    // Wait for HDA controller to return with a response
    for (int i = 0; i < 1000; i++)
    {
        status = mRegMap->ICS;
        
        if (!HDA_ICS_IS_BUSY(status))
            break;
        
        ::IODelay(100);
    }
    
    // Store the result validity while IRV is cleared
    bool validResult = HDA_ICS_IS_VALID(status);
    
    UInt32 response = 0xdeadbeef; //Obvious indication that something weird occurred
    
    if (validResult)
        response = mRegMap->IRR;
    
    // Reset IRV
    status = 0x02; // Valid, Non-busy status
    mRegMap->ICS = status;
    
    if (!validResult)
    {
        DebugLog("ExecutePIO Invalid result received.\n");
        return -1;
    }
    
    return response;
}
