/// "Make it smaller" without AI: first-step ideas and a short checklist for
/// common kinds of task, matched from the title. Works offline, sends
/// nothing anywhere, and needs no API key. Pure Dart.
library;

class StepIdeas {
  const StepIdeas({required this.firstSteps, required this.checklist});

  /// Two-minute starters, best first.
  final List<String> firstSteps;

  /// A short breakdown of the whole task.
  final List<String> checklist;
}

class _Kind {
  const _Kind(this.words, this.firstSteps, this.checklist);
  final List<String> words;
  final List<String> firstSteps;
  final List<String> checklist;
}

// Order matters: the first kind with a matching word wins, so the more
// specific kinds come first ("call the insurance company" is a call, not
// paperwork).
const _kinds = [
  _Kind(
    ['call', 'phone', 'ring', 'voicemail', 'book an appointment', 'schedule'],
    [
      'Find the number and put it on screen',
      'Write one line: what you need from this call',
      'Dial and say the first sentence',
    ],
    [
      'Find the number',
      'Write down what you need from the call',
      'Have any reference numbers ready',
      'Make the call',
      'Note what was agreed',
    ],
  ),
  _Kind(
    ['email', 'reply', 'respond', 'message', 'text ', 'inbox', 'write back'],
    [
      'Open the email and read it once',
      'Write the first sentence only',
      'Type who it\'s to and a subject line',
    ],
    [
      'Open it and read it once',
      'Jot the two or three points to make',
      'Write a rough reply',
      'Read it back once and send',
    ],
  ),
  _Kind(
    [
      'form',
      'paperwork',
      'application',
      'apply',
      'renew',
      'claim',
      'tax',
      'insurance',
      'register',
      'sign up',
      'registration',
    ],
    [
      'Open the website or find the form',
      'Find the one document you\'ll need',
      'Fill in just your name and the date',
    ],
    [
      'Find the form or the website',
      'Gather what it asks for (ID, numbers, dates)',
      'Fill in the easy parts',
      'Do the hard parts',
      'Submit it and save the confirmation',
    ],
  ),
  _Kind(
    ['pay', 'bill', 'invoice', 'budget', 'bank', 'refund'],
    [
      'Open the banking app or the bill',
      'Find the amount and the due date',
      'Log in to the account',
    ],
    [
      'Find the bill',
      'Check the amount',
      'Pay it',
      'Save or screenshot the confirmation',
    ],
  ),
  _Kind(
    [
      'report',
      'draft',
      'document',
      'doc ',
      'write',
      'essay',
      'presentation',
      'slides',
      'proposal',
      'cheat sheet',
      'policy',
    ],
    [
      'Open a blank document and give it a title',
      'Write the headings only',
      'Write one bad first sentence',
    ],
    [
      'Open a document and title it',
      'List the headings',
      'Fill in each heading roughly',
      'Read it through once and fix the worst parts',
      'Send or save it',
    ],
  ),
  _Kind(
    [
      'clean',
      'tidy',
      'laundry',
      'dishes',
      'vacuum',
      'declutter',
      'organize',
      'organise',
      'clear out',
      'sort',
    ],
    [
      'Set a 5-minute timer and pick up ten things',
      'Clear one surface',
      'Put on music and start with what\'s nearest',
    ],
    [
      'Pick one area to start',
      'Put away what belongs somewhere else',
      'Bin or recycle what you don\'t need',
      'Wipe or vacuum that area',
      'Move to the next area if there\'s time',
    ],
  ),
  _Kind(
    [
      'buy',
      'shop',
      'groceries',
      'pick up',
      'drop off',
      'return',
      'post office',
      'pharmacy',
      'errand',
    ],
    [
      'Write the list',
      'Put your shoes on and grab your keys',
      'Check the opening hours',
    ],
    [
      'Write what you need',
      'Check opening hours',
      'Get ready to go',
      'Do the errand',
    ],
  ),
  _Kind(
    [
      'plan',
      'prepare',
      'prep',
      'organize a',
      'arrange',
      'meeting',
      'trip',
      'event',
      'party',
    ],
    [
      'Write three bullet points of what it needs',
      'Open your calendar and pick a date',
      'Text one person the first question',
    ],
    [
      'Write what it needs to include',
      'Pick a date or deadline',
      'Make the bookings or invites',
      'Send the details to everyone involved',
    ],
  ),
  _Kind(
    ['study', 'read', 'learn', 'course', 'homework', 'review', 'research'],
    [
      'Open the book or page where you left off',
      'Read one paragraph',
      'Write down the one question you want answered',
    ],
    [
      'Open the material',
      'Skim the headings',
      'Read or work for one session',
      'Write three things you learned',
    ],
  ),
  _Kind(
    ['exercise', 'workout', 'gym', 'run', 'walk', 'yoga', 'stretch'],
    [
      'Put on your shoes',
      'Fill a water bottle',
      'Do one stretch right where you are',
    ],
    ['Get changed', 'Warm up for a few minutes', 'Do the workout', 'Cool down'],
  ),
  _Kind(
    ['cook', 'meal', 'dinner', 'lunch', 'bake', 'recipe'],
    [
      'Pick the recipe',
      'Take out the first ingredient',
      'Fill the pot or turn on the oven',
    ],
    [
      'Choose what to make',
      'Check you have the ingredients',
      'Prep the ingredients',
      'Cook it',
      'Clean up as you go',
    ],
  ),
  _Kind(
    ['fix', 'repair', 'install', 'set up', 'setup', 'update the', 'upgrade'],
    [
      'Find the instructions or a how-to video',
      'Get the one tool you need',
      'Take a photo of how it is now',
    ],
    [
      'Find instructions',
      'Gather tools and parts',
      'Do the fix',
      'Test that it works',
    ],
  ),
];

const _general = StepIdeas(
  firstSteps: [
    'Open whatever you need for it',
    'Write down the very first action',
    'Set a 2-minute timer and do the easiest part',
  ],
  checklist: [
    'Get what you need in front of you',
    'Do the first small part',
    'Do the rest in short bursts',
    'Check it\'s done and wrap up',
  ],
);

/// Ideas for [title]; general ones when nothing specific matches.
StepIdeas stepIdeasFor(String title) {
  final t = ' ${title.toLowerCase()} ';
  for (final k in _kinds) {
    for (final w in k.words) {
      if (_matches(t, w)) {
        return StepIdeas(firstSteps: k.firstSteps, checklist: k.checklist);
      }
    }
  }
  return _general;
}

/// Whole-word match, so "run" doesn't match "brunch" and "pay" doesn't
/// match "paycheck stub" (a phrase may contain spaces).
bool _matches(String padded, String word) {
  final w = word.trim();
  // Plurals count too: taxes, bills, emails, calls.
  final re = RegExp('(^|[^a-z])${RegExp.escape(w)}(s|es)?([^a-z]|\$)');
  return re.hasMatch(padded);
}
