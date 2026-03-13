export class AlertData {
  alert_id: string = '';
  type: string = '';
  type_name: string = '';
  level: string = '';
  timestamp: number = 0;
  message: string = '';
  source: string = 'environment';
  source_name: string = '环境监测';
  is_handled: boolean = false;
  handle_time: number | null = null;
}
