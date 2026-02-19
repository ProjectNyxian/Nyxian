/*
 Copyright (C) 2026 cr4zyengineer

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

#import <LindChain/CheckEngine/CheckEngine.h>
#import <LindChain/CheckEngine/CheckFile.h>
#import <os/lock.h>

@implementation CheckFile {
    os_unfair_lock _lock;
    __strong NSData *_contentData;
}

- (instancetype)initWithEngine:(CheckEngine*)engine
                      withPath:(NSString*)path
{
    assert(engine != nil);
    assert(path != nil);
    
    self = [super init];
    if(self)
    {
        _lock = OS_UNFAIR_LOCK_INIT;
        _engine = engine;
        _unsavedFile.Filename = strdup([path UTF8String]);
    }
    return self;
}

- (void)reparseFileWithContent:(NSString*)content
{
    /* getting data from content (dont allow lossy conversion, because otherwise chineese, japanese, etc users are pissed off)*/
    NSData *newData = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!newData)
    {
        return;
    }
    
    os_unfair_lock_lock(&_lock);
    
    /* set new properties */
    _contentData = newData;
    _unsavedFile.Contents = (const char*)_contentData.bytes;
    _unsavedFile.Length   = (unsigned long)_contentData.length;
    
    /* trigger reparse */
    [self.engine reparse];
    
    os_unfair_lock_unlock(&_lock);
}

@end
