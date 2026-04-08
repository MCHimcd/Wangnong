import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { SensorData } from '../../main/ets/models/SensorData';

export default function sensorDataTest() {
  describe('SensorData', () => {
    let sensorData: SensorData;

    beforeEach(() => {
      sensorData = new SensorData();
    });

    it('getValue_returns_zero_for_unknown_key', 0, () => {
      expect(sensorData.getValue('nonexistent')).assertEqual(0);
    });

    it('hasValue_returns_false_for_unknown_key', 0, () => {
      expect(sensorData.hasValue('nonexistent')).assertFalse();
    });

    it('setValue_and_getValue_roundtrip', 0, () => {
      sensorData.setValue('temperature', 25.3);
      expect(sensorData.getValue('temperature')).assertEqual(25.3);
    });

    it('hasValue_returns_true_after_setValue', 0, () => {
      sensorData.setValue('temperature', 25.3);
      expect(sensorData.hasValue('temperature')).assertTrue();
    });

    it('setValue_increments_revision', 0, () => {
      let before = sensorData.revision;
      sensorData.setValue('temperature', 25.3);
      expect(sensorData.revision).assertEqual(before + 1);
    });

    it('multiple_setValue_increments_revision_each_time', 0, () => {
      sensorData.setValue('temperature', 25.3);
      sensorData.setValue('humidity', 68);
      sensorData.setValue('co2', 420);
      expect(sensorData.revision).assertEqual(3);
    });

    it('setValue_overwrites_existing_value', 0, () => {
      sensorData.setValue('temperature', 25.3);
      sensorData.setValue('temperature', 30.0);
      expect(sensorData.getValue('temperature')).assertEqual(30.0);
      expect(sensorData.revision).assertEqual(2);
    });

    it('setValues_batch_writes_all_keys', 0, () => {
      let kvs: Record<string, number> = {};
      kvs['temperature'] = 25.3;
      kvs['humidity'] = 68;
      kvs['co2'] = 420;
      sensorData.setValues(kvs);

      expect(sensorData.getValue('temperature')).assertEqual(25.3);
      expect(sensorData.getValue('humidity')).assertEqual(68);
      expect(sensorData.getValue('co2')).assertEqual(420);
    });

    it('hasValue_returns_true_after_setValues', 0, () => {
      let kvs: Record<string, number> = {};
      kvs['temperature'] = 25.3;
      sensorData.setValues(kvs);

      expect(sensorData.hasValue('temperature')).assertTrue();
      expect(sensorData.hasValue('humidity')).assertFalse();
    });

    it('setValues_increments_revision_once', 0, () => {
      let kvs: Record<string, number> = {};
      kvs['temperature'] = 25.3;
      kvs['humidity'] = 68;
      sensorData.setValues(kvs);

      expect(sensorData.revision).assertEqual(1);
    });

    it('initial_values_is_empty_record', 0, () => {
      expect(Object.keys(sensorData.values).length).assertEqual(0);
    });

    it('initial_revision_is_zero', 0, () => {
      expect(sensorData.revision).assertEqual(0);
    });
  });
}
