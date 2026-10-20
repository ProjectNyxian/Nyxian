/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#import <LindChain/IDEBuilder/NXPhaseRunner.h>
#import <UI/XCodeButton.h>

@interface NXPhaseRunner(Private)

@property (atomic) CFIndex steps;
@property (atomic) CFIndex donestep;

@end

@implementation NXPhaseRunner {
    double _progressStep;
    CFIndex _steps;
    CFIndex _donestep;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _progressStep = 0.0;
        _steps = 0;
        _donestep = 0;
    }
    return self;
}

- (CFIndex)steps
{
    return _steps;
}

- (void)setSteps:(CFIndex)steps
{
    _steps = steps;
    _progressStep = 1.0 / (double)_steps;
    [self refreshDoneStep];
}

- (CFIndex)donestep
{
    return _donestep;
}

- (void)setDonestep:(CFIndex)donestep
{
    _donestep = donestep;
    [self refreshDoneStep];
}

- (void)refreshDoneStep
{
    double progress = _progressStep * (double)_donestep;
    [XCButton updateProgressWithValue:progress];
}

- (BOOL)runJob:(MDKJob *)job withinPhase:(MDKPhase *)phase
{
    BOOL success = [super runJob:job withinPhase:phase];
    self.donestep += 1;
    return success;
}

- (BOOL)runPhase:(MDKPhase *)phase
{
    switch(phase.type)
    {
        case MDKJobTypeCompiler:
        case MDKJobTypeSwiftCompiler:
            [XCButton switchImageSyncWithSystemName:@"hammer.fill" animated:YES];
            break;
        case MDKJobTypeLinker:
            [XCButton switchImageSyncWithSystemName:@"link" animated:YES];
            [[fallthrough]];
        default:
            break;
    }
    return [super runPhase:phase];
}

- (BOOL)runPhasesWithPhases:(NSArray *)phases
{
    for(MDKPhase *phase in phases)
    {
        if([phase isKindOfClass:[MDKPhase class]])
        {
            self.steps += phase.jobs.count;
        }
    }
    return [super runPhasesWithPhases:phases];
}

@end
