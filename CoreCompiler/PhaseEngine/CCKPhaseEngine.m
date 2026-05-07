/*
 * MIT License
 *
 * Copyright (c) 2026 mach-port-t
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <CoreCompiler/CCKPhaseEngine.h>

@interface CCKPhaseEngine ()

@property (nonatomic, readonly) NSArray<NSString*> *otherClangFlags;
@property (nonatomic, readonly) NSArray<NSString*> *otherLinkerFlags;

@end

static CCKJob *CCKPhaseGenerationJobByAppendingArgumentsHelper(CCKJob *job,
                                                               NSArray<NSString*> *arguments)
{
    return [CCKJob jobWithType:job.type withArguments:[job.arguments arrayByAddingObjectsFromArray:arguments]];
}

static void CCKPhaseGenerationEndHelper(CCKPhaseEngine *engine,
                                        CCJobType *type,
                                        NSMutableArray *phases,
                                        NSMutableArray<CCKJob*> *jobs)
{
    switch(*type)
    {
        case CCJobTypeCompiler:
            [phases addObject:[CCKPhase phaseWithJobs:[jobs copy] withJobType:CCJobTypeCompiler withMultithreadingSupport:YES]];
            break;
        case CCJobTypeSwiftCompiler:
        case CCJobTypeLinker:
            [phases addObject:[CCKPhase phaseWithJobs:[jobs copy] withJobType:*type withMultithreadingSupport:NO]];
            /* fallthrough */
        default:
            break;
    }
    
    /* resetting generation flags and arrays to sentinel */
    [jobs removeAllObjects];
    *type = CCJobTypeUnknown;
}

static void CCKPhaseGenerationAppendHelper(CCKPhaseEngine *engine,
                                           CCJobType *type,
                                           NSMutableArray *phases,
                                           NSMutableArray<CCKJob*> *jobs,
                                           CCKJob *job)
{
    switch(job.type)
    {
        case CCJobTypeCompiler:
            if(*type == CCJobTypeUnknown)
            {
            switch_to_compiler_job:
                *type = CCJobTypeCompiler;
                [jobs addObject:job];
            }
            else if(*type == CCJobTypeCompiler)
            {
                [jobs addObject:job];
            }
            else
            {
                CCKPhaseGenerationEndHelper(engine, type, phases, jobs);
                goto switch_to_compiler_job;
            }
            break;
        case CCJobTypeDriver:
        {
            CCKPhaseGenerationEndHelper(engine, type, phases, jobs);
            
            CCKPhaseEngine *subPhaseEngine = [CCKPhaseEngine engineWithClangFlags:[job.arguments arrayByAddingObjectsFromArray:engine.otherClangFlags] withOtherLinkerFlags:engine.otherLinkerFlags];
            subPhaseEngine.delegate = engine.delegate;
            [phases addObject:subPhaseEngine];
            
            CCKPhaseGenerationEndHelper(engine, type, phases, jobs);
            
            break;
        }
        case CCJobTypeSwiftCompiler:
            if(*type == CCJobTypeUnknown)
            {
            switch_to_swift_compiler_job:
                *type = CCJobTypeSwiftCompiler;
                [jobs addObject:job];
            }
            else if(*type == CCJobTypeSwiftCompiler)
            {
                [jobs addObject:job];
            }
            else
            {
                CCKPhaseGenerationEndHelper(engine, type, phases, jobs);
                goto switch_to_swift_compiler_job;
            }
            break;
        case CCJobTypeSwiftDriver:
            break;
        case CCJobTypeLinker:
            if(*type == CCJobTypeUnknown)
            {
            switch_to_linker_job:
                *type = CCJobTypeLinker;
                [jobs addObject:CCKPhaseGenerationJobByAppendingArgumentsHelper(job, engine.otherLinkerFlags)];
            }
            else if(*type == CCJobTypeLinker)
            {
                [jobs addObject:CCKPhaseGenerationJobByAppendingArgumentsHelper(job, engine.otherLinkerFlags)];
            }
            else
            {
                CCKPhaseGenerationEndHelper(engine, type, phases, jobs);
                goto switch_to_linker_job;
            }
            break;
        default:
            break;
    }
}

@implementation CCKPhaseEngine {
    CCKDriver *_driver;
}

@dynamic delegate;

+ (instancetype)engineWithDriver:(CCKDriver*)driver
             withOtherClangFlags:(NSArray<NSString*>*)clangFlags
            withOtherLinkerFlags:(NSArray<NSString*>*)linkerFlags
{
    return [[self alloc] initWithDriver:driver withOtherClangFlags:clangFlags withOtherLinkerFlags:linkerFlags];
}

+ (instancetype)engineWithClangFlags:(NSArray<NSString*>*)clangFlags
                withOtherLinkerFlags:(NSArray<NSString*>*)linkerFlags
{
    return [[self alloc] initWithClangFlags:clangFlags withOtherLinkerFlags:linkerFlags];
}

+ (instancetype)engineWithSwiftFlags:(NSArray<NSString*>*)swiftFlags
                 withOtherClangFlags:(NSArray<NSString*>*)clangFlags
                withOtherLinkerFlags:(NSArray<NSString*>*)linkerFlags
{
    return [[self alloc] initWithSwiftFlags:swiftFlags withOtherClangFlags:clangFlags withOtherLinkerFlags:linkerFlags];
}

- (instancetype)initWithDriver:(CCKDriver*)driver
           withOtherClangFlags:(NSArray<NSString*>*)clangFlags
          withOtherLinkerFlags:(NSArray<NSString*>*)linkerFlags
{
    self = [super init];
    if(self)
    {
        _otherClangFlags = clangFlags;
        _otherLinkerFlags = linkerFlags;
        _driver = driver;
    }
    return self;
}

- (instancetype)initWithClangFlags:(NSArray<NSString*>*)clangFlags
              withOtherLinkerFlags:(NSArray<NSString*>*)linkerFlags
{
    self = [super init];
    if(self)
    {
        _otherClangFlags = clangFlags;
        _otherLinkerFlags = linkerFlags;
        _driver = [CCKDriver driverWithArguments:clangFlags withType:CCDriverTypeClang];
    }
    return self;
}

- (instancetype)initWithSwiftFlags:(NSArray<NSString*>*)swiftFlags
               withOtherClangFlags:(NSArray<NSString*>*)clangFlags
              withOtherLinkerFlags:(NSArray<NSString*>*)linkerFlags
{
    self = [super init];
    if(self)
    {
        _otherClangFlags = clangFlags;
        _otherLinkerFlags = linkerFlags;
        _driver = [CCKDriver driverWithArguments:swiftFlags withType:CCDriverTypeSwift];
    }
    return self;
}

- (id<CCKDriverDelegate>)delegate
{
    return _driver.delegate;
}

- (void)setDelegate:(id<CCKDriverDelegate>)delegate
{
    _driver.delegate = delegate;
}

- (NSArray*)generatePhases
{
    NSMutableArray *phases = [NSMutableArray array];
    
    CCJobType currentPhasesType = CCJobTypeUnknown;
    NSMutableArray<CCKJob*> *currentPhasesJobs = [NSMutableArray array];
    
    NSArray<CCKJob*> *mainDriverJobs = [_driver generateJobs];
    if(mainDriverJobs == nil)
    {
        /* phase creation failed */
        return nil;
    }
    for(CCKJob *job in mainDriverJobs)
    {
        CCKPhaseGenerationAppendHelper(self, &currentPhasesType, phases, currentPhasesJobs, job);
    }
    CCKPhaseGenerationEndHelper(self, &currentPhasesType, phases, currentPhasesJobs);
    
    return phases;
}

@end
