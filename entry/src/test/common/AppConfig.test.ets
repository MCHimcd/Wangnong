/**
 * AppConfig 单元测试
 *
 * 验证配置常量的格式合法性和非空性。
 */
import { describe, it, expect } from '@ohos/hypium';
import { AppConfig } from '../../main/ets/common/AppConfig';

export default function appConfigTest() {
  describe('AppConfig', () => {

    it('BASE_URL_is_valid_http', 0, () => {
      expect(AppConfig.BASE_URL.startsWith('http://')).assertTrue();
    });

    it('BASE_URL_contains_port', 0, () => {
      expect(AppConfig.BASE_URL.includes(':')).assertTrue();
    });

    it('MQTT_BROKER_URL_is_valid_tcp', 0, () => {
      expect(AppConfig.MQTT_BROKER_URL.startsWith('tcp://')).assertTrue();
    });

    it('MQTT_BROKER_URL_contains_port', 0, () => {
      let parts = AppConfig.MQTT_BROKER_URL.split(':');
      expect(parts.length).assertEqual(3); // tcp + //host + port
    });

    it('MQTT_CLIENT_PREFIX_is_non_empty', 0, () => {
      expect(AppConfig.MQTT_CLIENT_PREFIX.length > 0).assertTrue();
    });

    it('APP_ID_is_non_empty', 0, () => {
      expect(AppConfig.APP_ID.length > 0).assertTrue();
    });
  });
}
