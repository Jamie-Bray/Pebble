import {
  AI_PHOTO_LIMITS,
  cleanDescription,
  cleanEmailDescriptions,
  containsVerdict,
  isValidIdempotencyKey,
  parseProviderReply,
  validateJpegBase64,
} from './ai_photo.ts';

function assert(condition: unknown, label: string): asserts condition {
  if (!condition) throw new Error(label);
}

function jpegBase64(bytes = 300): string {
  const data = new Uint8Array(bytes).fill(0x41);
  data.set([0xff, 0xd8, 0xff, 0xe0]);
  let binary = '';
  for (const b of data) binary += String.fromCharCode(b);
  return btoa(binary);
}

Deno.test('verdict filter: every agreed word is caught as a whole word', () => {
  const verdicts = [
    'The door is locked.',
    'The door looks unlocked.',
    'The window is secure.',
    'The latch is securely in place.',
    'Everything looks safe.',
    'This seems unsafe.',
    'The hob is off.',
    'All four dials are switched OFF',
    'The light is on.',
    'The oven is on and glowing.',
    'The lamp was left on',
    'The socket is switched on at the wall.',
    'The dial is turned to on.',
    'The switch is in the on position.',
    'The window is closed properly.',
    'The gate is properly shut.',
    'The door is fully closed.',
    'The Tuesday tablets have been taken.',
    'The washing up is done.',
    'It all looks fine.',
    'The plug looks OK.',
    'Everything is okay here.',
  ];
  for (const text of verdicts) assert(containsVerdict(text), `should be filtered: ${text}`);
});

Deno.test('verdict filter: plain descriptions of what is visible pass', () => {
  const visible = [
    'A white door with the handle pointing up and a key in the lock.',
    'A pan on the hob with its handle turned to the left.',
    'Four black dials, each with the marker at the top.',
    'An off-white wall with a double socket; both switches are up.',
    'The top of the dial is cut off by the edge of the photo.',
    'The dial marker is on 3.',
    'A lamp is on the bedside table.',
    'A person is visible beside an open window.',
    'A pill organiser with the Monday and Tuesday compartments empty.',
    'A closed window with the handle pointing down.',
    'A padlock hangs on the gate with its shackle through the hasp.',
    'A second door is one step further along the hall.',
    'A bookshelf, a sofa and an office chair.',
    'A lockable cabinet with a brass handle.',
  ];
  for (const text of visible) assert(!containsVerdict(text), `should pass: ${text}`);
});

Deno.test('cleanDescription: collapses whitespace, strips invisible characters, caps length', () => {
  assert(cleanDescription('  A  white\n door.\u202e ') === 'A white door.', 'cleaned');
  assert(cleanDescription('') === null && cleanDescription(42) === null, 'empty and non-string rejected');
  assert(cleanDescription('a'.repeat(AI_PHOTO_LIMITS.maxDescriptionChars + 1)) === null, 'too long rejected, not cut');
  assert(cleanDescription('The door is locked.') === null, 'verdict rejected');
});

Deno.test('cleanEmailDescriptions: at most five, verdicts and junk dropped', () => {
  const cleaned = cleanEmailDescriptions(['A white door.', 'The hob is off.', 7, 'A blue bag.', 'c', 'd', 'e']);
  assert(JSON.stringify(cleaned) === JSON.stringify(['A white door.', 'A blue bag.', 'c']), `got ${JSON.stringify(cleaned)}`);
  assert(cleanEmailDescriptions('A white door.').length === 0, 'non-array ignored');
});

Deno.test('parseProviderReply: accepts the agreed JSON, also inside a code fence', () => {
  const plain = parseProviderReply('{"clarity":"clear","description":"A white door with the handle up."}');
  assert(plain.ok && plain.description === 'A white door with the handle up.', 'plain');
  const fenced = parseProviderReply('```json\n{"clarity":"partly_unclear","description":"A hob; the left dial is hidden by a pan."}\n```');
  assert(fenced.ok, 'fenced');
});

Deno.test('parseProviderReply: everything else is a failure code', () => {
  const code = (reply: string) => {
    const result = parseProviderReply(reply);
    return result.ok ? 'ok' : result.code;
  };
  assert(code('{"clarity":"cannot_tell","description":"Too dark to make out the object."}') === 'cannot_tell', 'cannot_tell');
  assert(code('{"clarity":"clear","description":"The door is locked."}') === 'verdict', 'verdict');
  assert(code('{"clarity":"clear","description":"' + 'word '.repeat(80) + '"}') === 'rejected', 'too long');
  assert(code('{"clarity":"clear","description":""}') === 'rejected', 'empty');
  assert(code('A white door.') === 'malformed', 'not JSON');
  assert(code('{"clarity":"clear"') === 'malformed', 'truncated');
  assert(code('{"clarity":"great","description":"A door."}') === 'malformed', 'unknown clarity');
  assert(code('{"clarity":"clear","description":["A door."]}') === 'malformed', 'description not a string');
  assert(code('[1,2]') === 'malformed', 'array');
  assert(code('') === 'malformed', 'empty reply');
});

Deno.test('validateJpegBase64: JPEG magic bytes and the size cap', () => {
  const ok = validateJpegBase64(jpegBase64(300));
  assert(ok.ok && ok.bytes === 300, 'valid JPEG, size reported');
  const code = (value: unknown) => {
    const result = validateJpegBase64(value);
    return result.ok ? 'ok' : result.code;
  };
  assert(code(undefined) === 'imageMissing' && code('') === 'imageMissing', 'missing');
  assert(code(btoa('\x89PNG\r\n\x1a\n' + 'A'.repeat(300))) === 'imageNotJpeg', 'PNG refused');
  assert(code('data:image/jpeg;base64,' + jpegBase64(300)) === 'imageNotBase64', 'data URL refused');
  assert(code(jpegBase64(300).replace('Q', '*')) === 'imageNotBase64', 'bad characters');
  assert(code(jpegBase64(AI_PHOTO_LIMITS.maxImageBytes)) === 'ok', 'exactly at the cap');
  assert(code(jpegBase64(AI_PHOTO_LIMITS.maxImageBytes + 3)) === 'imageTooLarge', 'over the cap');
});

Deno.test('idempotency key shape', () => {
  assert(isValidIdempotencyKey('3f2b8c1e-9a4d-4c1b-8e2f-0a1b2c3d4e5f'), 'uuid');
  assert(!isValidIdempotencyKey('short') && !isValidIdempotencyKey('has space in it') && !isValidIdempotencyKey(12345678), 'bad keys');
});
