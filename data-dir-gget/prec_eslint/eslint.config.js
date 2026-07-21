export default [
  {
    ignores: [
      "**/external/**", 
      "**/_ds_bundle.js", 
      "node_modules/**",
      "smeXus (smec Design System Remix)/**"
    ]
  },
  {
    files: ["**/*.js", "**/*.jsx", "**/*.ts", "**/*.tsx"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        // Core Browser Globals
        window: "readonly",
        document: "readonly",
        localStorage: "readonly",
        sessionStorage: "readonly",
        navigator: "readonly",
        console: "readonly",
        fetch: "readonly",
        setTimeout: "readonly",
        setInterval: "readonly",
        clearTimeout: "readonly",
        clearInterval: "readonly",
        alert: "readonly",
        confirm: "readonly",
        requestAnimationFrame: "readonly",
        FileReader: "readonly",
        atob: "readonly",
        Blob: "readonly",
        ClipboardItem: "readonly",
        CustomEvent: "readonly",
        
        // Node globals
        process: "readonly",
        __dirname: "readonly",
        
        // Project Third-Party CDN Libraries
        showdown: "readonly",
        bootstrap: "readonly",
        io: "readonly",
        
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
      // Error prevention (Functional correctness)
      "no-undef": "error",
      
      // Best practices
      "eqeqeq": ["error", "always"],
      "no-var": "error",
      
      // Formatting and Aesthetic rule noise disabled (handled by editor auto-formatters, not pre-commit blocks)
      "indent": "off",
      "quotes": "off",
      "semi": "off",
      "prefer-const": "off"
    }
  }
]; 
