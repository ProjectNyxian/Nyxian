#include <stdio.h>
#include <stdbool.h>
#include <mach/mach.h>
#include <mach-o/loader.h>

#ifdef __arm64__
typedef struct mach_header_64 mach_header_u;
typedef struct segment_command_64 segment_command_u;
typedef struct section_64 section_u;
typedef struct nlist_64 nlist_u;
#define LC_SEGMENT_U LC_SEGMENT_64
#else
typedef struct mach_header mach_header_u;
typedef struct segment_command segment_command_u;
typedef struct section section_u;
typedef struct nlist nlist_u;
#define LC_SEGMENT_U LC_SEGMENT
#endif

const char *litehook_locate_dsc(void);

void *litehook_find_symbol(const mach_header_u *header, const char *symbolName);
void *litehook_find_symbol_file(const mach_header_u *header, const char *symbolName);
void *litehook_find_dsc_symbol(const char *imagePath, const char *symbolName);
kern_return_t litehook_hook_function(void *source, void *target);

#define LITEHOOK_REBIND_GLOBAL NULL
void litehook_rebind_symbol(const mach_header_u *targetHeader, void *replacee, void *replacement, bool (*exceptionFilter)(const mach_header_u *header));

bool os_tpro_is_supported(void);
void os_thread_self_restrict_tpro_to_rw(void);
void os_thread_self_restrict_tpro_to_ro(void);

typedef struct {
    const mach_header_u *sourceHeader;
    void *replacee;
    void *replacement;
    bool (*exceptionFilter)(const mach_header_u *header);
} global_rebind;

extern uint32_t gRebindCount;
extern global_rebind *gRebinds;

#define DEFINE_HOOK(func, return_type, signature) \
    static return_type (*orig_##func) signature __attribute__((unused)) = \
        (return_type (*) signature)func; \
    static return_type hook_##func signature

#define DO_HOOK(func, type) \
    litehook_rebind_symbol(type, func, hook_##func, nil)

#define DO_HOOK_GLOBAL(func) \
    DO_HOOK(func,LITEHOOK_REBIND_GLOBAL)
/*    orig_##func = func; \
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, func, hook_##func, nil);*/

#define ORIG_FUNC(func) \
    orig_##func

#define HOOK_FUNC(func) \
    hook_##func
