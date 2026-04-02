import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { AlertData } from '../../main/ets/models/AlertData';
import { createMockAlert, createHandledAlert } from '../testutils/TestHelpers';

export default function alertDataTest() {
  describe('AlertData', () => {

    it('default_values_are_correct', 0, () => {
      let alert = new AlertData();
      expect(alert.alert_id).assertEqual('');
      expect(alert.type).assertEqual('');
      expect(alert.type_name).assertEqual('');
      expect(alert.level).assertEqual('');
      expect(alert.timestamp).assertEqual(0);
      expect(alert.message).assertEqual('');
      expect(alert.source).assertEqual('environment');
      expect(alert.source_name).assertEqual('环境监测');
      expect(alert.is_handled).assertFalse();
      expect(alert.handle_time).assertNull();
    });

    it('factory_creates_valid_alert', 0, () => {
      let alert = createMockAlert('ALT_001', 'critical', 1711900000);
      expect(alert.alert_id).assertEqual('ALT_001');
      expect(alert.level).assertEqual('critical');
      expect(alert.timestamp).assertEqual(1711900000);
      expect(alert.is_handled).assertFalse();
    });

    it('handled_factory_sets_handled_fields', 0, () => {
      let alert = createHandledAlert('ALT_002', 1711900000);
      expect(alert.is_handled).assertTrue();
      expect(alert.handle_time).assertEqual(1711960000);
    });

    it('properties_can_be_reassigned', 0, () => {
      let alert = new AlertData();
      alert.alert_id = 'ALT_003';
      alert.level = 'warning';
      alert.is_handled = true;
      alert.handle_time = 9999;

      expect(alert.alert_id).assertEqual('ALT_003');
      expect(alert.level).assertEqual('warning');
      expect(alert.is_handled).assertTrue();
      expect(alert.handle_time).assertEqual(9999);
    });

    it('source_defaults_to_environment', 0, () => {
      let alert = new AlertData();
      expect(alert.source).assertEqual('environment');
      expect(alert.source_name).assertEqual('环境监测');
    });
  });
}
