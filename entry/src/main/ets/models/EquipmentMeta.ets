/**
 * Purpose: 定义设备控制元数据，描述 UI 渲染和控制能力所需的最小字段。
 * Responsibilities: 提供设备键名、展示名称、图标、是否可控和控件类型。
 * Flow: HttpService 拉取设备元数据后，MonitorView 和任务页据此决定展示方式与交互控件。
 * Input: 后端返回的设备能力描述。
 * Output: EquipmentMetaItem 数组元素。
 * Boundary: controlType 只表达前端控件形态，不直接等同于后端命令类型。
 */
export interface EquipmentMetaItem {
  key: string;
  name: string;
  icon: string;
  controllable: boolean;
  controlType: string;  // "toggle" (on/off) or "slider" (brightness 0-100)
}
