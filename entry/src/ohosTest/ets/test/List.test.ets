import abilityTest from './Ability.test';
// --- Pages ---
import loginPageTest from './pages/LoginPage.test';
import indexPageTest from './pages/Index.test';
import traceabilityScanPageTest from './pages/TraceabilityScanPage.test';
import avatarCropPageTest from './pages/AvatarCropPage.test';
// --- Views ---
import alertViewTest from './views/AlertView.test';
import monitorViewTest from './views/MonitorView.test';
import profileViewTest from './views/ProfileView.test';

export default function testsuite() {
  abilityTest();
  // Pages
  loginPageTest();
  indexPageTest();
  traceabilityScanPageTest();
  avatarCropPageTest();
  // Views
  alertViewTest();
  monitorViewTest();
  profileViewTest();
}