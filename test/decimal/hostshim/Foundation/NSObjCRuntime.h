//
//  NSObjCRuntime.h (host-test shim)
//
//  test/decimal builds src/NSDecimalCore.m on the build host in Objective-C
//  mode, with no Objective-C runtime and no Foundation.  NSDecimal.h needs exactly the
//  declarations below; supplying them here keeps the real NSDecimal.h -- and
//  therefore the real NSDecimal layout -- under test.
//

#ifndef _NSOBJCRUNTIME_HOSTSHIM_H_
#define _NSOBJCRUNTIME_HOSTSHIM_H_

#include <stddef.h>
#include <stdint.h>

typedef signed char BOOL;
#ifndef YES
#define YES ((BOOL)1)
#define NO  ((BOOL)0)
#endif

typedef long NSInteger;
typedef unsigned long NSUInteger;

typedef enum NSComparisonResult {
    NSOrderedAscending = -1L,
    NSOrderedSame,
    NSOrderedDescending
} NSComparisonResult;

#define NS_ENUM(type, name) type name; enum
#define FOUNDATION_EXPORT extern
#define NS_INLINE static inline

@class NSString;
@class NSDictionary;

#endif
