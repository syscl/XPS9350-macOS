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
// Apple Driver Documentation
//
// Writing a kernel extension:
// https://developer.apple.com/library/content/documentation/Darwin/Conceptual/KEXTConcept/KEXTConceptIOKit/iokit_tutorial.html
// IOKit Fundamentals:
// https://developer.apple.com/library/content/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Introduction/Introduction.html
// Writing an IOKit driver:
// https://developer.apple.com/library/content/documentation/DeviceDrivers/Conceptual/WritingDeviceDriver/Introduction/Intro.html
// Accessing Hardware:
// https://developer.apple.com/library/content/documentation/DeviceDrivers/Conceptual/AccessingHardware/AH_Intro/AH_Intro.html
// User Client Info (sample user client driver interface):
// https://developer.apple.com/library/content/samplecode/SimpleUserClient/Listings/User_Client_Info_txt.html
//

#include <IOKit/IOLib.h>
#include "VerbStub.hpp"

//*********************************************************************
// VerbStub Main Kernel Driver:
//*********************************************************************

// This required macro defines the class's constructors, destructors,
// and several other methods I/O Kit requires.
OSDefineMetaClassAndStructors(com_XPS_VerbStub, IOService)

// Define the driver's superclass.
#define super IOService

//
// IOKit driver init override (for logging)
//

bool com_XPS_VerbStub::init(OSDictionary *dict)
{
    bool result = super::init(dict);
    IOLog("Initializing...\n");
    return result;
}

//
// IOkit driver free override (for logging)
//

void com_XPS_VerbStub::free(void)
{
    IOLog("Freeing...\n");
    super::free();
}

//
// IOkit driver probe override (for logging)
//

IOService *com_XPS_VerbStub::probe(IOService *provider,
                                                SInt32 *score)
{
    IOService *result = super::probe(provider, score);
    IOLog("Probing...\n");
    return result;
}

// This function only gets used by 'start' to set IORegistry properties
static void setNumberProperty(IOService* service, const char* key, UInt32 value)
{
    OSNumber* num = OSNumber::withNumber(value, 32);
    if (num)
    {
        service->setProperty(key, num);
        num->release();
    }
}

//
// IOkit driver start override
//

bool com_XPS_VerbStub::start(IOService *provider)
{
    bool result = super::start(provider);
    IOLog("Starting...\n");
    if (!result)
    {
        IOLog("Error starting driver.\n");
        return result;
    }
    
    // cache the provider
    AudioDevc = provider;
    
    HDADevice = new IntelHDA(provider, PIO);
    if (!HDADevice || !HDADevice->initialize())
    {
        IOLog("Error initializing HDADevice instance.\n");
        stop(provider);
        return false;
    }

    // Populate HDA properties in IORegistry
    setNumberProperty(this, kCodecVendorID, HDADevice->getCodecVendorId());
    setNumberProperty(this, kCodecAddress, HDADevice->getCodecAddress());
    setNumberProperty(this, kCodecFuncGroupType, HDADevice->getCodecGroupType());
    setNumberProperty(this, kCodecSubsystemID, HDADevice->getCodecSubsystemId());
    setNumberProperty(this, kCodecRevisionID, HDADevice->getCodecRevisionId());

    this->registerService(0);
    return result;
}

//
// IOkit driver stop override
//

void com_XPS_VerbStub::stop(IOService *provider)
{
    IOLog("Stopping...\n");
    
    // Free HDADevice
    delete HDADevice;
    HDADevice = NULL;
    
    AudioDevc = NULL;
    
    super::stop(provider);
}

//
// Execute external command from user client
//

UInt32 com_XPS_VerbStub::ExternalCommand(UInt32 command)
{
    if (HDADevice)
    {
        UInt32 response;
        response = HDADevice->sendCommand(command);
        return response;
    }
    return -1;
}

//*********************************************************************
// VerbStub Userspace Client:
//*********************************************************************

//
// This should match IOConnectCallScalarMethod in hda-verb.c because this
// is the link to user-space.
//

const IOExternalMethodDispatch VerbStubUserClient::sMethods[kClientNumMethods] =
{
    { // kClientExecuteVerb
        (IOExternalMethodAction)&VerbStubUserClient::executeVerb,
        1, // One scalar input value
        0, // No struct inputs
        1, // One scalar output value
        0  // No struct outputs
    }
};

// Structure of IOExternalMethodDispatch:
// https://developer.apple.com/library/content/samplecode/SimpleUserClient/Listings/User_Client_Info_txt.html
/*
 struct IOExternalMethodDispatch
 {
 IOExternalMethodAction function;
 uint32_t           checkScalarInputCount;
 uint32_t           checkStructureInputSize;
 uint32_t           checkScalarOutputCount;
 uint32_t           checkStructureOutputSize;
 };
*/

/*
 * Define the metaclass information that is used for runtime
 * typechecking of IOKit objects. We're a subclass of IOUserClient.
 */

OSDefineMetaClassAndStructors(VerbStubUserClient, IOUserClient)

//
// IOUserClient user-kernel boundary interface init (initWithTask)
//

bool VerbStubUserClient::initWithTask(task_t owningTask, void* securityID, UInt32 type, OSDictionary* properties)
{
    IOLog("Client::initWithTask(type %u)\n", (unsigned int)type);
    
    mTask = owningTask;
    
    return IOUserClient::initWithTask(owningTask, securityID, type, properties);
}

//
// IOUserClient user-kernel boundary interface start
//

bool VerbStubUserClient::start(IOService * provider)
{
    bool result = IOUserClient::start(provider);
    IOLog("Client::start\n");
    
    if(!result)
        return(result);
    
    /*
     * Provider is always com_XPS_VerbStub
     */
    assert(OSDynamicCast(com_XPS_VerbStub, provider));
    providertarget = (com_XPS_VerbStub*) provider;
    
    mOpenCount = 1;
    
    return result;
}

//
// IOUserClient user-kernel boundary interface client exit behavior
//

IOReturn VerbStubUserClient::clientClose(void)
{
    if (!isInactive())
        terminate();
    
    return kIOReturnSuccess;
}

//
// IOUserClient user-kernel boundary interface stop override 
//

void VerbStubUserClient::stop(IOService * provider)
{
    IOLog("Client::stop\n");
    
    IOUserClient::stop(provider);
}

//
// IOUserClient handle external method
//

IOReturn VerbStubUserClient::externalMethod(uint32_t selector, IOExternalMethodArguments* arguments,
                                              IOExternalMethodDispatch* dispatch, OSObject* target, void* reference)
{
    DebugLog("%s[%p]::%s(%d, %p, %p, %p, %p)\n", getName(), this, __FUNCTION__, selector, arguments, dispatch, target, reference);
    
    if (selector < (uint32_t)kClientNumMethods)
    {
        dispatch = (IOExternalMethodDispatch *)&sMethods[selector];
        
        if (!target)
        {
            if (selector == kClientExecuteVerb)
                target = providertarget;
            else
                target = this;
        }
    }
    
    return IOUserClient::externalMethod(selector, arguments, dispatch, target, reference);
}

IOReturn VerbStubUserClient::executeVerb(com_XPS_VerbStub* target, void* reference, IOExternalMethodArguments* arguments)
{
    arguments->scalarOutput[0] = target->ExternalCommand((UInt32)arguments->scalarInput[0]);
    return kIOReturnSuccess;
}

//*********************************************************************
// VerbStub Boot-Time Residency Component:
//*********************************************************************

//
// Stay resident to load the kext when needed
//

OSDefineMetaClassAndStructors(VerbStubResidency, IOService)

bool VerbStubResidency::start(IOService *provider)
{
    // announce version
    extern kmod_info_t kmod_info;
    
    // place version in ioreg properties
    char buf[128];
    snprintf(buf, sizeof(buf), "%s %s", kmod_info.name, kmod_info.version);
    setProperty("VerbStub,Version", buf);
    
    return super::start(provider);
}
