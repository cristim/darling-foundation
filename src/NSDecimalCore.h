//
//  NSDecimalCore.h
//  Foundation
//
//  Internal interface between the plain-C decimal arithmetic in
//  NSDecimalCore.m and the Foundation-facing wrappers in NSDecimal.m.
//

#ifndef _NSDECIMALCORE_H_
#define _NSDECIMALCORE_H_

#import <Foundation/NSDecimal.h>
#include <stddef.h>

// 38 significant digits, a sign, a separator and a NUL, rounded up.
#define _NSDecimalFormatBufferSize 256

// Implemented in NSDecimal.m; called from NSDecimalCore.m.
extern void _NSDecimalAllocationFailure(void);
extern double _NSDecimalToDouble(const NSDecimal *dcm);
extern void _NSDecimalFromDouble(NSDecimal *result, double value);

// Implemented in NSDecimalCore.m.
extern BOOL _NSDecimalFormat(const NSDecimal *dcm, const char *separator, char *out, size_t outSize);

#endif
