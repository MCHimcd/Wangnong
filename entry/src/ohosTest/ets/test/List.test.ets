import abilityTest from './Ability.test';
// --- Pages ---
import loginPageTest from './pages/LoginPage.test';
import indexPageTest from './pages/Index.test';
// --- Views ---
import alertViewTest from './views/AlertView.test';
import monitorViewTest from './views/MonitorView.test';

export default function testsuite() {
  abilityTest();
  // Pages
  loginPageTest();
  indexPageTest();
  // Views
  alertViewTest();
  monitorViewTest();
}