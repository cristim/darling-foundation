#import <Foundation/Foundation.h>
#import <CoreFoundation/CFPropertyList.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

@interface NSBundle (LocalizedTable)
- (NSDictionary *)localizedStringsForTable:(NSString *)table localization:(NSString *)localization;
@end

static BOOL writeText(NSString *path, const char *contents) {
    FILE *file = fopen([path fileSystemRepresentation], "wb");
    if (!file) return NO;
    BOOL okay = fputs(contents, file) >= 0;
    return fclose(file) == 0 && okay;
}

int main(void) {
    @autoreleasepool {
        char directory[] = "/tmp/darling-loc-table-XXXXXX";
        if (!mkdtemp(directory)) return 2;
        NSString *bundlePath = [[NSString stringWithUTF8String:directory] stringByAppendingPathComponent:@"Fixture.bundle"];
        NSString *contentsPath = [bundlePath stringByAppendingPathComponent:@"Contents"];
        NSString *resourcesPath = [contentsPath stringByAppendingPathComponent:@"Resources"];
        NSString *englishPath = [resourcesPath stringByAppendingPathComponent:@"en.lproj"];
        NSString *germanPath = [resourcesPath stringByAppendingPathComponent:@"de.lproj"];
        for (NSString *path in @[bundlePath, contentsPath, resourcesPath, englishPath, germanPath]) {
            if (mkdir([path fileSystemRepresentation], 0700) != 0) return 2;
        }
        if (!writeText([contentsPath stringByAppendingPathComponent:@"Info.plist"],
                       "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>org.darling.loctable-probe</string></dict></plist>")) return 2;
        if (!writeText([englishPath stringByAppendingPathComponent:@"Legacy.strings"],
                       "\"HELLO\" = \"Hello\";")) return 2;
        if (!writeText([germanPath stringByAppendingPathComponent:@"Legacy.strings"],
                       "\"HELLO\" = \"Hallo\";")) return 2;

        NSDictionary *languages = @{@"en": @{@"HELLO": @"Welcome"},
                                    @"de": @{@"HELLO": @"Willkommen"}};
        CFDataRef plist = CFPropertyListCreateData(kCFAllocatorDefault, (CFPropertyListRef)languages,
                                                  kCFPropertyListBinaryFormat_v1_0, 0, NULL);
        BOOL wrote = [(NSData *)plist writeToFile:[resourcesPath stringByAppendingPathComponent:@"Modern.loctable"] atomically:NO];
        wrote &= [(NSData *)plist writeToFile:[resourcesPath stringByAppendingPathComponent:@"Legacy.loctable"] atomically:NO];
        CFRelease(plist);
        if (!wrote) return 2;

        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        BOOL passed = bundle != nil;
        passed &= [[[bundle localizedStringsForTable:@"Legacy" localization:@"en"] objectForKey:@"HELLO"] isEqualToString:@"Hello"];
        passed &= [[[bundle localizedStringsForTable:@"Legacy" localization:@"de"] objectForKey:@"HELLO"] isEqualToString:@"Hallo"];
        passed &= [[[bundle localizedStringsForTable:@"Modern" localization:@"en"] objectForKey:@"HELLO"] isEqualToString:@"Welcome"];
        passed &= [[[bundle localizedStringsForTable:@"Modern" localization:@"de"] objectForKey:@"HELLO"] isEqualToString:@"Willkommen"];
        passed &= [[[bundle localizedStringsForTable:@"Modern" localization:nil] objectForKey:@"HELLO"] isEqualToString:@"Welcome"];
        passed &= [[bundle localizedStringsForTable:@"Missing" localization:@"en"] count] == 0;
        passed &= [[bundle localizedStringsForTable:@"Modern" localization:@"fr"] count] == 0;
        passed &= [[bundle localizedStringsForTable:@"Legacy" localization:@"fr"] count] == 0;
        printf("bundle localized string tables: %s\n", passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
