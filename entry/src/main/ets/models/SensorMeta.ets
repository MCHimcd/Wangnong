/**
 * Purpose: 定义传感器指标元数据，描述监控卡片和图表展示所需的字段。
 * Responsibilities: 提供指标键名、名称、单位、图标、配色及预警阈值。
 * Flow: Index 从后端拉取 sensor-meta 后，MonitorView 和 SensorDetailPage 依据这些字段组织 UI 和告警样式。
 * Input: 后端下发的传感器能力描述。
 * Output: SensorMetaItem 数组元素。
 * Boundary: warningMin / warningMax 仅表示展示和前端预警边界，不替代后端真实告警规则。
 */
export interface SensorMetaItem {
  key: string;
  name: string;
  unit: string;
  icon: string;
  badgeColor: string;
  bgColor: string;
  warningMin?: number;
  warningMax?: number;
}
