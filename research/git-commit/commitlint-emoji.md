# Can commitlint forbid or require emoji?

Researched 2026-11-13. Sources: the commitlint docs (commitlint.js.org), commitlint source at
[`1c020f6`](https://github.com/conventional-changelog/commitlint/tree/1c020f6) (HEAD that day),
conventional-changelog source at [`0cdedf8`](https://github.com/conventional-changelog/conventional-changelog/tree/0cdedf8),
and the published npm tarballs (linked through unpkg and the npm registry). Blog posts were not used.

## Answer

commitlint has no built-in rule that takes a regex or character class, so it cannot forbid or require emoji out of the box. `@commitlint/config-conventional` has no emoji or ASCII rule. It rejects a *leading* emoji (`✨ feat: x`) only as a side effect: the header pattern needs `\w*` at `^`, so the header does not parse, and `type-empty` and `subject-empty` fire. It accepts emoji anywhere after `type: ` (`feat: ✨ x` passes, because `subject-case` skips a subject that does not start with a letter). Emoji enforcement exists only outside core. `commitlint-plugin-gitmoji` (`start-with-gitmoji`, packaged as `commitlint-config-gitmoji`) and `commitlint-config-git-commit-emoji` *require* an emoji. Neither has been published since 2023 or 2021. No published package *forbids* emoji. A repo forbids non-ASCII only by writing its own rule: a documented local plugin in `commitlint.config.js`, `commitlint-plugin-function-rules`, or a custom `parserPreset` header pattern. So "a commitlint repo decides for itself" is true only when the repo adds such a rule. A repo on the stock conventional config gets no emoji check after the type.

## 1. Built-in rules that match characters or patterns

- **No built-in rule takes an arbitrary pattern.** The rules reference lists 39 rules. Their values are case names, lengths, literal strings, and enum lists ([rules reference](https://commitlint.js.org/reference/rules.html)). The source has the same set ([`@commitlint/rules/src`](https://github.com/conventional-changelog/commitlint/tree/1c020f6/@commitlint/rules/src)).
- **`subject-case`, `header-case`, `body-case`, `scope-case`, `type-case`**: the value is one or more of `lower-case`, `upper-case`, `camel-case`, `kebab-case`, `pascal-case`, `sentence-case`, `snake-case`, `start-case`. It is never a regex ([rules#subject-case](https://commitlint.js.org/reference/rules.html#subject-case); [`TargetCaseType`](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/types/src/ensure.ts#L1-L13)). `subject-case` returns valid without checking when the subject does not start with a cased letter (`/^[\p{Ll}\p{Lu}\p{Lt}]/iu`), so a subject that starts with an emoji is skipped ([subject-case.ts#L21-L34](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/subject-case.ts#L21-L34)). `header-case` skips any header that does not start with `[a-z]` ([header-case.ts#L14-L16](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/header-case.ts#L14-L16)).
- **`subject-exclamation-mark`, `breaking-change-exclamation-mark`**: a fixed regex, `/^(\w*)(?:\((.*)\))?!: (.*)$/`, detects the `!` breaking marker. It takes no value ([subject-exclamation-mark.ts#L11](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/subject-exclamation-mark.ts#L11); [rules#subject-exclamation-mark](https://commitlint.js.org/reference/rules.html#subject-exclamation-mark)).
- **`subject-full-stop`, `header-full-stop`, `body-full-stop`**: the value is one literal string, compared with the last character ([subject-full-stop.ts#L4-L16](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/subject-full-stop.ts#L4-L16)).
- **`scope-delimiter-style`**: the value is a list of allowed delimiter strings. A fixed Unicode regex keeps an emoji such as `❤️` whole as a delimiter. The rule checks scope delimiters only ([scope-delimiter-style.ts#L10-L12](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/scope-delimiter-style.ts#L10-L12); [rules#scope-delimiter-style](https://commitlint.js.org/reference/rules.html#scope-delimiter-style)).
- **`type-enum`, `scope-enum`**: exact-string lists. A list can hold emoji-prefixed strings, but only if the parser puts the emoji into `type` (see section 3) ([type-enum.ts#L5-L18](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/type-enum.ts#L5-L18)).
- **`header-match-team-pattern` is not built in.** It is in neither the rules reference nor `@commitlint/rules/src`. GitHub code search finds it only as a local-plugin rule in individual repos' configs.

## 2. `@commitlint/config-conventional`

Rules object, published 21.2.4 ([lib/index.js](https://unpkg.com/@commitlint/config-conventional@21.2.4/lib/index.js)). HEAD also adds `"header-breaking-change": [Error, "never"]`, which is not yet released ([src/index.ts#L3-L39](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/config-conventional/src/index.ts#L3-L39)). `Warning` and `Error` stand for `RuleConfigSeverity.*`:

```js
parserPreset: "conventional-changelog-conventionalcommits",
rules: {
  "body-leading-blank": [Warning, "always"],
  "body-max-line-length": [Error, "always", 100],
  "footer-leading-blank": [Warning, "always"],
  "footer-max-line-length": [Error, "always", 100],
  "header-max-length": [Error, "always", 100],
  "header-trim": [Error, "always"],
  "subject-case": [Error, "never", ["sentence-case", "start-case", "pascal-case", "upper-case"]],
  "subject-empty": [Error, "never"],
  "subject-full-stop": [Error, "never", "."],
  "type-case": [Error, "always", "lower-case"],
  "type-empty": [Error, "never"],
  "type-enum": [Error, "always", ["build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "style", "test"]],
},
```

- No rule names emoji or ASCII. The `subject-case` tests include a Chinese subject, `test: 这是一次提交`, as a valid message ([subject-case.test.ts#L11](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/subject-case.test.ts#L11)).
- The emoji in the same file (`feat` ✨, `fix` 🐛, and so on) sit under `prompt.questions.type.enum`. They are menu labels for the `cz-commitlint` prompt, not rules ([src/index.ts#L40-L80](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/config-conventional/src/index.ts#L40-L80)). The prompt writes the emoji into the header only when a repo sets `emojiInHeader`, which makes the type value `✨ feat` ([getRuleQuestionConfig.ts#L90-L113](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/cz-commitlint/src/services/getRuleQuestionConfig.ts#L90-L113)).

## 3. Plugins and shareable configs with emoji rules

| Package (latest) | Rule or mechanism | Enforces | Last publish |
|---|---|---|---|
| [`commitlint-plugin-gitmoji`](https://registry.npmjs.org/commitlint-plugin-gitmoji) 2.2.6 | `start-with-gitmoji` ([lib/index.js#L11](https://unpkg.com/commitlint-plugin-gitmoji@2.2.6/lib/index.js), [lib/rule.js#L9-L43](https://unpkg.com/commitlint-plugin-gitmoji@2.2.6/lib/rule.js)) | **Requires** a gitmoji (`:code:` or a Unicode emoji from the `gitmojis` list); any other emoji fails. It ignores `when`, so `"never"` cannot turn it into a ban. Its regexes have no `^` and scan the whole raw message. | 2023-02-11 |
| [`commitlint-config-gitmoji`](https://registry.npmjs.org/commitlint-config-gitmoji) 2.3.1 | turns on `start-with-gitmoji` and uses the `@gitmoji/parser-opts` header pattern `^(?:gitmoji-code\|gitmoji\|emoji)\s(?<type>\w*)…` ([lib/index.js#L13-L45](https://unpkg.com/commitlint-config-gitmoji@2.3.1/lib/index.js); [parser-opts#L13](https://unpkg.com/@gitmoji/parser-opts@1.4.0/lib/index.js)) | Emoji **first**. The position comes from the parser: with no leading emoji, `type` is null and the config's `type-empty` fires. | 2023-02-11 |
| [`commitlint-config-git-commit-emoji`](https://registry.npmjs.org/commitlint-config-git-commit-emoji) 1.0.0 | `type-enum` of `'✨ feat'`, `'🐞 fix'`, … plus header pattern `^(?<type>.*\s\w*)…` ([index.js#L4,L19-L36](https://unpkg.com/commitlint-config-git-commit-emoji@1.0.0/index.js)) | **Requires** one of 12 fixed emoji-and-type pairs. Plain `feat: x` does not parse. | 2021-12-12 |
| [`commitlint-plugin-semantic-commit-emoji`](https://registry.npmjs.org/commitlint-plugin-semantic-commit-emoji) / `-config-` 3.0.1 | none: the plugin exports `rules: {}` ([dist/index.js#L2](https://unpkg.com/commitlint-plugin-semantic-commit-emoji@3.0.1/dist/index.js)); the parser allows an optional leading `:shortcode:` ([dist/parser.js#L4](https://unpkg.com/commitlint-plugin-semantic-commit-emoji@3.0.1/dist/parser.js)) | Tolerates a shortcode. Does not require or forbid anything. A Unicode emoji does not parse. | 2024-09-17 |
| [`@lobehub/commitlint-config`](https://registry.npmjs.org/@lobehub/commitlint-config) 3.0.1 | `extends: ["gitmoji"]` ([dist/index.mjs](https://unpkg.com/@lobehub/commitlint-config@3.0.1/dist/index.mjs)) | Same as `commitlint-config-gitmoji` | 2026-11-01 |
| [`commitlint-plugin-function-rules`](https://registry.npmjs.org/commitlint-plugin-function-rules) 5.0.1 | `function-rules/<built-in name>` takes a function as its value ([dist/function-rule.js](https://unpkg.com/commitlint-plugin-function-rules@5.0.1/dist/function-rule.js)) | Whatever the function checks. Generic, with no emoji logic of its own. | 2026-05-16 |

- The three gitmoji packages come from `arvinxx/gitmoji-commit-workflow`. The repo is not archived, but its last default-branch commit is 2023-06-12 (`gh repo view`, `gh api …/commits`). The commitlint docs list it under community projects, "not affiliated with us" ([community-projects](https://commitlint.js.org/reference/community-projects.html)). `@lobehub/commitlint-config` is maintained, but it delegates to that unmaintained config.
- No `@commitlint/config-*` package in the monorepo adds an emoji rule. The configs are `angular`, `angular-type-enum`, `conventional`, `patternplate`, and the `*-scopes` family ([`@commitlint/`](https://github.com/conventional-changelog/commitlint/tree/1c020f6/@commitlint)).

## 4. Parser handling of an emoji before or after the type

- `@commitlint/parse` starts from the `conventional-changelog-angular` options and overlays the repo's `parserOpts` ([parse/src/index.ts#L25-L36](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/parse/src/index.ts#L25-L36)). Extending config-conventional selects `conventional-changelog-conventionalcommits` ([configuration#parser-presets](https://commitlint.js.org/reference/configuration.html#parser-presets)).
- That preset uses `headerPattern: /^(\w*)(?:\((.*)\))?!?: (.*)$/` ([parser.js#L6](https://github.com/conventional-changelog/conventional-changelog/blob/0cdedf8/packages/conventional-changelog-conventionalcommits/src/parser.js#L6)) and `breakingHeaderPattern: /^(\w*)(?:\((.*)\))?!: (.*)$/` ([constants.js#L1](https://github.com/conventional-changelog/conventional-changelog/blob/0cdedf8/packages/conventional-changelog-conventionalcommits/src/constants.js#L1)). Both are anchored at `^`, and `\w` is ASCII `[A-Za-z0-9_]`. The published 10.4.1 tarball has the same patterns.
- The parser tries the breaking pattern, then the header pattern. When neither matches, it assigns no fields ([CommitParser.ts#L200-L216](https://github.com/conventional-changelog/conventional-changelog/blob/0cdedf8/packages/conventional-commits-parser/src/CommitParser.ts#L200-L216)), and `@commitlint/parse` sets `type`, `scope` and `subject` to `null` ([parse/src/index.ts#L12-L14](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/parse/src/index.ts#L12-L14)).

Results from running the exact source regexes in Node (not the commitlint CLI):

| Header | type | subject | Under config-conventional |
|---|---|---|---|
| `✨ feat: add x` | null | null | `type-empty` and `subject-empty` fail ([type-empty.ts](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/type-empty.ts#L5-L11), [subject-empty.ts](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/subject-empty.ts#L5-L12)). `type-enum` skips a null type ([type-enum.ts#L8-L10](https://github.com/conventional-changelog/commitlint/blob/1c020f6/@commitlint/rules/src/type-enum.ts#L8-L10)). |
| `:sparkles: feat: add x` | null | null | same as above |
| `feat: ✨ add x` | `feat` | `✨ add x` | passes: `subject-case` skips the non-letter start |
| `feat: add x ✨` | `feat` | `add x ✨` | passes |
| `feat(✨): add x` | `feat` | `add x` (scope `✨`) | passes: the scope group is `.*`, and the config has no scope rule |

So the default config rejects a leading emoji only through "type may not be empty". It never says "emoji". It accepts emoji everywhere after `type: `.

## 5. A local rule or plugin to forbid non-ASCII

- Yes. Under "Local Plugins", the docs show inline plugin objects in the `plugins` array of `commitlint.config.js`, turned on like any rule ([plugins#local-plugins](https://commitlint.js.org/reference/plugins.html#local-plugins)). A rule gets `(parsed, when, value)` and returns `[valid, message]`. `parsed` carries `header`, `subject`, `body` and `raw` ([plugins#rule-implementation](https://commitlint.js.org/reference/plugins.html#rule-implementation)). A string entry in `plugins` loads as an npm package, so a local file must be imported ([plugins#plugin-in-its-own-file](https://commitlint.js.org/reference/plugins.html#plugin-in-its-own-file)). JSON and YAML configs reach a local plugin through `extends` ([plugins#json-and-yaml-configurations](https://commitlint.js.org/reference/plugins.html#json-and-yaml-configurations)).
- Example. The rule function was run in Node against sample `parsed` objects; the full config was not loaded by commitlint:

  ```js
  export default {
    extends: ["@commitlint/config-conventional"],
    plugins: [{ rules: {
      "header-ascii": ({ header }) => [/^[\x20-\x7E]*$/.test(header ?? ""), "header must be ASCII (no emoji)"],
    } }],
    rules: { "header-ascii": [2, "always"] },
  };
  ```

- Other routes: `commitlint-plugin-function-rules` (section 3). Or a custom `parserPreset.parserOpts.headerPattern` ([configuration#parser-presets](https://commitlint.js.org/reference/configuration.html#parser-presets)), which, like the gitmoji config, fails only through `type-empty`.

## Not verified

- No end-to-end `commitlint` run: `npm install` was denied in this session. The section 4 outcomes come from running the source regexes in Node and reading the rule code. The same holds for the section 5 config and for what happens to an `emojiInHeader` header.
- `start-with-gitmoji` behavior (no anchor, ignores `when`) was read from the published `lib/rule.js` and not run. The emoji lists in its `gitmojis` and `emoji-regex` dependencies were not inspected.
- Whether the next config-conventional release turns on `header-breaking-change` (HEAD has it, 21.2.4 does not). It does not affect emoji.
- Completeness of section 3: discovery used npm registry search ("commitlint emoji", "commitlint gitmoji") and the docs' community list. Packages without those keywords can exist.
- "Maintained" is judged only from publish dates and the repo archive flag. Issue and PR activity were not reviewed.
- Where `header-match-team-pattern` comes from: it was seen only in user repos via GitHub code search, and no package that defines it was found.
