export class AlertData {
  alert_id: string = '';
  type: string = '';
  type_name: string = '';
  level: string = '';
  timestamp: number = 0;
  message: string = '';
  is_handled: boolean = false;
  handle_time: number | null = null;
}
