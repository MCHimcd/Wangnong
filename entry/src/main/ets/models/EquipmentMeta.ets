export interface EquipmentMetaItem {
  key: string;
  name: string;
  icon: string;
  controllable: boolean;
  controlType: string;  // "toggle" (on/off) or "slider" (brightness 0-100)
}
