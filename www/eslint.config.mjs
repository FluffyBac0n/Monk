import { defineConfig, globalIgnores } from 'eslint/config';
import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTs from 'eslint-config-next/typescript';

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // Vinext's current Next Link client handler crashes at runtime; native
    // anchors preserve reliable navigation until that compatibility bug lands.
    rules: {
      '@next/next/no-html-link-for-pages': 'off',
    },
  },
  globalIgnores(['.next/**', 'out/**', 'build/**', 'public/vendor/**', 'next-env.d.ts']),
]);

export default eslintConfig;
