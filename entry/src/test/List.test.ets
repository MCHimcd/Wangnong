import localUnitTest from './LocalUnit.test';
// --- Models ---
import sensorDataTest from './models/SensorData.test';
import nodeStateTest from './models/NodeState.test';
import alertDataTest from './models/AlertData.test';
import nodeTest from './models/Node.test';
// --- Services ---
import httpServiceTest from './services/HttpService.test';
import serverAvailabilityServiceTest from './services/ServerAvailabilityService.test';
import mqttClientServiceTest from './services/MqttClientService.test';
import alertSyncServiceTest from './services/AlertSyncService.test';
import videoMonitorServiceTest from './services/VideoMonitorService.test';
// --- Common ---
import breakpointSystemTest from './common/BreakpointSystem.test';
import appConfigTest from './common/AppConfig.test';
import designTokenTest from './common/DesignToken.test';
import traceabilityFlowHelperTest from './common/TraceabilityFlowHelper.test';
import avatarCropMathTest from './common/AvatarCropMath.test';
import avatarCaptureHelperTest from './common/AvatarCaptureHelper.test';

export default function testsuite() {
  localUnitTest();
  // Models
  sensorDataTest();
  nodeStateTest();
  alertDataTest();
  nodeTest();
  // Services
  httpServiceTest();
  serverAvailabilityServiceTest();
  mqttClientServiceTest();
  alertSyncServiceTest();
  videoMonitorServiceTest();
  // Common
  breakpointSystemTest();
  appConfigTest();
  designTokenTest();
  traceabilityFlowHelperTest();
  avatarCropMathTest();
  avatarCaptureHelperTest();
}