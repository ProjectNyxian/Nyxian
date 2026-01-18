#include <sys/syslimits.h>

__BEGIN_DECLS

_Pragma("GCC visibility push(hidden)")

const char *_Nonnull libroot_dyn_get_root_prefix(void);
const char *_Nonnull libroot_dyn_get_jbroot_prefix(void);
const char *_Nonnull libroot_dyn_get_boot_uuid(void);
char *_Nullable libroot_dyn_rootfspath(const char *_Nullable path, char *_Nullable resolvedPath);
char *_Nullable libroot_dyn_jbrootpath(const char *_Nullable path, char *_Nullable resolvedPath);

_Pragma("GCC visibility pop")

__END_DECLS

#define __CONVERT_PATH_CSTRING(converter, path) ({ \
	static char outPath[PATH_MAX]; \
	converter(path, outPath); \
})

#define JBROOT_PATH_CSTRING(path) __CONVERT_PATH_CSTRING(libroot_dyn_jbrootpath, path)
#define ROOTFS_PATH_CSTRING(path) __CONVERT_PATH_CSTRING(libroot_dyn_rootfspath, path)

#if __has_attribute(overloadable)
__attribute__((__overloadable__))
static inline const char *_Nullable __libroot_convert_path(char *_Nullable (*_Nonnull converter)(const char *_Nonnull, char *_Nullable), const char *_Nullable path, char *_Nonnull buf) {
	return converter(path, buf);
}
#endif /* __has_attribute(overloadable) */

#ifdef __OBJC__

#import <Foundation/Foundation.h>

#define __CONVERT_PATH_NSSTRING(converter, path) ({ \
	char tmpBuf[PATH_MAX]; \
	const char *converted = converter(path.fileSystemRepresentation, tmpBuf); \
	converted ? [NSString stringWithUTF8String:converted] : nil; \
})

#define JBROOT_PATH_NSSTRING(path) __CONVERT_PATH_NSSTRING(libroot_dyn_jbrootpath, path)
#define ROOTFS_PATH_NSSTRING(path) __CONVERT_PATH_NSSTRING(libroot_dyn_rootfspath, path)

#if __has_attribute(overloadable)
__attribute__((__overloadable__))
static inline NSString *_Nullable __libroot_convert_path(char *_Nullable (*_Nonnull converter)(const char *_Nonnull, char *_Nullable), NSString *_Nullable path, void *_Nullable const __unused buf) {
	return __CONVERT_PATH_NSSTRING(converter, path);
}
#endif /* __has_attribute(overloadable) */

#endif /* __OBJC__ */

#if __has_attribute(overloadable)

#define __BUFFER_FOR_CHAR_P(x) \
	__builtin_choose_expr(										\
		__builtin_types_compatible_p(__typeof__(*(x)), char),	\
		({ static char buf[PATH_MAX]; buf; }),					\
		NULL													\
	)

#	define JBROOT_PATH(path) __libroot_convert_path(libroot_dyn_jbrootpath, (path), __BUFFER_FOR_CHAR_P(path))
#	define ROOTFS_PATH(path) __libroot_convert_path(libroot_dyn_rootfspath, (path), __BUFFER_FOR_CHAR_P(path))
#else
#	define JBROOT_PATH(path) _Pragma("GCC error \"JBROOT_PATH is not supported with this compiler, use JBROOT_PATH_CSTRING or JBROOT_PATH_NSSTRING\"") path
#	define ROOTFS_PATH(path) _Pragma("GCC error \"ROOTFS_PATH is not supported with this compiler, use ROOTFS_PATH_CSTRING or ROOTFS_PATH_NSSTRING\"") path
#endif /* __has_attribute(overloadable) */

#define JBRAND libroot_dyn_get_boot_uuid()
