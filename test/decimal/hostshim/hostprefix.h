//
//  hostprefix.h (host-test shim)
//
//  The real build force-includes CoreFoundation's CoreFoundation_Prefix.h and
//  macros.h (see the top-level CMakeLists.txt).  NSDecimalCore.m uses three
//  things from them; this supplies those three and nothing else.
//

#ifndef _NSDECIMAL_HOSTPREFIX_H_
#define _NSDECIMAL_HOSTPREFIX_H_

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

// src/external/corefoundation/macros.h:3.  Kept identical: a trap must stay a
// trap, so that a DEBUG_BREAK reached during a test is reported as one.
#ifndef DEBUG_BREAK
#define DEBUG_BREAK() __builtin_trap()
#endif

#endif
