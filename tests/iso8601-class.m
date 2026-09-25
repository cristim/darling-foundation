#import <Foundation/Foundation.h>

static int verifyFormat(NSString *actual, NSString *expected) {
    if ([actual isEqualToString:expected]) return 0;
    NSLog(@"expected %@, got %@", expected, actual);
    return 1;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSDate *epoch = [NSDate dateWithTimeIntervalSince1970:0];
    NSTimeZone *utc = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSTimeZone *plusTwo = [NSTimeZone timeZoneForSecondsFromGMT:7200];
    NSUInteger standard = NSISO8601DateFormatWithInternetDateTime;
    int failures = 0;
    failures += verifyFormat([NSISO8601DateFormatter stringFromDate:epoch timeZone:utc formatOptions:standard], @"1970-01-01T00:00:00Z");
    failures += verifyFormat([NSISO8601DateFormatter stringFromDate:epoch timeZone:plusTwo formatOptions:standard], @"1970-01-01T02:00:00+02:00");
    failures += verifyFormat([NSISO8601DateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:0.25] timeZone:utc formatOptions:standard | NSISO8601DateFormatWithFractionalSeconds], @"1970-01-01T00:00:00.250Z");
    NSLog(@"ISO8601 class checks=%d failures=%d", 3, failures);
    [pool drain];
    return failures ? 1 : 0;
}
