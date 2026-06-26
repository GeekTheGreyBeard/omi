import nextVitals from 'eslint-config-next/core-web-vitals';

const eslintConfig = [
  ...nextVitals,
  {
    ignores: ['.next/**', 'node_modules/**', 'out/**', 'next-env.d.ts'],
  },
  {
    rules: {
      /*
       * The React Compiler rules below are useful migration signals, but this
       * legacy web app is not compiler-clean yet. Keep the hard lint gate on
       * correctness rules while the compiler migration is handled deliberately.
       */
      'react-hooks/immutability': 'off',
      'react-hooks/preserve-manual-memoization': 'off',
      'react-hooks/purity': 'off',
      'react-hooks/set-state-in-effect': 'off',
      'react-hooks/static-components': 'off',
    },
  },
];

export default eslintConfig;
