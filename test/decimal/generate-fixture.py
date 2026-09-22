#!/usr/bin/env python3
"""Generate decimal-fixture.txt from Python's `decimal` module.

The expected values in the fixture come from an arbitrary-precision decimal
implementation that has nothing to do with Foundation.  Nothing here reads,
imports or mirrors NSDecimal.c: the fixture states what the answers ARE, so a
self-consistently wrong implementation cannot make the tests pass.

NSDecimal holds a 128-bit mantissa (8 x 16-bit limbs) and a signed 8-bit
decimal exponent, giving 38 significant digits -- NSDecimalDigitPrecision in
Foundation's own header.  Contexts below use that precision.

Fixture line format (| separated):
    <op>|<name>|<arg...>|<expect>
where a decimal operand or result is encoded as
    <sign>,<exponent>,<limb count>,<limb>,<limb>,...     (little-endian limbs)
and a string result is a literal.  `!` as an expectation means the operation is
required to report failure rather than produce a value.
"""

from decimal import Decimal, getcontext, localcontext, ROUND_HALF_UP, ROUND_DOWN, ROUND_UP, ROUND_HALF_EVEN
import sys

PRECISION = 38          # NSDecimalDigitPrecision, NSDecimal.h / NSDecimalCore.m
MAX_LIMBS = 8           # NSDecimalMaxSize
getcontext().prec = PRECISION


def encode(value: Decimal) -> str:
    """Encode an exact Decimal as NSDecimal's compact representation.

    Compact form: the integer mantissa carries no trailing factor of ten, which
    is the normalisation NSDecimal documents (and the only one that makes the
    representation unique).  Raises if the value does not fit.
    """
    sign, digits, exponent = value.as_tuple()
    mantissa = int(''.join(map(str, digits)))
    if mantissa == 0:
        return '0,0,0'
    while mantissa % 10 == 0:
        mantissa //= 10
        exponent += 1
    if mantissa >= 1 << (16 * MAX_LIMBS):
        raise ValueError(f'mantissa {mantissa} exceeds 128 bits')
    if not -128 <= exponent <= 127:
        raise ValueError(f'exponent {exponent} out of signed 8-bit range')
    limbs = []
    m = mantissa
    while m:
        limbs.append(m & 0xFFFF)
        m >>= 16
    return ','.join([str(sign), str(exponent), str(len(limbs))] + [str(x) for x in limbs])


def plain_string(value: Decimal) -> str:
    """The digits-and-separator rendering NSDecimalString is specified to make.

    Always positional, never exponential, with the compact mantissa; this is
    what -[NSDecimalNumber stringValue] / Decimal.description produce on macOS.
    """
    sign, digits, exponent = value.as_tuple()
    mantissa = int(''.join(map(str, digits)))
    if mantissa == 0:
        return '0'
    while mantissa % 10 == 0:
        mantissa //= 10
        exponent += 1
    text = str(mantissa)
    if exponent >= 0:
        body = text + '0' * exponent
    elif len(text) + exponent > 0:
        body = text[:len(text) + exponent] + '.' + text[len(text) + exponent:]
    else:
        body = '0.' + '0' * (-exponent - len(text)) + text
    return ('-' if sign else '') + body


ROUNDING = {                    # NSRoundingMode -> the decimal module's mode
    'plain': ROUND_HALF_UP,     # NSRoundPlain:  ties away from zero
    'down': ROUND_DOWN,         # NSRoundDown:   toward zero
    'up': ROUND_UP,             # NSRoundUp:     away from zero
    'bankers': ROUND_HALF_EVEN, # NSRoundBankers
}
ROUNDING_INDEX = {'plain': 0, 'down': 1, 'up': 2, 'bankers': 3}

lines = []


def emit(op, name, *args):
    lines.append('|'.join([op, name] + [str(a) for a in args]))


def arith(op, name, a, b):
    a, b = Decimal(a), Decimal(b)
    if op == 'add':
        r = a + b
    elif op == 'subtract':
        r = a - b
    elif op == 'multiply':
        r = a * b
    elif op == 'divide':
        r = a / b
    emit(op, name, encode(a), encode(b), encode(r))


# ---------------------------------------------------------------- addition --
# Exactness is the whole point of the type: these are the identities binary
# floating point gets wrong.
arith('add', 'tenths', '0.1', '0.2')                    # the canonical 0.30000000000000004
arith('add', 'money_carry', '1234567.89', '0.11')
arith('add', 'cents', '0.07', '0.01')
arith('add', 'negative', '-0.3', '0.1')
arith('add', 'crosses_64bit', '9999999999999999999', '1')
arith('add', 'wide_mantissa', '12345678901234567890123456789012345678', '0')
arith('add', 'unlike_exponents', '1000000', '0.000001')
arith('add', 'to_zero', '1.5', '-1.5')
arith('subtract', 'borrow', '1.00', '0.01')
arith('subtract', 'money', '20.00', '19.99')
arith('subtract', 'sign_flip', '1', '2')
arith('subtract', 'wide', '10000000000000000000', '1')

# ---------------------------------------------------------- multiplication --
arith('multiply', 'price_times_three', '19.99', '3')
arith('multiply', 'tax', '100.00', '0.0825')
arith('multiply', 'tenths', '0.1', '0.1')
arith('multiply', 'negatives', '-1.5', '-2.5')
arith('multiply', 'by_zero', '12345.6789', '0')
arith('multiply', 'wide', '4294967296', '4294967296')

# -------------------------------------------------------------- division ----
# Terminating quotients first: no rounding is involved, so a correct
# implementation must reproduce them digit for digit.
arith('divide', 'exact_half', '1', '2')
arith('divide', 'exact_money', '100.00', '8')
arith('divide', 'power_of_ten', '1', '10')            # the one branch that is fixed-point today
arith('divide', 'power_of_ten_100', '123.45', '100')
arith('divide', 'exact_quarters', '5', '4')
arith('divide', 'negative', '-1', '8')
# Repeating quotients, correctly rounded to the 38 significant digits the
# representation holds.
arith('divide', 'third', '1', '3')
arith('divide', 'seventh', '100.00', '7')
arith('divide', 'sixth', '1', '6')
arith('divide', 'eleventh', '1', '11')

# Quotients that terminate in decimal but not in binary.  1/2, 5/4 and friends
# above survive a float round-trip unharmed and so cannot distinguish a real
# decimal division from one routed through double; every case here can.
arith('divide', 'fifth', '1', '5')
arith('divide', 'twentieth', '1', '20')
arith('divide', 'fortieth', '1', '40')
arith('divide', 'tenth_of_tenth', '0.3', '3')
arith('divide', 'money_split', '0.30', '3')
arith('divide', 'cents_each', '100.00', '3.2')

# division by zero must be reported, not guessed at
emit('divide_by_zero', 'one_over_zero', encode(Decimal('1')), encode(Decimal('0')), '!')

# ---------------------------------------------------------------- rounding --
for mode in ('plain', 'down', 'up', 'bankers'):
    for name, value, scale in [
        ('tie_up', '123.45', 1),
        ('tie_down', '123.35', 1),
        ('tie_int_odd', '2.5', 0),
        ('tie_int_even', '3.5', 0),
        ('neg_tie', '-123.45', 1),
        ('neg_tie_int', '-2.5', 0),
        ('below_tie', '1.24', 1),
        ('above_tie', '1.26', 1),
        ('money_cents', '1.005', 2),
        ('no_truncation', '1.25', 4),
        ('to_tens', '1250', -1),
    ]:
        v = Decimal(value)
        with localcontext() as ctx:
            ctx.prec = PRECISION
            quantum = Decimal(1).scaleb(-scale)
            r = v.quantize(quantum, rounding=ROUNDING[mode])
        emit('round', f'{mode}_{name}', encode(v), scale, ROUNDING_INDEX[mode], encode(r))

# ------------------------------------------------------------------ string --
# NSDecimalString / Decimal.description.  Values below 1 and mantissas wider
# than 64 bits are the two shapes the current implementation cannot express.
for name, value in [
    ('one', '1'),
    ('int', '42'),
    ('half', '0.5'),
    ('thousandth', '0.001'),
    ('money', '1234567.89'),
    ('negative_tenth', '-0.1'),
    ('hundred', '100'),
    ('zero', '0'),
    ('leading_zeros', '0.000123'),
    ('wide_mantissa', '10000000000000000000'),
    ('full_precision', '12345678901234567890123456789012345678'),
    ('negative_wide', '-99999999999999999999'),
]:
    v = Decimal(value)
    emit('string', name, encode(v), plain_string(v))

out = '\n'.join([
    '# Generated by generate-fixture.py from Python\'s decimal module.',
    '# Do not hand-edit: regenerate instead.  Expected values are independent',
    f'# of Foundation and computed at {PRECISION} significant digits.',
    '# op|name|arg...|expected      decimal = sign,exponent,limbcount,limb...',
] + lines) + '\n'

path = sys.argv[1] if len(sys.argv) > 1 else 'decimal-fixture.txt'
open(path, 'w').write(out)
print(f'{len(lines)} cases -> {path}')
