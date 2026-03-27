module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
  extends: ["eslint:recommended", "google"],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    quotes: "off",
    "quote-props": "off",
    "max-len": "off",
    indent: "off",
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "no-inner-declarations": "off",
    "no-unused-vars": "warn",
    "object-curly-spacing": "off",
    "comma-dangle": "off",
    camelcase: "off",
    "new-cap": "off",
    "space-before-function-paren": "off",
    "operator-linebreak": "off",
    "padded-blocks": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
