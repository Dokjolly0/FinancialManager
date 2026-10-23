import { SseParser, sseJson } from './sse';

describe('SseParser', () => {
  it('parses events split across chunks', () => {
    const parser = new SseParser();
    expect(parser.push('event: delta\ndata: {"te')).toEqual([]);
    expect(parser.push('xt":"Ciao"}\n\n')).toEqual([{ event: 'delta', data: '{"text":"Ciao"}' }]);
  });

  it('skips comments, joins data lines and defaults the event name', () => {
    const parser = new SseParser();
    const events = parser.push(': ping\r\ndata: one\r\ndata: two\r\n\r\n');
    expect(events).toEqual([{ event: 'message', data: 'one\ntwo' }]);
  });

  it('emits a last event without its blank line at the end', () => {
    const parser = new SseParser();
    expect(parser.push('event: done\ndata: {}')).toEqual([]);
    expect(parser.end()).toEqual([{ event: 'done', data: '{}' }]);
  });

  it('decodes JSON data, tolerating garbage', () => {
    expect(sseJson({ event: 'm', data: '{"a":1}' })).toEqual({ a: 1 });
    expect(sseJson({ event: 'm', data: 'not json' })).toEqual({});
  });
});
