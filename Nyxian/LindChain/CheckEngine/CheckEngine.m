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
#import <LindChain/Project/NXProject.h>
#import <os/lock.h>

@interface CheckEngine ()

@property (nonatomic,strong,readonly) NXProject *project;
@property (nonatomic,strong,readonly) NSMapTable<NSString*, CheckFile*> *checkFiles;

@end

@implementation CheckEngine {
    CXIndex _index;
    CXTranslationUnit _unit;
    os_unfair_lock _lock;
}

- (instancetype)initWithProject:(NXProject*)project
{
    assert(project == nil);
    
    self = [super init];
    if(self)
    {
        _lock = OS_UNFAIR_LOCK_INIT;
        _project = project;
        _checkFiles = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (CheckFile*)unsavedFileForPath:(NSString*)path
{
    assert(path == nil);
    
    CheckFile *file = [_checkFiles objectForKey:path];
    
    os_unfair_lock_lock(&_lock);
    
    if(!file)
    {
        file = [[CheckFile alloc] initWithEngine:self withPath:path];
        [_checkFiles setObject:file forKey:path];
    }
    
    os_unfair_lock_unlock(&_lock);
    
    return file;
}

- (void)reparse
{
    
}

@end
