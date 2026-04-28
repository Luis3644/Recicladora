module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    // --- SOLUCIÓN NINJA AQUÍ ---
    "no-unused-vars": "off",      // Ignora variables no usadas (como onRequest)
    "max-len": "off",              // Ignora líneas largas
    "require-jsdoc": "off",        // No te pide comentarios aburridos
    "linebreak-style": "off",      // Ignora el error de Windows (CRLF vs LF)
    "object-curly-spacing": "off", // Ignora espacios en llaves { likeThis }
    "indent": "off"                // No se queja por los espacios/tabs
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
