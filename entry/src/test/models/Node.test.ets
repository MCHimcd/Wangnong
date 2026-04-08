import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { Node } from '../../main/ets/models/Node';
import { SensorData } from '../../main/ets/models/SensorData';
import { NodeState } from '../../main/ets/models/NodeState';

export default function nodeTest() {
  describe('Node', () => {
    let node: Node;

    beforeEach(() => {
      node = new Node('A03_Node_01', '温室一号');
    });

    it('constructor_sets_id_and_name', 0, () => {
      expect(node.id).assertEqual('A03_Node_01');
      expect(node.name).assertEqual('温室一号');
    });

    it('status_defaults_to_offline', 0, () => {
      expect(node.status).assertEqual('offline');
    });

    it('constructor_accepts_status', 0, () => {
      let onlineNode = new Node('A03_Node_02', '温室二号', 'online');
      expect(onlineNode.status).assertEqual('online');
    });

    it('constructor_creates_sensorData_instance', 0, () => {
      expect(node.sensorData instanceof SensorData).assertTrue();
    });

    it('constructor_creates_nodeState_instance', 0, () => {
      expect(node.nodeState instanceof NodeState).assertTrue();
    });

    it('sensorMeta_defaults_to_empty_array', 0, () => {
      expect(node.sensorMeta.length).assertEqual(0);
    });

    it('equipmentMeta_defaults_to_empty_array', 0, () => {
      expect(node.equipmentMeta.length).assertEqual(0);
    });

    it('sensorData_setValue_through_node', 0, () => {
      node.sensorData.setValue('temperature', 25.3);
      expect(node.sensorData.getValue('temperature')).assertEqual(25.3);
      expect(node.sensorData.revision).assertEqual(1);
    });

    it('nodeState_setState_through_node', 0, () => {
      node.nodeState.setState('water_pump', true);
      expect(node.nodeState.getState('water_pump')).assertTrue();
      expect(node.nodeState.revision).assertEqual(1);
    });

    it('two_nodes_have_independent_sensorData', 0, () => {
      let node2 = new Node('A03_Node_02', '温室二号');
      node.sensorData.setValue('temperature', 25.3);
      node2.sensorData.setValue('temperature', 30.0);

      expect(node.sensorData.getValue('temperature')).assertEqual(25.3);
      expect(node2.sensorData.getValue('temperature')).assertEqual(30.0);
    });

    it('two_nodes_have_independent_nodeState', 0, () => {
      let node2 = new Node('A03_Node_02', '温室二号');
      node.nodeState.setState('fan', true);
      node2.nodeState.setState('fan', false);

      expect(node.nodeState.getState('fan')).assertTrue();
      expect(node2.nodeState.getState('fan')).assertFalse();
    });
  });
}
