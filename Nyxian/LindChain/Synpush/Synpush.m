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

#import <LindChain/Synpush/Synpush.h>
#import <pthread.h>
#import <dispatch/dispatch.h>
#import <string.h>
#import <strings.h>

static unsigned tuFlags = CXTranslationUnit_CacheCompletionResults |
                          CXTranslationUnit_KeepGoing |
                          CXTranslationUnit_IncludeBriefCommentsInCodeCompletion |
                          CXTranslationUnit_DetailedPreprocessingRecord;

#pragma mark - Small C helpers

static inline uint8_t mapSeverity(enum CXDiagnosticSeverity severity) {
    switch (severity) {
        case CXDiagnostic_Note:    return 0;
        case CXDiagnostic_Warning: return 1;
        case CXDiagnostic_Error:
        case CXDiagnostic_Fatal:   return 2;
        default:                   return 2;
    }
}

#pragma mark - SynpushServer

@interface SynpushServer () {
    CXIndex _index;
    CXTranslationUnit _unit;
    struct CXUnsavedFile _unsaved;
    NSData *_contentData;
    NSString *_filepath;
    char *_cFilename;
    int _argc;
    char **_args;
    pthread_mutex_t _mutex;
}
@end

@implementation SynpushServer

- (instancetype)init:(NSString*)filepath
{
    self = [super init];
    if(!self) return nil;

    /* initilizing step numero uno */
    _filepath = [filepath copy];
    _cFilename = strdup(_filepath.UTF8String);
    _unsaved.Filename = _cFilename;

    pthread_mutex_init(&_mutex, NULL);
    return self;
}

#pragma mark - Reparse (incremental)

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args
{
    /* getting data from content (dont allow lossy conversion, because otherwise chineese, japanese, etc users are pissed off)*/
    NSData *newData = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!newData)
    {
        return;
    }
    
    pthread_mutex_lock(&_mutex);
    
    /* checking for unit */
    if(!_unit)
    {
        /* needs reactivation */
        pthread_mutex_unlock(&_mutex);
        [self reactivateWithContent:content withArgs:args];
        return;
    }
    
    _contentData = newData;

    _unsaved.Filename = _cFilename;
    _unsaved.Contents = (const char*)_contentData.bytes;
    _unsaved.Length   = (unsigned long)_contentData.length;
    clang_reparseTranslationUnit(_unit, 1, &_unsaved, clang_defaultReparseOptions(_unit));

    pthread_mutex_unlock(&_mutex);
}

- (NSArray<Synitem *> *)getDiagnostics
{
    pthread_mutex_lock(&_mutex);

    /* checking if unit is already active */
    if(!_unit)
    {
        /* its not so fall back to being an asshole */
        pthread_mutex_unlock(&_mutex);
        return @[];
    }
    
    unsigned count = clang_getNumDiagnostics(_unit);
    
    /* preallocating array with count of items */
    NSMutableArray<Synitem *> *items = [NSMutableArray arrayWithCapacity:count];

    CXFile targetFile = NULL;
    for(unsigned i = 0; i < count; ++i)
    {
        /* getting diagnostic */
        CXDiagnostic diag = clang_getDiagnostic(_unit, i);
        
        /* getting severity of diagnostic */
        enum CXDiagnosticSeverity severity = clang_getDiagnosticSeverity(diag);
        
        /* checking if we shall ignore the diagnostic */
        if(severity == CXDiagnostic_Ignored)
        {
            clang_disposeDiagnostic(diag);
            continue;
        }

        /* getting location of diagnostic (line and column basically lol x3) */
        CXSourceLocation loc = clang_getDiagnosticLocation(diag);
        
        /* now getting the user readable location */
        CXFile file;
        unsigned line = 0, col = 0;
        clang_getSpellingLocation(loc, &file, &line, &col, NULL);
        
        /* checking if we got the file already */
        if(targetFile == NULL)
        {
            
            /*
             * getting name of file and checking if its
             * the same file targetted
             */
            CXString fileName = clang_getFileName(file);
            const char *fn = clang_getCString(fileName);
            BOOL sameFile = (fn && _cFilename) ? (strcmp(fn, _cFilename) == 0) : NO;
            clang_disposeString(fileName);
            if(!sameFile)
            {
                clang_disposeDiagnostic(diag);
                continue;
            }
            
            /* finally got the targetFile */
            targetFile = file;
        }
        else
        {
            /* already got the file! */
            if(!clang_File_isEqual(file, targetFile))
            {
                clang_disposeDiagnostic(diag);
                continue;
            }
        }
        
        /* getting diagnostic string */
        CXString diagStr = clang_getDiagnosticSpelling(diag);
        const char *cmsg = clang_getCString(diagStr);

        /* creating actual SynItem! */
        Synitem *item = [[Synitem alloc] init];
        item.line    = line;
        item.column  = col;
        item.type    = mapSeverity(severity);
        item.message = [NSString stringWithFormat:@"%s", cmsg ?: "Unknown"];
        [items addObject:item];

        clang_disposeString(diagStr);
        clang_disposeDiagnostic(diag);
    }

    pthread_mutex_unlock(&_mutex);
    return items;
}

#pragma mark - Memory management

- (void)releaseMemory
{
    pthread_mutex_lock(&_mutex);
    
    /* dispose many clang things to get rid of most */
    if(_unit)
    {
        clang_disposeTranslationUnit(_unit);
        _unit = NULL;
    }
    
    if(_index)
    {
        clang_disposeIndex(_index);
        _index = NULL;
    }
    
    /* releasing content data memory */
    _contentData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    _unsaved.Contents = (const char*)_contentData.bytes;
    _unsaved.Length = 0;
    
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)isActive
{
    pthread_mutex_lock(&_mutex);
    BOOL active = (_unit != NULL);
    pthread_mutex_unlock(&_mutex);
    return active;
}

- (BOOL)reactivateWithContent:(NSString*)content withArgs:(NSArray*)args
{
    /* checking if server is still active */
    if([self isActive])
    {
        return YES;
    }
    
    /* its not so we need to reactivate it */
    pthread_mutex_lock(&_mutex);
    
    /* free if allocated */
    if(_args != NULL)
    {
        for (int i = 0; i < _argc; ++i) free(_args[i]);
        free(_args);
    }
    
    /* making arguments ready */
    _argc = (int)args.count;
    _args = (char**)calloc((size_t)_argc, sizeof(char*));
    for(int i = 0; i < _argc; ++i)
    {
        _args[i] = strdup([args[i] UTF8String]);
    }
    
    /* creating new data out of content */
    NSData *newData = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!newData)
    {
        pthread_mutex_unlock(&_mutex);
        return NO;
    }
    
    /* making sure that bytes doesnt get deallocated randomly */
    _contentData = newData;
    _unsaved.Contents = (const char*)_contentData.bytes;
    _unsaved.Length = (unsigned long)_contentData.length;
    
    /* creating new index */
    _index = clang_createIndex(0, 0);
    
    /* parsing code*/
    enum CXErrorCode err = clang_parseTranslationUnit2(_index, _cFilename, (const char *const *)_args, _argc, &_unsaved, 1, tuFlags, &_unit);
    
    /* done */
    pthread_mutex_unlock(&_mutex);
    
    return (err == CXError_Success && _unit != NULL);
}

- (void)dealloc
{
    /* locking and disposing lol */
    pthread_mutex_lock(&_mutex);
    if(_unit)
    {
        clang_disposeTranslationUnit(_unit);
    }
    if(_index)
    {
        clang_disposeIndex(_index);
    }
    
    if(_args != NULL)
    {
        
        /* releasing da rest */
        for (int i = 0; i < _argc; ++i) free(_args[i]);
        free(_args);
    }
    
    pthread_mutex_unlock(&_mutex);
    
    free(_cFilename);
    
    /* destroying the lock */
    pthread_mutex_destroy(&_mutex);
}

- (Syndef*)getDefinitionAtLine:(unsigned)line
                        column:(unsigned)column
{
    pthread_mutex_lock(&_mutex);
    
    /* no unit, no definition */
    if(!_unit)
    {
        pthread_mutex_unlock(&_mutex);
        return nil;
    }
    
    /* get the source file we are working with */
    CXFile file = clang_getFile(_unit, _cFilename);
    if(!file)
    {
        pthread_mutex_unlock(&_mutex);
        return nil;
    }
    
    /* build a source location from the provided line and column */
    CXSourceLocation loc = clang_getLocation(_unit, file, line, column);
    
    /* get the cursor sitting at that location */
    CXCursor cursor = clang_getCursor(_unit, loc);
    
    /* check if cursor is valid */
    if(clang_Cursor_isNull(cursor) || clang_isInvalid(clang_getCursorKind(cursor)))
    {
        pthread_mutex_unlock(&_mutex);
        return nil;
    }
    
    /* get the definition cursor — try direct definition first */
    CXCursor defCursor = clang_getCursorDefinition(cursor);

    /*
     * if that failed or returned the same location (call expr pointing to itself),
     * resolve the referenced symbol first, then get its definition.
     */
    if(clang_Cursor_isNull(defCursor) ||
       clang_isInvalid(clang_getCursorKind(defCursor)) ||
       clang_equalCursors(defCursor, cursor))
    {
        CXCursor referenced = clang_getCursorReferenced(cursor);
        
        if(!clang_Cursor_isNull(referenced) && !clang_isInvalid(clang_getCursorKind(referenced)))
        {
            defCursor = clang_getCursorDefinition(referenced);
            
            /* if still no definition, use the declaration itself */
            if(clang_Cursor_isNull(defCursor) || clang_isInvalid(clang_getCursorKind(defCursor)))
            {
                defCursor = referenced;
            }
        }
    }

    /* last resort: canonical declaration */
    if(clang_Cursor_isNull(defCursor) || clang_isInvalid(clang_getCursorKind(defCursor)))
    {
        defCursor = clang_getCanonicalCursor(cursor);
    }
    
    /* still nothing? bail */
    if(clang_Cursor_isNull(defCursor) || clang_isInvalid(clang_getCursorKind(defCursor)))
    {
        pthread_mutex_unlock(&_mutex);
        return nil;
    }
    
    /* extract the location of the definition */
    CXSourceLocation defLoc = clang_getCursorLocation(defCursor);
    
    CXFile defFile;
    unsigned defLine = 0, defCol = 0;
    clang_getSpellingLocation(defLoc, &defFile, &defLine, &defCol, NULL);
    
    if(!defFile)
    {
        pthread_mutex_unlock(&_mutex);
        return nil;
    }
    
    /* get the filepath of the definition */
    CXString defFilename = clang_getFileName(defFile);
    const char *defFilenameCStr = clang_getCString(defFilename);
    
    if(!defFilenameCStr)
    {
        clang_disposeString(defFilename);
        pthread_mutex_unlock(&_mutex);
        return nil;
    }
    
    /* build the result */
    Syndef *def = [[Syndef alloc] init];
    def.filepath = [NSString stringWithUTF8String:defFilenameCStr];
    def.line     = defLine;
    def.column   = defCol;
    
    clang_disposeString(defFilename);
    pthread_mutex_unlock(&_mutex);
    
    return def;
}

@end

