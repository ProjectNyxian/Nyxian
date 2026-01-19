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

#import <LindChain/jbroot.h>
#import <LindChain/Shell.h>
#import <LindChain/libroot.h>

NSString *IGottaNeedTheActualJBRootMate(void)
{
    /* root placeholder for the once run */
    static NSString *root = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* i wanna hear libroots part of the story */
        const char *prerootC = libroot_dyn_get_jbroot_prefix();
        NSString *preroot = [NSString stringWithCString:prerootC encoding:NSUTF8StringEncoding];
        
        /* checking if libroot says the truth if so this is it */
        if([[NSFileManager defaultManager] fileExistsAtPath:preroot])
        {
            root = preroot;
            return;
        }
        
        /* liar liar pants on fire */
        NSError *error = nil;
        NSArray<NSString*> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/var/containers/Bundle/Application" error:&error];
        
        if(error != nil ||
           files == nil)
        {
            return;
        }
        
        /* checking for roothide */
        for(NSString *item in files)
        {
            if([item hasPrefix:@".jbroot-"])
            {
                root = [NSString stringWithFormat:@"%@/%@", @"/var/containers/Bundle/Application/", item];
                return;
            }
        }
    });
    
    return root;
}
