/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSISO8601DateFormatter.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSString.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>

static NSString *ISO8601Pattern(NSISO8601DateFormatOptions options) {
    BOOL dash = (options & NSISO8601DateFormatWithDashSeparatorInDate) != 0;
    BOOL colon = (options & NSISO8601DateFormatWithColonSeparatorInTime) != 0;
    BOOL zoneColon = (options & NSISO8601DateFormatWithColonSeparatorInTimeZone) != 0;
    NSMutableString *pattern = [NSMutableString string];

    if (options & NSISO8601DateFormatWithYear)
        [pattern appendString:(options & NSISO8601DateFormatWithWeekOfYear) ? @"YYYY" : @"yyyy"];
    if (options & NSISO8601DateFormatWithMonth) {
        if ([pattern length] && dash) [pattern appendString:@"-"];
        [pattern appendString:@"MM"];
    }
    if (options & NSISO8601DateFormatWithWeekOfYear) {
        if ([pattern length] && dash) [pattern appendString:@"-"];
        [pattern appendString:@"'W'ww"];
    }
    if (options & NSISO8601DateFormatWithDay) {
        if ([pattern length] && dash) [pattern appendString:@"-"];
        [pattern appendString:(options & NSISO8601DateFormatWithWeekOfYear) ? @"ee" :
                              (options & NSISO8601DateFormatWithMonth) ? @"dd" : @"DDD"];
    }
    if (options & NSISO8601DateFormatWithTime) {
        if ([pattern length]) [pattern appendString:(options & NSISO8601DateFormatWithSpaceBetweenDateAndTime) ? @" " : @"'T'"];
        [pattern appendString:colon ? @"HH:mm:ss" : @"HHmmss"];
        if (options & NSISO8601DateFormatWithFractionalSeconds) [pattern appendString:@".SSS"];
    }
    if (options & NSISO8601DateFormatWithTimeZone)
        [pattern appendString:zoneColon ? @"XXXXX" : @"XXXX"];
    return pattern;
}

@implementation NSISO8601DateFormatter

+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)options {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:locale];
    [locale release];
    [formatter setTimeZone:timeZone ?: [NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setDateFormat:ISO8601Pattern(options)];
    NSString *result = [[formatter stringFromDate:date] retain];
    [formatter release];
    return [result autorelease];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	NSLog(@"[NSISO8601DateFormatter initWithCoder:]");
	return [self init];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	NSLog(@"[NSISO8601DateFormatter encodeWithCoder:");
}

- (BOOL)supportsSecureCoding
{
	return YES;
}

@end
