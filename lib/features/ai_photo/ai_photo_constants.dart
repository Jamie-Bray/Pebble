// Everything a person is told, and agrees to, about AI photo descriptions.
//
// The provider name and the retention sentence live here and nowhere else in
// the app. If the provider, what it keeps, the wording below or the data sent
// changes, change [aiPhotoConsentVersion] too (and AI_PHOTO_CONSENT_VERSION
// in supabase/functions/_shared/ai_photo.ts, which must be equal). Every
// earlier consent then stops counting, on the phone and on the server, and
// people are asked again.

/// Recorded with each consent, with the time it was given.
const aiPhotoConsentVersion = '2026-10-05.3';

const aiPhotoProviderName = 'Anthropic';
const aiPhotoProviderDescription = 'an AI company in the USA';

/// What happens to the photo. True only while Pebble's server holds the photo
/// in memory for the one request and the provider's terms say 30 days and no
/// training (LEGAL_PROCESSOR_MAP.md).
const aiPhotoRetentionSentence =
    "Pebble doesn't keep a copy for this, and $aiPhotoProviderName deletes "
    "it within 30 days, except where needed for misuse investigations or legal "
    "duties. It doesn't use it to train its AI.";

/// AI describes the photos from this many photo steps, counted from the top
/// of the routine.
const aiPhotoMaxSteps = 5;

String aiPhotoConsentTitle(String routineName) => 'Use AI on "$routineName"?';

const _consentWhatHappens =
    'When you take a photo on a photo step in this routine, Pebble sends it '
    'and the step title to '
    '$aiPhotoProviderName, $aiPhotoProviderDescription, which sends back a '
    "sentence or two saying what's in the photo. $aiPhotoRetentionSentence "
    'No account details are added.';
const _consentCanBeWrong =
    "The description can be wrong. It can't tell you whether something is "
    'locked, switched off or done, so look at the photo yourself if it '
    'matters.';
const _consentOptional =
    "It's optional, and you can turn it off any time in this routine's "
    'settings.';

const aiPhotoConsentBody = <String>[
  _consentWhatHappens,
  _consentCanBeWrong,
  _consentOptional,
];

/// The sentence beside the box. Unchecked until the person checks it.
const aiPhotoConsentCheckLabel =
    "I'm happy for photos and step titles from this routine to be sent to "
    '$aiPhotoProviderName to be described.';

const aiPhotoHowItWorksLabel = 'How AI descriptions work';
const aiPhotoHowItWorksUrl =
    'https://pebbleroutines.com/privacy#ai-photo-descriptions';

/// Shown in the routine's AI settings while it is on.
const aiPhotoOnDetail =
    "Photos and step titles from this routine are sent to $aiPhotoProviderName "
    'to be described. Turn this off and Pebble stops sending them straight '
    'away. Descriptions you already have stay with their photos until you '
    'delete the photo or the run.';

const aiPhotoUnavailableMessage = 'AI descriptions are unavailable right now.';
const aiPhotoFailedMessage = "Couldn't describe this photo.";
const aiPhotoLabel = 'AI description';
