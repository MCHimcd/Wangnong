/**
 * DesignToken 单元测试
 *
 * 验证设计规范常量的格式和有效性，防止误改。
 */
import { describe, it, expect } from '@ohos/hypium';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../../main/ets/common/DesignToken';

export default function designTokenTest() {
  describe('DesignToken', () => {

    // ===== AppColors 色值格式 =====
    it('primary_color_is_hex', 0, () => {
      expect(AppColors.Primary.startsWith('#')).assertTrue();
      expect(AppColors.Primary.length).assertEqual(7);
    });

    it('alert_critical_is_hex', 0, () => {
      expect(AppColors.AlertCritical.startsWith('#')).assertTrue();
    });

    it('overlay_bg_is_rgba', 0, () => {
      expect(AppColors.OverlayBg.startsWith('rgba(')).assertTrue();
    });

    it('surface_is_white', 0, () => {
      expect(AppColors.Surface).assertEqual('#FFFFFF');
    });

    // ===== AppFontSize 有效性 =====
    it('font_sizes_are_positive', 0, () => {
      expect(AppFontSize.Hero > 0).assertTrue();
      expect(AppFontSize.H1 > 0).assertTrue();
      expect(AppFontSize.H2 > 0).assertTrue();
      expect(AppFontSize.H3 > 0).assertTrue();
      expect(AppFontSize.Body > 0).assertTrue();
      expect(AppFontSize.Caption > 0).assertTrue();
      expect(AppFontSize.Mini > 0).assertTrue();
    });

    it('font_sizes_descending_order', 0, () => {
      expect(AppFontSize.Hero > AppFontSize.H1).assertTrue();
      expect(AppFontSize.H1 > AppFontSize.H2).assertTrue();
      expect(AppFontSize.H2 > AppFontSize.H3).assertTrue();
      expect(AppFontSize.H3 > AppFontSize.Body).assertTrue();
      expect(AppFontSize.Body > AppFontSize.Caption).assertTrue();
      expect(AppFontSize.Caption > AppFontSize.Mini).assertTrue();
    });

    // ===== AppSpacing 有效性 =====
    it('spacings_are_non_negative', 0, () => {
      expect(AppSpacing.XS >= 0).assertTrue();
      expect(AppSpacing.SM >= 0).assertTrue();
      expect(AppSpacing.MD >= 0).assertTrue();
      expect(AppSpacing.LG >= 0).assertTrue();
      expect(AppSpacing.XL >= 0).assertTrue();
      expect(AppSpacing.XXL >= 0).assertTrue();
      expect(AppSpacing.PagePadding >= 0).assertTrue();
    });

    it('spacings_ascending_order', 0, () => {
      expect(AppSpacing.XS < AppSpacing.SM).assertTrue();
      expect(AppSpacing.SM < AppSpacing.MD).assertTrue();
      expect(AppSpacing.MD < AppSpacing.LG).assertTrue();
      expect(AppSpacing.LG < AppSpacing.XL).assertTrue();
      expect(AppSpacing.XL < AppSpacing.XXL).assertTrue();
    });

    // ===== AppRadius 有效性 =====
    it('radii_are_non_negative', 0, () => {
      expect(AppRadius.SM >= 0).assertTrue();
      expect(AppRadius.MD >= 0).assertTrue();
      expect(AppRadius.LG >= 0).assertTrue();
      expect(AppRadius.XL >= 0).assertTrue();
      expect(AppRadius.Full >= 0).assertTrue();
    });

    it('radii_ascending_order', 0, () => {
      expect(AppRadius.SM < AppRadius.MD).assertTrue();
      expect(AppRadius.MD < AppRadius.LG).assertTrue();
      expect(AppRadius.LG < AppRadius.XL).assertTrue();
      expect(AppRadius.XL < AppRadius.Full).assertTrue();
    });

    // ===== AppShadow 有效性 =====
    it('shadow_radius_positive', 0, () => {
      expect(AppShadow.CardRadius > 0).assertTrue();
      expect(AppShadow.ElevatedRadius > 0).assertTrue();
    });

    // ===== AppSize 有效性 =====
    it('sizes_are_positive', 0, () => {
      expect(AppSize.InputHeight > 0).assertTrue();
      expect(AppSize.ButtonHeight > 0).assertTrue();
      expect(AppSize.TabBarHeight > 0).assertTrue();
      expect(AppSize.SidebarWidth > 0).assertTrue();
    });
  });
}
