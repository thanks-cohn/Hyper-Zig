# ZIGN01D AI Assistance Policy

AI tools may assist with scaffolding, documentation drafts, code suggestions, review checklists, and explanation. AI output is not accepted as proof.

Every accepted change must build. Every milestone must have smoke-test proof. Students must be able to explain their changes. Students must disclose AI-assisted work if required by their course. Generated code must be reviewed, understood, tested, and documented. Fake success is forbidden.

## Acceptable AI use

- Drafting documentation that the student reviews and corrects.
- Suggesting a small diagnostic command implementation.
- Helping write a smoke-test checklist.
- Explaining RISC-V, Zig, QEMU, or shell-script concepts.
- Producing a first-pass lab report outline that the student verifies.

## Unacceptable AI use

- Submitting AI output the student cannot explain.
- Claiming tests passed when they were not run.
- Removing smoke checks to hide a failure.
- Inventing internet, SMS, modem, call, or hardware support.
- Fabricating transcripts or PASS output.
- Hiding AI assistance when course policy requires disclosure.

## Student disclosure template

```text
AI assistance disclosure:
I used [tool/model] for [drafting/explanation/code suggestion].
I reviewed the output, changed [summary], and verified the final work with:
- [command]
- [PASS/output]
I can explain the changed files and limitations.
```

## Instructor policy options

Instructors may choose one of these policies:

1. **No AI assistance:** Students may not use AI tools for submitted work.
2. **Disclosed AI assistance:** Students may use AI tools but must include the disclosure template.
3. **AI for docs only:** Students may use AI for documentation drafts, but code must be handwritten.
4. **AI allowed with oral defense:** Students may use AI but must explain every changed line and proof result.

## Why proof matters more than authorship claims

Authorship statements are difficult to verify. Build commands, smoke tests, expected output, and student explanations are inspectable. ZIGN01D therefore grades proof and understanding more heavily than unsupported claims about who typed each character.
