import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { ServerAvailabilityMode, ServerAvailabilityService } from '../../main/ets/services/ServerAvailabilityService';

export default function serverAvailabilityServiceTest() {
  describe('ServerAvailabilityService', () => {
    beforeEach(() => {
      let svc = ServerAvailabilityService.getInstance();
      svc.resetForTest();
    });

    it('getInstance_returns_same_instance', 0, () => {
      let a = ServerAvailabilityService.getInstance();
      let b = ServerAvailabilityService.getInstance();
      expect(a === b).assertTrue();
    });

    it('recordHealthResult_session_two_failures_triggers_force_logout', 0, () => {
      let svc = ServerAvailabilityService.getInstance();

      let r1 = svc.recordHealthResult(false, ServerAvailabilityMode.SESSION);
      let r2 = svc.recordHealthResult(false, ServerAvailabilityMode.SESSION);

      expect(r1).assertFalse();
      expect(r2).assertTrue();
      expect(svc.getConsecutiveFailures()).assertEqual(0);
      expect(svc.isServerAvailable()).assertFalse();
    });

    it('recordHealthResult_success_resets_failure_counter', 0, () => {
      let svc = ServerAvailabilityService.getInstance();

      svc.recordHealthResult(false, ServerAvailabilityMode.STARTUP);
      svc.recordHealthResult(false, ServerAvailabilityMode.STARTUP);
      expect(svc.getConsecutiveFailures()).assertEqual(2);

      svc.recordHealthResult(true, ServerAvailabilityMode.STARTUP);
      expect(svc.getConsecutiveFailures()).assertEqual(0);
      expect(svc.isServerAvailable()).assertTrue();
    });

    it('status_listener_only_notifies_on_state_change', 0, () => {
      let svc = ServerAvailabilityService.getInstance();
      let changes: boolean[] = [];

      const listener = (available: boolean) => {
        changes.push(available);
      };

      svc.addStatusListener(listener);
      svc.recordHealthResult(false, ServerAvailabilityMode.STARTUP);
      svc.recordHealthResult(false, ServerAvailabilityMode.STARTUP);
      svc.recordHealthResult(true, ServerAvailabilityMode.STARTUP);
      svc.removeStatusListener(listener);

      expect(changes.length).assertEqual(2);
      expect(changes[0]).assertFalse();
      expect(changes[1]).assertTrue();
    });
  });
}