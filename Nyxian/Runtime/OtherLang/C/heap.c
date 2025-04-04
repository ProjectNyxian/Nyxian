/* picoc heap memory allocation. */

/* stack grows up from the bottom and heap grows down from
    the top of heap space */
#include "interpreter.h"

/* initialize the stack and heap storage */
void HeapInit(Picoc *pc, int StackOrHeapSize)
{
    int Count;
    int AlignOffset = 0;

    pc->HeapMemory = malloc(StackOrHeapSize);
    pc->HeapBottom = NULL;  /* the bottom of the (downward-growing) heap */
    pc->StackFrame = NULL;  /* the current stack frame */
    pc->HeapStackTop = NULL;  /* the top of the stack */

    while (((unsigned long)&pc->HeapMemory[AlignOffset] & (sizeof(ALIGN_TYPE)-1)) != 0)
        AlignOffset++;

    pc->StackFrame = &(pc->HeapMemory)[AlignOffset];
    pc->HeapStackTop = &(pc->HeapMemory)[AlignOffset];
    *(void**)(pc->StackFrame) = NULL;
    pc->HeapBottom =
        &(pc->HeapMemory)[StackOrHeapSize-sizeof(ALIGN_TYPE)+AlignOffset];
    pc->FreeListBig = NULL;
    for (Count = 0; Count < FREELIST_BUCKETS; Count++)
        pc->FreeListBucket[Count] = NULL;
}

void HeapCleanup(Picoc *pc)
{
    free(pc->HeapMemory);
}

/* allocate some space on the stack, in the current stack frame
 * clears memory. can return NULL if out of stack space */
void *HeapAllocStack(Picoc *pc, int Size)
{
    char *NewMem = pc->HeapStackTop;
    char *NewTop = (char*)pc->HeapStackTop + MEM_ALIGN(Size);
    if (NewTop > (char*)pc->HeapBottom)
        return NULL;

    pc->HeapStackTop = (void*)NewTop;
    memset((void*)NewMem, '\0', Size);
    return NewMem;
}

/* allocate some space on the stack, in the current stack frame */
void HeapUnpopStack(Picoc *pc, int Size)
{
    pc->HeapStackTop = (void*)((char*)pc->HeapStackTop + MEM_ALIGN(Size));
}

/* free some space at the top of the stack */
int HeapPopStack(Picoc *pc, void *Addr, int Size)
{
    int ToLose = MEM_ALIGN(Size);
    if (ToLose > ((char*)pc->HeapStackTop - (char*)&(pc->HeapMemory)[0]))
        return false;

    pc->HeapStackTop = (void*)((char*)pc->HeapStackTop - ToLose);
    assert(Addr == NULL || pc->HeapStackTop == Addr);

    return true;
}

/* push a new stack frame on to the stack */
void HeapPushStackFrame(Picoc *pc)
{
    *(void**)pc->HeapStackTop = pc->StackFrame;
    pc->StackFrame = pc->HeapStackTop;
    pc->HeapStackTop = (void*)((char*)pc->HeapStackTop +
        MEM_ALIGN(sizeof(ALIGN_TYPE)));
}

/* pop the current stack frame, freeing all memory in the
    frame. can return NULL */
int HeapPopStackFrame(Picoc *pc)
{
    if (*(void**)pc->StackFrame != NULL) {
        pc->HeapStackTop = pc->StackFrame;
        pc->StackFrame = *(void**)pc->StackFrame;
        return true;
    } else
        return false;
}

/* allocate some dynamically allocated memory. memory is cleared.
    can return NULL if out of memory */
void *HeapAllocMem(Picoc *pc, int Size)
{
    return calloc(Size, 1);
}

/* free some dynamically allocated memory */
void HeapFreeMem(Picoc *pc, void *Mem)
{
    free(Mem);
}

