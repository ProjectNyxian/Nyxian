#include "../interpreter.h"
#include <fcntl.h>

static const int O_RDONLYValue = O_RDONLY;
static const int O_WRONLYValue = O_WRONLY;
static const int O_RDWRValue = O_RDWR;
static const int O_CREATValue = O_CREAT;
static const int O_EXCLValue = O_EXCL;
static const int O_NOCTTYValue = O_NOCTTY;
static const int O_TRUNCValue = O_TRUNC;
static const int O_APPENDValue = O_APPEND;
static const int O_NONBLOCKValue = O_NONBLOCK;
static const int O_SYNCValue = O_SYNC;
static const int O_DSYNCValue = O_DSYNC;
static const int O_CLOEXECValue = O_CLOEXEC;

void StdFcntl(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = fcntl(Param[0]->Val->Integer,
        Param[1]->Val->Integer, Param[2]->Val->Pointer);
}

void StdOpen(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = open(Param[0]->Val->Pointer,
        Param[1]->Val->Integer, Param[2]->Val->Integer);
}

void StdClose(struct ParseState *Parser, struct Value *ReturnValue,
    struct Value **Param, int NumArgs)
{
    ReturnValue->Val->Integer = close(Param[0]->Val->Integer);
}

const char StdFcntlDefs[] = "\
//typedef int mode_t;     // ALREADY DEFINED \
//typedef int off_t; \
";

struct LibraryFunction StdFcntlFunctions[] =
{
    {StdFcntl, "int fcntl(int, int, void *);"},
    {StdOpen, "int open(char *, int, int);"},
    {StdClose, "int close(int);"},
    {NULL, NULL}
};

void StdFcntlSetupFunc(Picoc *pc)
{
    VariableDefinePlatformVar(pc, NULL, "O_RDONLY", &pc->IntType,
        (union AnyValue*)&O_RDONLYValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_WRONLY", &pc->IntType,
        (union AnyValue*)&O_WRONLYValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_RDWR", &pc->IntType,
        (union AnyValue*)&O_RDWRValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_CREAT", &pc->IntType,
        (union AnyValue*)&O_CREATValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_EXCL", &pc->IntType,
        (union AnyValue*)&O_EXCLValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_NOCTTY", &pc->IntType,
        (union AnyValue*)&O_NOCTTYValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_TRUNC", &pc->IntType,
        (union AnyValue*)&O_TRUNCValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_APPEND", &pc->IntType,
        (union AnyValue*)&O_APPENDValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_NONBLOCK", &pc->IntType,
        (union AnyValue*)&O_NONBLOCKValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_SYNC", &pc->IntType,
        (union AnyValue*)&O_SYNCValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_DSYNC", &pc->IntType,
        (union AnyValue*)&O_DSYNCValue, false);
    VariableDefinePlatformVar(pc, NULL, "O_CLOEXEC", &pc->IntType,
        (union AnyValue*)&O_CLOEXECValue, false);
}
