import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { NodeState } from '../../main/ets/models/NodeState';

export default function nodeStateTest() {
  describe('NodeState', () => {
    let nodeState: NodeState;

    beforeEach(() => {
      nodeState = new NodeState();
    });

    it('getState_returns_false_for_unknown_key', 0, () => {
      expect(nodeState.getState('nonexistent')).assertFalse();
    });

    it('hasState_returns_false_for_unknown_key', 0, () => {
      expect(nodeState.hasState('nonexistent')).assertFalse();
    });

    it('setState_and_getState_roundtrip_true', 0, () => {
      nodeState.setState('water_pump', true);
      expect(nodeState.getState('water_pump')).assertTrue();
    });

    it('hasState_returns_true_after_setState', 0, () => {
      nodeState.setState('water_pump', true);
      expect(nodeState.hasState('water_pump')).assertTrue();
    });

    it('setState_and_getState_roundtrip_false', 0, () => {
      nodeState.setState('water_pump', true);
      nodeState.setState('water_pump', false);
      expect(nodeState.getState('water_pump')).assertFalse();
    });

    it('setState_increments_revision', 0, () => {
      let before = nodeState.revision;
      nodeState.setState('fan', true);
      expect(nodeState.revision).assertEqual(before + 1);
    });

    it('multiple_setState_increments_correctly', 0, () => {
      nodeState.setState('water_pump', true);
      nodeState.setState('fan', false);
      nodeState.setState('led_light', true);
      expect(nodeState.revision).assertEqual(3);
    });

    it('initial_smartMode_is_false', 0, () => {
      expect(nodeState.smartMode).assertFalse();
    });

    it('initial_controlStateBootstrapped_is_false', 0, () => {
      expect(nodeState.controlStateBootstrapped).assertFalse();
    });

    it('initial_revision_is_zero', 0, () => {
      expect(nodeState.revision).assertEqual(0);
    });

    it('smartMode_can_be_toggled', 0, () => {
      nodeState.smartMode = true;
      expect(nodeState.smartMode).assertTrue();
      nodeState.smartMode = false;
      expect(nodeState.smartMode).assertFalse();
    });

    it('initial_equipmentStates_is_empty', 0, () => {
      expect(Object.keys(nodeState.equipmentStates).length).assertEqual(0);
    });
  });
}
