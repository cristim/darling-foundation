//
//  NSDecimal.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSDecimal.h>
#import <Foundation/NSDecimalNumber.h>

#import <Foundation/NSException.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>

#import "NSDecimalCore.h"

// Hooks used by NSDecimalCore.m, which sends no Objective-C messages so that
// the arithmetic can be exercised off-target (see test/decimal).

void _NSDecimalAllocationFailure(void)
{
    [NSException raise:NSMallocException format:@"Could not allocate buffer"];
}

double _NSDecimalToDouble(const NSDecimal *dcm)
{
    return [[NSDecimalNumber decimalNumberWithDecimal:*dcm] doubleValue];
}

void _NSDecimalFromDouble(NSDecimal *result, double value)
{
    NSDecimalNumber *number = [[NSDecimalNumber alloc] initWithDouble:value];
    NSDecimal decimal = [number decimalValue];
    NSDecimalCopy(result, &decimal);
    [number release];
}

NSString *NSDecimalString(const NSDecimal *dcm, id locale)
{
    NSString *separator = [locale objectForKey:NSLocaleDecimalSeparator] ?: @".";

    char buffer[_NSDecimalFormatBufferSize];
    if (!_NSDecimalFormat(dcm, [separator UTF8String], buffer, sizeof(buffer)))
    {
        return nil;
    }

    return [NSString stringWithUTF8String:buffer];
}
