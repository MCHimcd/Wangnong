/**
 * Purpose: 统一定义 Wangnong 的设计令牌，作为所有页面和视图的视觉基础。
 * Responsibilities: 提供颜色、字号、间距、圆角、阴影和尺寸常量，约束 UI 不直接硬编码样式值。
 * Flow: 页面、视图和组件在构建 UI 时直接引用这些常量；README 中的设计规范也以此文件为准。
 * Dependencies: 被 entry/src/main/ets 下几乎所有 UI 文件导入使用。
 * Input: 无运行时输入。
 * Output: 各类只读设计常量。
 * Invariant: 新增视觉规则应优先扩展此文件，而不是在页面中引入散落的数值字面量。
 */

// ==================== 配色 ====================
export class AppColors {
  // --- 主色 ---
  static readonly Primary: string = '#2E7D32';
  static readonly PrimaryLight: string = '#4CAF50';
  static readonly PrimaryDark: string = '#1B5E20';
  static readonly PrimaryBg: string = '#E8F5E9';

  // --- 科技点缀色 ---
  static readonly Accent: string = '#00ACC1';
  static readonly AccentBg: string = '#E0F7FA';

  // --- 表面/背景 ---
  static readonly Surface: string = '#FFFFFF';
  static readonly Background: string = '#F0F4F1';
  static readonly SidebarBg: string = '#1B3A26';
  static readonly SidebarActive: string = '#2E5C3A';
  static readonly OverlayBg: string = 'rgba(0,0,0,0.35)';

  // --- 文字 ---
  static readonly TextPrimary: string = '#1B2631';
  static readonly TextSecondary: string = '#546E7A';
  static readonly TextTertiary: string = '#90A4AE';
  static readonly TextOnPrimary: string = '#FFFFFF';
  static readonly TextOnSidebar: string = 'rgba(255,255,255,0.72)';
  static readonly TextOnSidebarActive: string = '#FFFFFF';

  // --- 边框/分割线 ---
  static readonly Border: string = '#E0E0E0';
  static readonly Divider: string = '#ECEFF1';

  // --- 告警 ---
  static readonly AlertCritical: string = '#D32F2F';
  static readonly AlertCriticalBg: string = '#FFEBEE';
  static readonly AlertWarning: string = '#F57C00';
  static readonly AlertWarningBg: string = '#FFF3E0';
  static readonly AlertInfo: string = '#0288D1';
  static readonly AlertInfoBg: string = '#E1F5FE';
  static readonly Success: string = '#2E7D32';
  static readonly SuccessBg: string = '#E8F5E9';

  // --- 设备状态 ---
  static readonly DeviceOn: string = '#2E7D32';
  static readonly DeviceOnBg: string = '#E5F3E7';
  static readonly DeviceOnBorder: string = '#81C784';
  static readonly DeviceOff: string = '#78909C';
  static readonly DeviceOffBg: string = '#F5F5F5';
  static readonly DeviceOffBorder: string = '#CFD8DC';

  // --- 图表 ---
  static readonly ChartLine1: string = '#2E7D32';
  static readonly ChartLine2: string = '#00ACC1';
  static readonly ChartLine3: string = '#F57C00';
  static readonly ChartGrid: string = '#ECEFF1';

  // --- 渐变 (用字符串描述, 在需要时手动拆分) ---
  static readonly GradientPrimaryStart: string = '#2E7D32';
  static readonly GradientPrimaryEnd: string = '#4CAF50';
  static readonly GradientAccentStart: string = '#00ACC1';
  static readonly GradientAccentEnd: string = '#26C6DA';
  static readonly GradientBannerStart: string = '#1B5E20';
  static readonly GradientBannerEnd: string = '#388E3C';
}

// ==================== 字体 ====================
export class AppFontSize {
  static readonly Hero: number = 32;   // 登录页大标题
  static readonly H1: number = 24;     // 页面标题
  static readonly H2: number = 20;     // 区块标题
  static readonly H3: number = 16;     // 卡片标题 / 菜单项
  static readonly Body: number = 14;   // 正文
  static readonly Caption: number = 12; // 辅助 / 时间
  static readonly Mini: number = 10;   // 极小标注
}

// ==================== 间距 ====================
export class AppSpacing {
  static readonly XS: number = 4;
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 20;
  static readonly XXL: number = 28;
  static readonly PagePadding: number = 16;
  static readonly CardPadding: number = 16;
  static readonly SectionGap: number = 14;
}

// ==================== 圆角 ====================
export class AppRadius {
  static readonly SM: number = 8;
  static readonly MD: number = 12;
  static readonly LG: number = 16;
  static readonly XL: number = 20;
  static readonly Full: number = 999;
}

// ==================== 阴影 ====================
export class AppShadow {
  static readonly CardRadius: number = 16;
  static readonly CardColor: string = 'rgba(30,70,40,0.06)';
  static readonly CardOffsetY: number = 4;

  static readonly ElevatedRadius: number = 24;
  static readonly ElevatedColor: string = 'rgba(30,70,40,0.10)';
  static readonly ElevatedOffsetY: number = 8;
}

// ==================== 尺寸 ====================
export class AppSize {
  static readonly InputHeight: number = 48;
  static readonly ButtonHeight: number = 44;
  static readonly ButtonHeightSM: number = 32;
  static readonly AvatarLG: number = 88;
  static readonly AvatarMD: number = 48;
  static readonly AvatarSM: number = 32;
  static readonly IconCircle: number = 40;
  static readonly TabBarHeight: number = 56;
  static readonly SidebarWidth: number = 240;
  static readonly StatusDotSize: number = 8;
}
