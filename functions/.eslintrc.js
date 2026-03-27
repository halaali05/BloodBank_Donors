module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: ["eslint:recommended", "google"],
  parserOptions: {
    ecmaVersion: 2020,
  },
  rules: {
    "max-len": "off",
    "require-jsdoc": "off",
    "no-inner-declarations": "off",
    "no-unused-vars": "warn",
    quotes: "off",
    "quote-props": "off",
    indent: "off", // ← أضف هذا السطر
  },
};
