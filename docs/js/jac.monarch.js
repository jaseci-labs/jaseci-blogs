// Monarch syntax definition for Jaclang
window.jaclangMonarchSyntax = {
  defaultToken: '',
  tokenPostfix: '.jac',

  functionKeywords: ['can', 'def', 'impl', 'with'],
  variableKeywords: ['has', 'glob'],
  typeKeywords: ['class', 'node', 'edge', 'walker', 'enum', 'obj', 'test', 'root', 'here'],
  controlKeywords: [
    'import', 'include', 'from', 'as',
    'if', 'else', 'elif', 'while', 'for', 'in', 'match', 'case',
    'return', 'break', 'continue', 'spawn', 'ignore', 'visit', 'disengage',
    'entry', 'exit', 'pass', 'try', 'except', 'finally', 'raise', 'assert',
    'async', 'await', 'lambda', 'by', 'to', 'del', 'check'
  ],

  literalKeywords: ['True', 'False', 'None'],

  typeIdentifiers: [
    'str', 'int', 'float', 'list', 'tuple', 'set', 'dict',
    'bool', 'bytes', 'any', 'type'
  ],

  operators: [
    '=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=', '**=',
    '+', '-', '*', '**', '/', '//', '%', '@',
    '==', '!=', '<', '<=', '>', '>=',
    '<<', '>>', '&', '|', '^', '~',
  ],

  logicalOperators: [
    'and', 'or', 'not', 'is', 'in', 'not in', 'is not'
  ],

  symbols: /[=><!~?:&|+\-*\/\^%]+/,

  escapes: /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

  tokenizer: {
    root: [
      // Comments
      [/#.*$/, 'comment'],

      // Multi-line comment: #* ... *#
      [/#\*/, 'comment', '@comment'],

      [/\b(can|def|impl|with)\b(?=\s+[a-zA-Z_]\w*)/, 'keyword.function', '@function_decl'],
      [/\b(class|node|edge|walker|enum|obj|test)\b(?=\s+[a-zA-Z_]\w*)/, 'keyword.type', '@type_decl'],

      // Keywords and identifiers
      [/[a-zA-Z_]\w*/, {
        cases: {
          '@functionKeywords': 'keyword.function',
          '@variableKeywords': 'keyword.variable',
          '@typeKeywords': 'keyword.type',
          '@controlKeywords': 'keyword.control',
          '@literalKeywords': 'constant.language',
          '@typeIdentifiers': 'type.identifier',
          '@logicalOperators': 'operator.logical',
          '@default': 'identifier'
        }
      }],

      // Numbers
      [/\d*\.\d+([eE][\-+]?\d+)?[jJ]?/, 'number.float'],
      [/0[xX][0-9a-fA-F]+/, 'number.hex'],
      [/0[oO]?[0-7]+/, 'number.octal'],
      [/0[bB][01]+/, 'number.binary'],
      [/\d+[jJ]?/, 'number'],

      // Strings
      [/'([^'\\]|\\.)*$/, 'string.invalid'],
      [/'/, 'string', '@string_single'],
      [/"/, 'string', '@string_double'],

      // Brackets
      [/[{}]/, '@brackets'],
      [/[()\[\]]/, '@brackets'],

      // Operators
      [/@symbols/, {
        cases: {
          '@operators': 'operator',
          '@default': ''
        }
      }],

      // Whitespace
      [/\s+/, 'white'],
    ],

    comment: [
      [/\*#/, 'comment', '@pop'],
      [/[^*#]+/, 'comment'],
      [/./, 'comment']
    ],

    function_decl: [
      [/\s+/, 'white'],
      [/[a-zA-Z_]\w*/, 'function.identifier', '@pop']
    ],

    type_decl: [
      [/\s+/, 'white'],
      [/[a-zA-Z_]\w*/, 'type.identifier', '@pop']
    ],

    string_single: [
      [/[^\\']+/, 'string'],
      [/@escapes/, 'string.escape'],
      [/\\./, 'string.escape.invalid'],
      [/'/, 'string', '@pop']
    ],

    string_double: [
      [/[^\\"]+/, 'string'],
      [/@escapes/, 'string.escape'],
      [/\\./, 'string.escape.invalid'],
      [/"/, 'string', '@pop']
    ]
  }
};

// Define the theme rules and colors for Monaco Editor (Dark Theme)
window.jacThemeRulesDark = [
  { token: 'keyword.function', foreground: 'ff6b35' },  // Primary orange
  { token: 'keyword.variable', foreground: 'ff6b35' },  // Primary orange
  { token: 'keyword.type', foreground: 'ff6b35' },     // Primary orange
  { token: 'keyword.control', foreground: 'f7931e' },  // Secondary orange
  { token: 'function.identifier', foreground: 'cccccc' }, // Text secondary
  { token: 'type.identifier', foreground: '9CDCFE' },  // Light blue
  { token: 'operator.logical', foreground: 'ff6b35' },  // Primary orange
  { token: 'string', foreground: 'CE9178' },           // Warm string color
  { token: 'number', foreground: 'B5CEA8' },           // Green for numbers
  { token: 'comment', foreground: '6A9955' },          // Green for comments
  { token: 'constant.language', foreground: 'f7931e' }, // Secondary orange for True/False/None
  { token: 'operator', foreground: 'ffffff' },         // White for operators
  { token: 'delimiter.bracket', foreground: 'cccccc' }, // Text secondary for brackets
  { token: 'identifier', foreground: 'e6edf3' },       // Light text for identifiers
];

// Define the theme colors for Monaco Editor (Dark Theme)
window.jacThemeColorsDark = {
  'editor.foreground': '#e6edf3',           // Code text color
  'editor.background': '#0d1117',          // Code background
  'editor.lineHighlightBackground': '#1c2128',
  'editor.selectionBackground': '#264f78',
  'editor.inactiveSelectionBackground': '#1c2128',
  'editorCursor.foreground': '#ff6b35',    // Orange cursor
  'editorWhitespace.foreground': '#30363d',
  'editorIndentGuide.background': '#30363d',
  'editorIndentGuide.activeBackground': '#404040',
  'editorLineNumber.foreground': '#484f58',
  'editorLineNumber.activeForeground': '#cccccc',
};

// Define the theme rules for Monaco Editor (Light Theme)
window.jacThemeRulesLight = [
  { token: 'keyword.function', foreground: 'ff6b35' },  // Primary orange
  { token: 'keyword.variable', foreground: 'ff6b35' },  // Primary orange
  { token: 'keyword.type', foreground: 'ff6b35' },     // Primary orange
  { token: 'keyword.control', foreground: 'f7931e' },  // Secondary orange
  { token: 'function.identifier', foreground: '000000' }, // Black for functions
  { token: 'type.identifier', foreground: '267F99' },  // Blue for types
  { token: 'operator.logical', foreground: 'ff6b35' },  // Primary orange
  { token: 'string', foreground: 'A31515' },           // Red for strings
  { token: 'number', foreground: '098658' },           // Green for numbers
  { token: 'comment', foreground: '008000' },          // Green for comments
  { token: 'constant.language', foreground: 'f7931e' }, // Secondary orange for True/False/None
  { token: 'operator', foreground: '000000' },         // Black for operators
  { token: 'delimiter.bracket', foreground: '333333' }, // Dark gray for brackets
  { token: 'identifier', foreground: '000000' },       // Black for identifiers
];

// Define the theme colors for Monaco Editor (Light Theme)
window.jacThemeColorsLight = {
  'editor.foreground': '#000000',           // Black text
  'editor.background': '#ffffff',          // White background
  'editor.lineHighlightBackground': '#f0f0f0',
  'editor.selectionBackground': '#add8e6',
  'editor.inactiveSelectionBackground': '#e0e0e0',
  'editorCursor.foreground': '#ff6b35',    // Orange cursor
  'editorWhitespace.foreground': '#d0d0d0',
  'editorIndentGuide.background': '#e0e0e0',
  'editorIndentGuide.activeBackground': '#cccccc',
  'editorLineNumber.foreground': '#237893',
  'editorLineNumber.activeForeground': '#ff6b35',
};

// Backward compatibility
window.jacThemeRules = window.jacThemeRulesDark;
window.jacThemeColors = window.jacThemeColorsDark;