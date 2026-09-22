//
//  test-decimal.c
//
//  Drives src/NSDecimalCore.m against decimal-fixture.txt, whose expected
//  values come from Python's decimal module (see generate-fixture.py) and
//  never from Foundation.  This is a host test: the decimal core sends no
//  Objective-C messages, so it runs in CI without a Darling container.
//
//  decimal-known-failures.txt lists the cases that are expected to fail today.
//  A listed case that fails is reported but does not fail the run; a listed
//  case that PASSES does fail it, so the list cannot rot.
//
//  Every case runs in a forked child under an alarm, because the code under
//  test contains DEBUG_BREAK() traps and can fail to terminate.  A trap, a
//  segfault and a hang are results, not reasons to lose the rest of the run.
//

#import <Foundation/NSDecimal.h>
#import "../../src/NSDecimalCore.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

#define CASE_TIMEOUT_SECONDS 5
#define MAX_LINE 1024
#define RESULT_SIZE 512

// The four NSRoundingMode values, in header order.
static const NSRoundingMode kRoundingModes[] = { NSRoundPlain, NSRoundDown, NSRoundUp, NSRoundBankers };

typedef enum { OUTCOME_PASS, OUTCOME_WRONG, OUTCOME_SIGNAL, OUTCOME_TIMEOUT } Outcome;

#define MAX_KNOWN_FAILURES 256
static char knownFailures[MAX_KNOWN_FAILURES][128];
static int knownFailureCount = 0;
static BOOL knownFailureSeen[MAX_KNOWN_FAILURES];

static void loadKnownFailures(const char *path)
{
    FILE *file = fopen(path, "r");
    if (file == NULL) return;   // absent list means nothing is excused
    char line[256];
    while (fgets(line, sizeof(line), file) != NULL && knownFailureCount < MAX_KNOWN_FAILURES)
    {
        line[strcspn(line, "\n")] = '\0';
        if (line[0] == '#' || line[0] == '\0') continue;
        snprintf(knownFailures[knownFailureCount++], 128, "%s", line);
    }
    fclose(file);
}

static int knownFailureIndex(const char *op, const char *name)
{
    char key[128];
    snprintf(key, sizeof(key), "%s|%s", op, name);
    for (int i = 0; i < knownFailureCount; i++)
    {
        if (strcmp(knownFailures[i], key) == 0) return i;
    }
    return -1;
}

// ---------------------------------------------------------------- decoding --

// "sign,exponent,limbcount,limb,limb,..." -> NSDecimal
static BOOL decodeDecimal(const char *text, NSDecimal *out)
{
    memset(out, 0, sizeof(*out));
    char buffer[MAX_LINE];
    strncpy(buffer, text, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';

    char *save = NULL;
    char *field = strtok_r(buffer, ",", &save);
    if (field == NULL) return NO;
    out->_isNegative = (unsigned)atoi(field);

    field = strtok_r(NULL, ",", &save);
    if (field == NULL) return NO;
    out->_exponent = atoi(field);

    field = strtok_r(NULL, ",", &save);
    if (field == NULL) return NO;
    int count = atoi(field);
    if (count < 0 || count > NSDecimalMaxSize) return NO;
    out->_length = (unsigned)count;

    for (int i = 0; i < count; i++)
    {
        field = strtok_r(NULL, ",", &save);
        if (field == NULL) return NO;
        out->_mantissa[i] = (unsigned short)strtoul(field, NULL, 10);
    }
    // Operands are handed over already compact; say so, as the arithmetic
    // functions document that they take compact inputs.
    out->_isCompact = 1;
    return YES;
}

static void encodeDecimal(const NSDecimal *value, char *out, size_t outSize)
{
    if (value->_length == 0)
    {
        // Zero and NaN have no mantissa; the exponent carries no meaning.
        snprintf(out, outSize, value->_isNegative ? "NaN" : "0,0,0");
        return;
    }
    int written = snprintf(out, outSize, "%u,%d,%u", value->_isNegative, value->_exponent, value->_length);
    for (unsigned i = 0; i < value->_length && written > 0 && (size_t)written < outSize; i++)
    {
        written += snprintf(out + written, outSize - written, ",%u", value->_mantissa[i]);
    }
}

// ------------------------------------------------------------- case bodies --

// Runs one case and writes its observed result as text.  Called in the child.
static void runCase(const char *op, char **args, char *out, size_t outSize)
{
    NSDecimal lhs, rhs, result;
    memset(&result, 0, sizeof(result));

    if (strcmp(op, "string") == 0)
    {
        if (!decodeDecimal(args[0], &lhs)) { snprintf(out, outSize, "<bad fixture>"); return; }
        char formatted[_NSDecimalFormatBufferSize];
        if (!_NSDecimalFormat(&lhs, ".", formatted, sizeof(formatted)))
        {
            snprintf(out, outSize, "<format failed>");
            return;
        }
        snprintf(out, outSize, "%s", formatted);
        return;
    }

    if (strcmp(op, "round") == 0)
    {
        if (!decodeDecimal(args[0], &lhs)) { snprintf(out, outSize, "<bad fixture>"); return; }
        NSInteger scale = atoi(args[1]);
        int modeIndex = atoi(args[2]);
        NSDecimalRound(&result, &lhs, scale, kRoundingModes[modeIndex]);
        encodeDecimal(&result, out, outSize);
        return;
    }

    if (!decodeDecimal(args[0], &lhs) || !decodeDecimal(args[1], &rhs))
    {
        snprintf(out, outSize, "<bad fixture>");
        return;
    }

    NSCalculationError error = NSCalculationNoError;
    if (strcmp(op, "add") == 0)            error = NSDecimalAdd(&result, &lhs, &rhs, NSRoundPlain);
    else if (strcmp(op, "subtract") == 0)  error = NSDecimalSubtract(&result, &lhs, &rhs, NSRoundPlain);
    else if (strcmp(op, "multiply") == 0)  error = NSDecimalMultiply(&result, &lhs, &rhs, NSRoundPlain);
    else if (strcmp(op, "divide") == 0 || strcmp(op, "divide_by_zero") == 0)
                                           error = NSDecimalDivide(&result, &lhs, &rhs, NSRoundPlain);
    else { snprintf(out, outSize, "<unknown op %s>", op); return; }

    if (strcmp(op, "divide_by_zero") == 0)
    {
        snprintf(out, outSize, error == NSCalculationDivideByZero ? "!" : "error=%d", (int)error);
        return;
    }

    // An operation that reports an error has not produced the expected value,
    // whatever landed in `result`.  Say so rather than comparing digits.
    if (error != NSCalculationNoError)
    {
        snprintf(out, outSize, "error=%d", (int)error);
        return;
    }
    encodeDecimal(&result, out, outSize);
}

// ---------------------------------------------------------------- harness ---

static Outcome runIsolated(const char *op, char **args, char *observed, size_t observedSize)
{
    int channel[2];
    if (pipe(channel) != 0) { perror("pipe"); exit(2); }

    pid_t child = fork();
    if (child < 0) { perror("fork"); exit(2); }

    if (child == 0)
    {
        close(channel[0]);
        alarm(CASE_TIMEOUT_SECONDS);
        char result[RESULT_SIZE] = {0};
        runCase(op, args, result, sizeof(result));
        ssize_t ignored = write(channel[1], result, strlen(result));
        (void)ignored;
        close(channel[1]);
        _exit(0);
    }

    close(channel[1]);
    memset(observed, 0, observedSize);
    ssize_t got = read(channel[0], observed, observedSize - 1);
    if (got < 0) got = 0;
    observed[got] = '\0';
    close(channel[0]);

    int status = 0;
    waitpid(child, &status, 0);

    if (WIFSIGNALED(status))
    {
        int signo = WTERMSIG(status);
        if (signo == SIGALRM)
        {
            snprintf(observed, observedSize, "<did not terminate within %ds>", CASE_TIMEOUT_SECONDS);
            return OUTCOME_TIMEOUT;
        }
        snprintf(observed, observedSize, "<killed by %s>", strsignal(signo));
        return OUTCOME_SIGNAL;
    }
    return OUTCOME_PASS; // caller compares the value
}

int main(int argc, char **argv)
{
    const char *fixturePath = argc > 1 ? argv[1] : "decimal-fixture.txt";
    loadKnownFailures(argc > 2 ? argv[2] : "decimal-known-failures.txt");
    FILE *fixture = fopen(fixturePath, "r");
    if (fixture == NULL)
    {
        fprintf(stderr, "cannot open fixture %s\n", fixturePath);
        return 2;
    }

    int total = 0, passed = 0, wrong = 0, trapped = 0, hung = 0, known = 0, unexpectedPass = 0;
    char line[MAX_LINE];

    while (fgets(line, sizeof(line), fixture) != NULL)
    {
        line[strcspn(line, "\n")] = '\0';
        if (line[0] == '#' || line[0] == '\0') continue;

        char *fields[8];
        int count = 0;
        char *save = NULL;
        for (char *field = strtok_r(line, "|", &save);
             field != NULL && count < 8;
             field = strtok_r(NULL, "|", &save))
        {
            fields[count++] = field;
        }
        if (count < 3) continue;

        const char *op = fields[0];
        const char *name = fields[1];
        const char *expected = fields[count - 1];

        char observed[RESULT_SIZE];
        Outcome outcome = runIsolated(op, &fields[2], observed, sizeof(observed));
        if (outcome == OUTCOME_PASS)
        {
            outcome = (strcmp(observed, expected) == 0) ? OUTCOME_PASS : OUTCOME_WRONG;
        }

        total++;
        int known_index = knownFailureIndex(op, name);
        if (known_index >= 0)
        {
            knownFailureSeen[known_index] = YES;
            if (outcome == OUTCOME_PASS)
            {
                unexpectedPass++;
                printf("FIXED %-10s %-24s now passes and is still listed in decimal-known-failures.txt\n", op, name);
            }
            else
            {
                known++;
                printf("known %-10s %-24s %s\n", op, name, observed);
            }
            continue;
        }

        switch (outcome)
        {
            case OUTCOME_PASS:
                passed++;
                break;
            case OUTCOME_WRONG:
                wrong++;
                printf("FAIL  %-10s %-24s expected %s\n                                        got      %s\n",
                       op, name, expected, observed);
                break;
            case OUTCOME_SIGNAL:
                trapped++;
                printf("TRAP  %-10s %-24s %s (expected %s)\n", op, name, observed, expected);
                break;
            case OUTCOME_TIMEOUT:
                hung++;
                printf("HANG  %-10s %-24s %s (expected %s)\n", op, name, observed, expected);
                break;
        }
    }
    fclose(fixture);

    int stale = 0;
    for (int i = 0; i < knownFailureCount; i++)
    {
        if (!knownFailureSeen[i])
        {
            stale++;
            printf("STALE decimal-known-failures.txt lists %s, which the fixture does not contain\n",
                   knownFailures[i]);
        }
    }

    printf("\n%d cases: %d passed, %d wrong, %d trapped, %d did not terminate, %d known failures\n",
           total, passed, wrong, trapped, hung, known);
    if (unexpectedPass > 0)
    {
        printf("%d case(s) listed as known failures now pass: remove them from decimal-known-failures.txt\n",
               unexpectedPass);
    }

    int bad = wrong + trapped + hung + unexpectedPass + stale;
    return bad == 0 ? 0 : 1;
}
