export default [
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        // Browser globals
        window: "readonly",
        document: "readonly",
        localStorage: "readonly",
        console: "readonly",
        fetch: "readonly",
        setTimeout: "readonly",
        setInterval: "readonly",
        clearTimeout: "readonly",
        clearInterval: "readonly",
        // Node globals
        process: "readonly",
        __dirname: "readonly",
        // Markdown
        showdown: "readonly",
        // ES2022 globals
        Promise: "readonly",
        Map: "readonly",
        Set: "readonly",
        URL: "readonly",
        URLSearchParams: "readonly",
        FormData: "readonly",
        Headers: "readonly",
        Request: "readonly",
        Response: "readonly",
        TextDecoder: "readonly",
        TextEncoder: "readonly"
      }
    },
    rules: {
      // Error prevention
      "no-undef": "error",
    //   "no-unused-vars": "warn", // false positives when used in html and js is separate files
      
      // Style consistency 
      "semi": ["error", "always"],
      "quotes": ["error", "single"],
      "indent": ["error", 2],
      
      // Best practices
      "eqeqeq": ["error", "always"],
      "no-var": "error",
      "prefer-const": "warn",
    //   "no-console": "warn" // i am ok with console.log
    }
  }
]; 