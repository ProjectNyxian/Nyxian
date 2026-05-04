/*
 * MIT License
 *
 * Copyright (c) 2024 light-tech
 * Copyright (c) 2026 Kyle-Ye
 * Copyright (c) 2026 cr4zyengineer
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

#include <CoreCompiler/CCSwiftCompiler.h>
#include <CoreCompiler/CCDiagnostic.h>
#include <CoreCompiler/CCFile.h>
#include <CoreCompiler/CCUtils.h>
#include <CoreCompiler/CCUtilsPrivate.h>
#include <swift/FrontendTool/FrontendTool.h>
#include <swift/Frontend/Frontend.h>
#include <swift/Frontend/PrintingDiagnosticConsumer.h>
#include <swift/Basic/InitializeSwiftModules.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/Path.h>
#include <llvm/Support/ErrorHandling.h>
#include <fcntl.h>
#include <mutex>
#include <unistd.h>

struct CapturedDiag {
    swift::DiagID id;
    swift::DiagnosticKind kind;
    std::string message;
    std::string file;
    unsigned line = 0, column = 0;
    /* add ranges / fixits / category / educationalNotes if you need them */
};

class CapturingConsumer : public swift::DiagnosticConsumer {
public:
    std::vector<CapturedDiag> diags;

    void handleDiagnostic(swift::SourceManager &SM,
                          const swift::DiagnosticInfo &Info) override
    {
        CapturedDiag d;
        d.id = Info.ID;
        d.kind = Info.Kind;

        /* render FormatString + FormatArgs into a real string. */
        llvm::SmallString<256> buf;
        {
            llvm::raw_svector_ostream os(buf);
            swift::DiagnosticEngine::formatDiagnosticText(os, Info.FormatString, Info.FormatArgs);
        }
        d.message = std::string(buf);

        if(Info.Loc.isValid())
        {
            auto lc = SM.getPresumedLineAndColumnForLoc(Info.Loc);
            d.line = lc.first;
            d.column = lc.second;
            d.file = SM.getDisplayNameForLoc(Info.Loc).str();
        }
        diags.push_back(std::move(d));
    }
};

class MyObserver : public swift::FrontendObserver {
public:
    CapturingConsumer consumer;
    void configuredCompiler(swift::CompilerInstance &CI) override
    {
        CI.addDiagnosticConsumer(&consumer);
    }
};

static std::once_flag SwiftModulesInitOnce;

static CFStringRef CCStringCreateWithFileDescriptor(CFAllocatorRef allocator, int fd)
{
    if(fd < 0)
    {
        return CFSTR("");
    }

    lseek(fd, 0, SEEK_SET);

    CFMutableDataRef data = CFDataCreateMutable(allocator, 0);
    if(data == nullptr)
    {
        return CFSTR("");
    }

    char buffer[4096];
    ssize_t count = 0;
    while((count = read(fd, buffer, sizeof(buffer))) > 0)
    {
        CFDataAppendBytes(data, reinterpret_cast<const UInt8 *>(buffer), count);
    }

    CFStringRef string = CFStringCreateFromExternalRepresentation(allocator, data, kCFStringEncodingUTF8);
    CFRelease(data);

    if(string == nullptr)
    {
        return CFSTR("");
    }

    return string;
}

CC_EXPORT Boolean CCSwiftCompilerJobExecute(CCJobRef job,
                                            CFArrayRef *outDiagnostics)
{
    assert(job != nullptr);
    assert(CCJobGetType(job) == CCJobTypeSwiftCompiler);

    CFArrayRef argsArray = CCJobGetArguments(job);

    llvm::SmallVector<std::string, 64> argStorage = CCArrayToStringVector(argsArray);
    llvm::SmallVector<const char *, 64> args = StringVectorToCStrings(argStorage);
    
    /* get_-frontend_out_of_my_way type shii */
    if(!args.empty() && std::strcmp(args.front(), "-frontend") == 0)
    {
        args.erase(args.begin());
    }
    
    std::call_once(SwiftModulesInitOnce, [] {
        initializeSwiftModules();
    });

    MyObserver obs;
    llvm::remove_fatal_error_handler();
    int status = swift::performFrontend(args, "swift-frontend", nullptr, &obs);
    CCInstallLLVMFatalErrorHandler();

    if(outDiagnostics == nullptr)
    {
        goto out_status;
    }

    *outDiagnostics = CFArrayCreateMutable(kCFAllocatorSystemDefault, obs.consumer.diags.size(), &kCFTypeArrayCallBacks);
    if(*outDiagnostics == nullptr)
    {
        goto out_status;
    }

    for(auto &d : obs.consumer.diags)
    {
        CCDiagnosticLevel level = CCDiagnosticLevelUnknown;

        switch(d.kind)
        {
            case swift::DiagnosticKind::Error:
                level = CCDiagnosticLevelError;
                break;
            case swift::DiagnosticKind::Warning:
                level = CCDiagnosticLevelWarning;
                break;
            case swift::DiagnosticKind::Remark:
                level = CCDiagnosticLevelRemark;
                break;
            case swift::DiagnosticKind::Note:
                level = CCDiagnosticLevelNote;
                break;
            default:
                break;
        }

        if(level == CCDiagnosticLevelUnknown)
        {
            continue;
        }

        CFStringRef messageStr = CFStringCreateWithCString(kCFAllocatorSystemDefault, d.message.c_str(), kCFStringEncodingUTF8);
        if(messageStr == nullptr)
        {
            continue;
        }

        CCFileRef file = CCFileCreateWithCString(kCFAllocatorSystemDefault, d.file.c_str(), kCFStringEncodingUTF8);
        if(file == nullptr)
        {
            CFRelease(messageStr);
            continue;
        }

        CFURLRef fileURL = CCFileGetFileURL(file);
        CCFileSourceLocationRef fileSourceLocation = CCFileSourceLocationCreate(kCFAllocatorSystemDefault, fileURL, CCSourceLocationMake(d.line, d.column));
        CFRelease(file);

        if(fileSourceLocation == nullptr)
        {
            CFRelease(messageStr);
            continue;
        }

        /* TODO: support internal diagnostic's aswell */
        CCDiagnosticRef diagnostic = CCDiagnosticCreate(kCFAllocatorSystemDefault, CCDiagnosticTypeFile, level, fileSourceLocation, messageStr);
        CFRelease(messageStr);
        CFRelease(fileSourceLocation);
        if(diagnostic == nullptr)
        {
            continue;
        }

        CFArrayAppendValue((CFMutableArrayRef)*outDiagnostics, diagnostic);
        CFRelease(diagnostic);
    }

out_status:
    return status == 0;
}
