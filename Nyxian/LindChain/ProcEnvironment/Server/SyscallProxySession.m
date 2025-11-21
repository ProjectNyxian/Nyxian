/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Server/SyscallProxySession.h>
#import <sys/syscall.h>

@implementation SyscallProxySession

- (void)syscall:(long)call
  withArguments:(NSArray<NSNumber*>*)arguments
      withReply:(void (^)(unsigned long))reply
{
    unsigned long sysarg[10] = {};
    for(unsigned char i = 0; i < arguments.count && i < 10; i++)
    {
        sysarg[i] = arguments[i].unsignedLongValue;
    }
    reply(syscall(call, sysarg[0], sysarg[1], sysarg[2], sysarg[3], sysarg[4], sysarg[5], sysarg[6], sysarg[7], sysarg[8], sysarg[9]));
}

- (void)mappingPortObjectWithSize:(unsigned long)size
                         withProt:(vm_prot_t)prot
                        withReply:(void (^)(MappingPortObject*))reply
{
    reply([[MappingPortObject alloc] initWithSize:size withProt:prot]);
}

@end
