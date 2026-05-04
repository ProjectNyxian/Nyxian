//
//  CoreCompiler.h
//  CoreCompiler
//
//  Created by Frida on 01.05.26.
//

#import <Foundation/Foundation.h>

//! Project version number for CoreCompiler.
FOUNDATION_EXPORT double CoreCompilerVersionNumber;

//! Project version string for CoreCompiler.
FOUNDATION_EXPORT const unsigned char CoreCompilerVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <CoreCompiler/PublicHeader.h>
#include <CoreCompiler/CCBase.h>
#include <CoreCompiler/CCSourceLocation.h>
#include <CoreCompiler/CCFile.h>
#include <CoreCompiler/CCFileSourceLocation.h>
#include <CoreCompiler/CCDiagnostic.h>
#include <CoreCompiler/CCJob.h>
#include <CoreCompiler/CCDriver.h>
#include <CoreCompiler/CCSDK.h>
#include <CoreCompiler/CCASTUnit.h>
#include <CoreCompiler/CCDependencyScanner.h>
#include <CoreCompiler/CCCompiler.h>
#include <CoreCompiler/CCSwiftCompiler.h>
#include <CoreCompiler/CCLinker.h>
#include <CoreCompiler/CCUtils.h>

#ifdef __OBJC__
#import <CoreCompiler/CCKFile.h>
#import <CoreCompiler/CCKFileSourceLocation.h>
#import <CoreCompiler/CCKDiagnostic.h>
#import <CoreCompiler/CCKJob.h>
#import <CoreCompiler/CCKDriver.h>
#import <CoreCompiler/CCKSDK.h>
#import <CoreCompiler/CCKASTUnit.h>
#import <CoreCompiler/CCKDependencyScanner.h>
#import <CoreCompiler/CCKCompiler.h>
#import <CoreCompiler/CCKLinker.h>
#import <CoreCompiler/CCKSwiftCompiler.h>
#import <CoreCompiler/CCKProgramCompiler.h>
#import <CoreCompiler/CCKPhase.h>
#import <CoreCompiler/CCKPhaseEngine.h>
#import <CoreCompiler/CCKThreadPool.h>
#import <CoreCompiler/CCKThreadPoolGroup.h>
#endif /* __OBJC__ */
