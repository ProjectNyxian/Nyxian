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

#import <LindChain/ProcEnvironment/environment.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Nyxian-Swift.h>
#import "bridge.h"

int main(int argc, char * argv[])
{
    @autoreleasepool
    {
        /* initilizing environment */
#if !JAILBREAK_ENV
        environment_init(EnvironmentRoleHost, EnvironmentExecCustom, [[[NSBundle mainBundle] executablePath] UTF8String], argc, argv);
#endif // !JAILBREAK_ENV
        
        /* do bootstrapping */
        [[Bootstrap shared] bootstrap];                         /* starts bootstrapping */
        
#if !JAILBREAK_ENV
        /* entry point is the new setup chain, better than using this lazy __attribute__ 100% control */
        [LaunchServices shared];                                /* invokes launch services startup*/
#endif // !JAILBREAK_ENV
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
