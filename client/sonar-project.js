const scanner = require('sonarqube-scanner');

scanner(
  {
    serverUrl: 'http://sonarqube-sonarqube:9000',
    //token: "019d1e2e04eefdcd0caee1468f39a45e69d33d3f",
    options: {
      'sonar.login': 'admin',
      'sonar.password': 'admin',
      'sonar.projectName': 'Curriki UI',
      'sonar.projectDescription': 'Curriki UI',
      'sonar.projectVersion': '0.1.0',
      'sonar.sources': 'src',
      'sonar.tests': 'src',
      'sonar.inclusions': '**', // Entry point of your code
      'sonar.test.inclusions': 'src/**/*.spec.js,src/**/*.spec.ts,src/**/*.spec.jsx,src/**/*.test.js,src/**/*.test.jsx',
      'sonar.exclusions': '**/node_modules/**',
      //'sonar.javascript.lcov.reportPaths': 'reports/lcov.info',
      //'sonar.testExecutionReportPaths': 'coverage/test-reporter.xml'
    }
  },
  () => process.exit()
);
