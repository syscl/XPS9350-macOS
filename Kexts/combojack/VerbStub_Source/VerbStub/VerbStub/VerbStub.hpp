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

#include <IOKit/IOService.h>
#include <IOKit/IOUserClient.h>
#include "IntelHDA.h"

// External client methods
enum
{
    kClientExecuteVerb = 0,
    kClientNumMethods
};

class com_XPS_VerbStub : public IOService
{
    OSDeclareDefaultStructors(com_XPS_VerbStub)
public:
    virtual bool init(OSDictionary *dictionary = 0);
    virtual void free(void);
    virtual IOService *probe(IOService *provider, SInt32 *score);
    virtual bool start(IOService *provider);
    virtual void stop(IOService *provider);
   
    UInt32 ExternalCommand(UInt32 command);

private: // Only for use by com_XPS_VerbStub::functions
    IOService *AudioDevc = NULL;
    IntelHDA *HDADevice = NULL;

};

class VerbStubUserClient : public IOUserClient
{
    /*
     * Declare the metaclass information that is used for runtime
     * typechecking of IOKit objects.
     */

    OSDeclareDefaultStructors(VerbStubUserClient)
    
private:
    com_XPS_VerbStub* providertarget;
    task_t mTask;
    SInt32 mOpenCount;
    
    static const IOExternalMethodDispatch sMethods[kClientNumMethods];
    
public:

    /* IOService overrides */

    virtual bool start(IOService* provider);
    virtual void stop(IOService* provider);

    /* IOUserClient overrides */

    virtual bool initWithTask(task_t owningTask, void * securityID, UInt32 type, OSDictionary* properties);
    virtual IOReturn clientClose(void);
    
    virtual IOReturn externalMethod(uint32_t selector, IOExternalMethodArguments *arguments, IOExternalMethodDispatch* dispatch = 0,
                                    OSObject* target = 0, void* reference = 0);
    /* External methods */

    static IOReturn executeVerb(com_XPS_VerbStub* target, void* reference, IOExternalMethodArguments* arguments);
};

class VerbStubResidency : public IOService
{
private:
    
    /*
     * Declare the metaclass information that is used for runtime
     * typechecking of IOKit objects.
     */
    
    OSDeclareDefaultStructors(VerbStubResidency);
    
    // standard IOKit methods
    virtual bool start(IOService *provider);
};
