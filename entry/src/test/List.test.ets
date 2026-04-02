import localUnitTest from './LocalUnit.test';
// --- Models ---
import sensorDataTest from './models/SensorData.test';
import nodeStateTest from './models/NodeState.test';
import alertDataTest from './models/AlertData.test';
import nodeTest from './models/Node.test';
// --- Services ---
import httpServiceTest from './services/HttpService.test';
import mqttClientServiceTest from './services/MqttClientService.test';
import alertSyncServiceTest from './services/AlertSyncService.test';
import videoMonitorServiceTest from './services/VideoMonitorService.test';
// --- Common ---
import breakpointSystemTest from './common/BreakpointSystem.test';
import appConfigTest from './common/AppConfig.test';
import designTokenTest from './common/DesignToken.test';

export default function testsuite() {
  localUnitTest();
  // Models
  sensorDataTest();
  nodeStateTest();
  alertDataTest();
  nodeTest();
  // Services
  httpServiceTest();
  mqttClientServiceTest();
  alertSyncServiceTest();
  videoMonitorServiceTest();
  // Common
  breakpointSystemTest();
  appConfigTest();
  designTokenTest();
}