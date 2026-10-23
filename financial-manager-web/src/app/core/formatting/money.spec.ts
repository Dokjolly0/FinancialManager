import { formatMoney, minorToInput, parseMinorUnits } from './money';

describe('parseMinorUnits', () => {
  it('accepts either decimal separator', () => {
    expect(parseMinorUnits('500')).toBe(50000);
    expect(parseMinorUnits('500,5')).toBe(50050);
    expect(parseMinorUnits('500.50')).toBe(50050);
    expect(parseMinorUnits(' 0,01 ')).toBe(1);
  });

  it('never rounds through floats', () => {
    // 0.29 * 100 = 28.999999999999996 in floating point.
    expect(parseMinorUnits('0,29')).toBe(29);
    expect(parseMinorUnits('1234567,89')).toBe(123456789);
  });

  it('rejects invalid, negative and over-precise input', () => {
    for (const input of ['', 'abc', '-5', '1,234,5', '1.005', '1e3']) {
      expect(parseMinorUnits(input)).toBeNull();
    }
  });
});

describe('minorToInput', () => {
  it('uses the locale separator', () => {
    expect(minorToInput(123450, 'it-IT')).toBe('1234,50');
    expect(minorToInput(5, 'en-GB')).toBe('0.05');
    expect(minorToInput(-1999, 'it-IT')).toBe('-19,99');
  });
});

describe('formatMoney', () => {
  it('formats minor units in the locale', () => {
    expect(formatMoney(243050, 'EUR', 'it-IT')).toMatch(/2\.430,50\s€/);
    expect(formatMoney(243050, 'EUR', 'en-GB')).toBe('€2,430.50');
  });

  it('shows the sign of positive amounts when asked', () => {
    expect(formatMoney(1000, 'EUR', 'en-GB', { signed: true })).toBe('+€10.00');
    expect(formatMoney(-1000, 'EUR', 'en-GB', { signed: true })).toBe('-€10.00');
    expect(formatMoney(0, 'EUR', 'en-GB', { signed: true })).toBe('€0.00');
  });
});
