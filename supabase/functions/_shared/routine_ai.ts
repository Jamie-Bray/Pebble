// Pure rules for the AI routine builder: limits, request validation, the word
// filter and parsing of the model's reply. No I/O, so it is unit tested
// directly (routine_ai_test.ts).

export const ROUTINE_AI_LIMITS = {
  /** Provider calls one build can make: questions, the draft, two "Try again". */
  callsPerBuild: 4,
  /** Personal Premium builds per account in a rolling 24 hours. */
  premiumDailyPerUser: 20,
  /** Free builds across everyone in a rolling 24 hours (a guard against scripts). */
  freeDailyCap: 2000,
  /** Provider calls across everyone per UTC month (about 20,000 builds). */
  monthlyCalls: 30000,
  maxDescriptionChars: 400,
  minDescriptionChars: 3,
  maxAnswers: 2,
  maxAnswerChars: 120,
  maxQuestions: 2,
  maxOptionsPerQuestion: 4,
  minSteps: 3,
  maxSteps: 8,
  maxNameChars: 40,
  maxStepChars: 60,
  maxDetailChars: 140,
  maxQuestionChars: 90,
  maxOptionChars: 30,
} as const;

/** A random install ID from the app (a UUID). */
export function isValidInstallId(value: unknown): value is string {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

/** One per build, made by the app; reused for "Try again" and the follow-up. */
export function isValidBuildKey(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(value);
}

export type BuildAnswer = { question: string; answer: string };

export type BuildRequest = {
  description: string;
  answers: BuildAnswer[];
};

export function validateBuildRequest(body: Record<string, unknown>):
  | { ok: true; request: BuildRequest }
  | { ok: false; code: string } {
  const description = typeof body.description === 'string' ? body.description.trim() : '';
  if (description.length < ROUTINE_AI_LIMITS.minDescriptionChars) return { ok: false, code: 'descriptionMissing' };
  if (description.length > ROUTINE_AI_LIMITS.maxDescriptionChars) return { ok: false, code: 'descriptionTooLong' };
  const answers: BuildAnswer[] = [];
  if (body.answers !== undefined) {
    if (!Array.isArray(body.answers) || body.answers.length > ROUTINE_AI_LIMITS.maxAnswers) {
      return { ok: false, code: 'answers' };
    }
    for (const item of body.answers) {
      const question = typeof item?.question === 'string' ? item.question.trim() : '';
      const answer = typeof item?.answer === 'string' ? item.answer.trim() : '';
      if (!question || !answer ||
          question.length > ROUTINE_AI_LIMITS.maxAnswerChars ||
          answer.length > ROUTINE_AI_LIMITS.maxAnswerChars) {
        return { ok: false, code: 'answers' };
      }
      answers.push({ question, answer });
    }
  }
  return { ok: true, request: { description, answers } };
}

// ---------------------------------------------------------------------------
// The word filter. Steps are plain actions ("Hob dials off"). Nothing that
// reassures, judges safety, or talks about health or worry gets through.
// ---------------------------------------------------------------------------

const BLOCKED_WORDS = [
  'anxiety', 'anxious', 'ocd', 'obsessive', 'compulsive', 'compulsion', 'intrusive',
  'reassure', 'reassurance', 'worry', 'worried', 'worrying', 'panic', 'calm down',
  'therapy', 'therapist', 'diagnos', 'disorder', 'symptom', 'mental health',
  'you are safe', "you're safe", 'it is safe', "it's safe", 'guaranteed', 'definitely',
];

/** True when `text` contains a word the builder must never show. */
export function hasBlockedWording(text: string): boolean {
  const lower = text.toLowerCase();
  return BLOCKED_WORDS.some((word) =>
    word.includes(' ') || word === 'diagnos'
      ? lower.includes(word)
      : new RegExp(`\\b${word}\\b`).test(lower)
  );
}

function cleanLine(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const line = value.replace(/\s+/g, ' ').trim().replace(/[.。]+$/, '');
  if (!line || line.length > max) return null;
  if (hasBlockedWording(line)) return null;
  return line;
}

/** `detail` goes into the step's description in the editor; '' when none. */
export type DraftStep = { label: string; photo: boolean; detail: string };
export type RoutineDraft = { name: string; steps: DraftStep[] };
export type BuildQuestion = { question: string; options: string[] };

/** Parses and checks a draft. Bad steps are dropped; too few left is a failure. */
export function parseDraftReply(text: string): { ok: true; draft: RoutineDraft } | { ok: false; code: string } {
  let data: Record<string, unknown>;
  try {
    data = JSON.parse(text);
  } catch (_) {
    return { ok: false, code: 'notJson' };
  }
  if (!data || typeof data !== 'object') return { ok: false, code: 'notObject' };
  const name = cleanLine(data.name, ROUTINE_AI_LIMITS.maxNameChars);
  if (!name) return { ok: false, code: 'name' };
  if (!Array.isArray(data.steps)) return { ok: false, code: 'steps' };
  const seen = new Set<string>();
  const steps: DraftStep[] = [];
  for (const raw of data.steps) {
    const label = cleanLine(raw?.label, ROUTINE_AI_LIMITS.maxStepChars);
    if (!label || seen.has(label.toLowerCase())) continue;
    seen.add(label.toLowerCase());
    const detail = typeof raw?.detail === 'string' && raw.detail.trim()
      ? cleanLine(raw.detail, ROUTINE_AI_LIMITS.maxDetailChars) ?? ''
      : '';
    steps.push({ label, photo: raw?.photo === true, detail: detail && `${detail}.` });
    if (steps.length === ROUTINE_AI_LIMITS.maxSteps) break;
  }
  if (steps.length < ROUTINE_AI_LIMITS.minSteps) return { ok: false, code: 'tooFewSteps' };
  return { ok: true, draft: { name, steps } };
}

/** Parses the questions. None left is a failure (the app then builds straight away). */
export function parseQuestionsReply(text: string): { ok: true; questions: BuildQuestion[] } | { ok: false; code: string } {
  let data: Record<string, unknown>;
  try {
    data = JSON.parse(text);
  } catch (_) {
    return { ok: false, code: 'notJson' };
  }
  if (!data || !Array.isArray(data.questions)) return { ok: false, code: 'questions' };
  const questions: BuildQuestion[] = [];
  for (const raw of data.questions) {
    const question = typeof raw?.question === 'string' ? raw.question.replace(/\s+/g, ' ').trim() : '';
    if (!question || question.length > ROUTINE_AI_LIMITS.maxQuestionChars || hasBlockedWording(question)) continue;
    const options = Array.isArray(raw?.options)
      ? raw.options
        .map((o: unknown) => cleanLine(o, ROUTINE_AI_LIMITS.maxOptionChars))
        .filter((o: string | null): o is string => o !== null)
        .slice(0, ROUTINE_AI_LIMITS.maxOptionsPerQuestion)
      : [];
    if (options.length < 2) continue;
    questions.push({ question, options });
    if (questions.length === ROUTINE_AI_LIMITS.maxQuestions) break;
  }
  if (questions.length === 0) return { ok: false, code: 'noQuestions' };
  return { ok: true, questions };
}
