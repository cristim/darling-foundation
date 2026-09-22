//
//  hoststubs.m (host-test shim)
//
//  NSDecimalCore.m calls three functions that NSDecimal.m implements in terms
//  of Foundation.  The host test supplies them here.
//
//  _NSDecimalToDouble and _NSDecimalFromDouble exist only because
//  NSDecimalDivide currently routes non-power-of-ten division through
//  NSDecimalNumber and double.  They are transcribed line for line from
//  src/NSDecimalNumber.m so that the host test observes exactly the behaviour
//  the shipped code has -- the divide cases must fail here for the reason they
//  fail on target, not because the harness approximated something.  When
//  NSDecimalDivide stops going through double, all three go away.
//

#import <Foundation/NSDecimal.h>
#import "../../../src/NSDecimalCore.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <limits.h>

void _NSDecimalAllocationFailure(void)
{
    fprintf(stderr, "decimal test: allocation failure\n");
    abort();
}

// -[NSDecimalNumber doubleValue], src/NSDecimalNumber.m:211
double _NSDecimalToDouble(const NSDecimal *dcm)
{
    if (NSDecimalIsNotANumber(dcm))
    {
        return NAN;
    }

    double result = 0.0;
    if (!dcm->_length)
    {
        return dcm->_isNegative ? -result : result;
    }

    for (int length = dcm->_length; length > 0; length--)
    {
        result *= (double)USHRT_MAX + 1.0;
        result += (double)(dcm->_mantissa[length - 1]);
    }

    if (dcm->_exponent != 0)
    {
        int exponent = dcm->_exponent;
        if (dcm->_exponent < 0)
        {
            for (; exponent < 0; exponent++)
            {
                result /= 10.0;
            }
        }
        else
        {
            for (int negated = -exponent; negated < 0; negated++)
            {
                result *= 10.0;
            }
        }
    }

    return dcm->_isNegative ? -result : result;
}

// -[NSDecimalNumber initWithMantissa:exponent:isNegative:], src/NSDecimalNumber.m:618,
// followed by -initWithDecimal:, which compacts.
static void fromMantissa(NSDecimal *out, unsigned long long mantissa, short exponent, BOOL negative)
{
    memset(out, 0, sizeof(*out));
    out->_exponent = exponent;
    out->_isNegative = negative ? 1 : 0;
    memcpy(&(out->_mantissa), &mantissa, sizeof(unsigned long long));
    for (int i = NSDecimalMaxSize - 1; i >= 0; i--)
    {
        if (out->_mantissa[i] != 0)
        {
            out->_length = i + 1;
            break;
        }
    }
    NSDecimalCompact(out);
}

// -[NSDecimalNumber initWithDouble:], src/NSDecimalNumber.m:708
void _NSDecimalFromDouble(NSDecimal *result, double value)
{
    if (isnan(value))
    {
        fromMantissa(result, 0x0, 0x0, YES);
        return;
    }

    double magnitude = fabs(value);
    if (magnitude < 1.0e-110 || magnitude == ULLONG_MAX)
    {
        fromMantissa(result, 0x0, 0x0, NO);
        return;
    }
    if (magnitude > 1.8e146)
    {
        fromMantissa(result, ULLONG_MAX, 0x7f, value < 0 ? YES : NO);
        return;
    }

    int exponent = 0;
    for (; magnitude < 1.8446744073709551616e19; exponent--) // 2^64
    {
        magnitude *= 10.0;
    }
    for (; magnitude > 1.8446744073709551616e19; exponent++)
    {
        magnitude /= 10.0;
    }

    fromMantissa(result, (unsigned long long)magnitude, exponent, value < 0.0);
}
