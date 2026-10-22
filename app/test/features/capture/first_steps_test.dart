import 'package:adhd_tax/features/capture/first_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the kind of task from the title', () {
    expect(
      stepIdeasFor('Call the dentist').firstSteps.first,
      contains('number'),
    );
    expect(
      stepIdeasFor('Reply to Sam about Friday').firstSteps.first,
      contains('email'),
    );
    expect(
      stepIdeasFor('Renew car registration').checklist,
      contains('Submit it and save the confirmation'),
    );
    expect(
      stepIdeasFor('Clear out the garage').firstSteps,
      contains('Clear one surface'),
    );
  });

  test('a call about insurance is a call, not paperwork', () {
    expect(
      stepIdeasFor('Call insurance about the claim').checklist.first,
      'Find the number',
    );
  });

  test('plurals match too', () {
    expect(
      stepIdeasFor('Do taxes').checklist.first,
      'Find the form or the website',
    );
    expect(stepIdeasFor('Pay bills').firstSteps.first, contains('banking'));
  });

  test('whole words only: "brunch" is not a run', () {
    expect(
      stepIdeasFor('Brunch with Jo').firstSteps,
      isNot(contains('Put on your shoes')),
    );
  });

  test('anything else gets general ideas', () {
    final ideas = stepIdeasFor('Think about the garden');
    expect(ideas.firstSteps, hasLength(3));
    expect(ideas.checklist, isNotEmpty);
  });
}
