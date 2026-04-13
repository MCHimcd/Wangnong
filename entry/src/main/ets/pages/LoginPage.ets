import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';
import { ServerAvailabilityMode, ServerAvailabilityService } from '../services/ServerAvailabilityService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppSize } from '../common/DesignToken';

/**
 * Purpose: 承载登录、注册、找回密码和自动登录入口，并在进入应用前统一处理服务器可用性检查。
 * Responsibilities: 管理认证表单状态、验证码倒计时、自动登录偏好、协议同意状态和服务器恢复后的重试逻辑。
 * Flow: aboutToAppear() 调用 initializePage() 启动 startup 探活；服务器可用时再执行 checkAutoLogin() 或手动登录/注册流程。
 * Dependencies: 依赖 HttpService 完成认证请求，依赖 Preferences 保存自动登录信息，依赖 ServerAvailabilityService 管理启动阶段探活。
 * Input: 用户输入的账号、密码、手机号、验证码以及本地偏好数据。
 * Output: 登录相关 UI、自动登录结果，以及成功后跳转到 Index。
 * Side Effects: 读写 Preferences、写入 AppStorage、展示服务器不可用提示和验证码倒计时。
 */
@Entry
@Component
struct LoginPage {
  @State currentMode: 'login' | 'register' | 'forgot' = 'login';
  @State username: string = '';
  @State password: string = '';
  @State rememberPassword: boolean = false;
  @State autoLogin: boolean = false;
  @State isAutoLoggingIn: boolean = true;
  @State isCheckingServer: boolean = true;
  @State serverAvailable: boolean = false;
  @State agreedToTerms: boolean = false;

  // 注册/找回专用
  @State phone: string = '';
  @State verifyCode: string = '';
  @State newPassword: string = '';
  @State isSendingCode: boolean = false;
  @State codeCountdown: number = 0;

  private codeTimerId: number = -1;
  private pendingAutoLoginAfterRecovery: boolean = true;

  private readonly PREF_NAME: string = 'AppPreferences';
  private readonly availabilityService: ServerAvailabilityService = ServerAvailabilityService.getInstance();
  private readonly onServerStatusChanged = (available: boolean): void => {
    this.serverAvailable = available;
    if (!available) {
      return;
    }
    // Reason: 只有“服务器恢复”“当前不在自动登录中”“启动探活已结束”三个条件同时满足时，才允许补做自动登录。
    if (this.pendingAutoLoginAfterRecovery && !this.isAutoLoggingIn && !this.isCheckingServer) {
      this.pendingAutoLoginAfterRecovery = false;
      this.isAutoLoggingIn = true;
      void this.checkAutoLogin();
    }
  };

  async aboutToAppear() {
    this.availabilityService.addStatusListener(this.onServerStatusChanged);
    await this.initializePage();
  }

  aboutToDisappear(): void {
    this.stopCodeTimer();
    this.availabilityService.removeStatusListener(this.onServerStatusChanged);
    this.availabilityService.stopPolling();
  }

  private async initializePage(): Promise<void> {
    // Flow: 启动页先确认服务器可用，再决定是否自动登录；这样能避免在服务不可用时直接触发无意义的认证请求。
    this.isCheckingServer = true;
    this.isAutoLoggingIn = false;
    this.pendingAutoLoginAfterRecovery = true;

    const available = await this.availabilityService.startStartupPolling();
    this.serverAvailable = available;
    this.isCheckingServer = false;

    if (!available) {
      this.isAutoLoggingIn = false;
      promptAction.showToast({ message: '服务器不可用，登录相关功能已禁用' });
      return;
    }

    this.pendingAutoLoginAfterRecovery = false;
    this.isAutoLoggingIn = true;
    await this.checkAutoLogin();
  }

  async onRetryServerClick() {
    if (this.isCheckingServer) {
      return;
    }
    this.isCheckingServer = true;
    const available = await this.availabilityService.retryNow(ServerAvailabilityMode.STARTUP);
    this.serverAvailable = available;
    this.isCheckingServer = false;
    if (!available) {
      promptAction.showToast({ message: '服务器仍不可用，请稍后重试' });
    }
  }

  private stopCodeTimer(): void {
    if (this.codeTimerId !== -1) {
      clearInterval(this.codeTimerId);
      this.codeTimerId = -1;
    }
  }

  private startCodeTimer(): void {
    this.stopCodeTimer();
    this.codeCountdown = 60;
    // Boundary: 倒计时既是 UX 反馈，也是前端节流，避免在验证码接口未做更强限流时被重复点击淹没。
    this.codeTimerId = setInterval(() => {
      if (this.codeCountdown <= 1) {
        this.codeCountdown = 0;
        this.stopCodeTimer();
        return;
      }
      this.codeCountdown -= 1;
    }, 1000);
  }

  async onSendVerifyCodeClick() {
    if (!this.serverAvailable) {
      promptAction.showToast({ message: '服务器不可用，暂时无法发送验证码' });
      return;
    }
    const phone = this.phone.trim();
    if (phone.length === 0) {
      promptAction.showToast({ message: '请先输入手机号' });
      return;
    }
    if (this.codeCountdown > 0 || this.isSendingCode) {
      return;
    }

    this.isSendingCode = true;
    const ok = await HttpService.getInstance().sendVerificationCode(phone);
    this.isSendingCode = false;

    if (!ok) {
      promptAction.showToast({ message: '验证码发送失败，请稍后重试' });
      return;
    }

    // Boundary: 当前提示明确说明验证码为测试固定值，后续接入真实短信网关时应同步移除该 mock 说明。
    promptAction.showToast({ message: '验证码已发送（测试固定为1234）' });
    this.startCodeTimer();
  }

  async checkAutoLogin() {
    // Flow: 自动登录失败时不会阻塞页面，而是回填已保存账号信息，退回到可手动登录的状态。
    if (!this.serverAvailable) {
      this.isAutoLoggingIn = false;
      return;
    }
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let dataPreferences = await preferences.getPreferences(context, this.PREF_NAME);
      let savedUsername = await dataPreferences.get('username', '') as string;
      let savedPassword = await dataPreferences.get('password', '') as string;
      let savedRememberPassword = await dataPreferences.get('rememberPassword', false) as boolean;
      let savedAutoLogin = await dataPreferences.get('autoLogin', false) as boolean;

      if (savedAutoLogin && savedUsername && savedPassword) {
        let res = await HttpService.getInstance().login(savedUsername, savedPassword);
        if (res && res.token) {
          HttpService.getInstance().setToken(res.token);
          let profile = await HttpService.getInstance().getUserProfile();
          AppStorage.setOrCreate('userRole', profile?.role || 'user');
          AppStorage.setOrCreate('isLoggedIn', true);
          router.replaceUrl({ url: 'pages/Index' });
          return;
        }
      }
      
      // Setup default text from pref
      if (savedRememberPassword) {
        this.username = savedUsername;
        this.password = savedPassword;
      }
      this.rememberPassword = savedRememberPassword;
      this.autoLogin = savedAutoLogin;

    } catch (err) {
      console.error(`Failed to get preferences. Code:${err.code},message:${err.message}`);
    }
    
    // Stop the loading indicator
    this.isAutoLoggingIn = false;
  }

  async onLoginClick() {
    if (!this.serverAvailable) {
      promptAction.showToast({ message: '服务器不可用，暂时无法登录' });
      return;
    }
    if (!this.agreedToTerms) {
      promptAction.showToast({ message: '请先阅读并同意用户协议与隐私政策' });
      return;
    }
    
    let res = await HttpService.getInstance().login(this.username, this.password);
    if (res && res.token) {
      HttpService.getInstance().setToken(res.token);
      try {
        let context = getContext(this) as common.UIAbilityContext;
        let dataPreferences = await preferences.getPreferences(context, this.PREF_NAME);
        
        // Boundary: autoLogin 依赖 rememberPassword 持有同一份凭据，因此两者任一为 true 时都要保留用户名和密码。
        if (this.rememberPassword || this.autoLogin) {
          await dataPreferences.put('username', this.username);
          await dataPreferences.put('password', this.password);
        } else {
          await dataPreferences.delete('username');
          await dataPreferences.delete('password');
        }
        
        await dataPreferences.put('rememberPassword', this.rememberPassword);
        await dataPreferences.put('autoLogin', this.autoLogin);
        await dataPreferences.flush();
      } catch (err) {
        console.error(`Failed to save preferences. Code:${err.code},message:${err.message}`);
      }
      
      promptAction.showToast({ message: '登录成功' });
      let profile = await HttpService.getInstance().getUserProfile();
      AppStorage.setOrCreate('userRole', profile?.role || 'user');
      AppStorage.setOrCreate('isLoggedIn', true);
      router.replaceUrl({ url: 'pages/Index' });
    } else {
      promptAction.showToast({ message: '用户名或密码错误' });
    }
  }

  async onRegisterClick() {
    if (!this.serverAvailable) {
      promptAction.showToast({ message: '服务器不可用，暂时无法注册' });
      return;
    }
    if (!this.agreedToTerms) {
      promptAction.showToast({ message: '请先同意用户协议与隐私政策' });
      return;
    }
    if (!this.phone || !this.verifyCode || !this.newPassword) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }

    const registerSuccess = await HttpService.getInstance().register(this.phone, this.verifyCode, this.newPassword);
    if (!registerSuccess) {
      promptAction.showToast({ message: '注册失败，请稍后重试' });
      return;
    }

    let loginRes = await HttpService.getInstance().login(this.phone, this.newPassword);
    if (loginRes && loginRes.token) {
      HttpService.getInstance().setToken(loginRes.token);
      AppStorage.setOrCreate('isLoggedIn', true);
      promptAction.showToast({ message: '注册并登录成功' });
      router.replaceUrl({ url: 'pages/Index' });
      return;
    }

    // 如果自动登录失败，回到登录态并回填账号密码
    promptAction.showToast({ message: '注册成功，请登录' });
    this.username = this.phone;
    this.password = this.newPassword;
    this.currentMode = 'login';
  }

  async onForgotPasswordClick() {
    if (!this.serverAvailable) {
      promptAction.showToast({ message: '服务器不可用，暂时无法找回密码' });
      return;
    }
    if (!this.phone || !this.verifyCode || !this.newPassword) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }

    const success = await HttpService.getInstance().forgotPassword(this.phone, this.verifyCode, this.newPassword);
    if (!success) {
      promptAction.showToast({ message: '密码修改失败，请稍后重试' });
      return;
    }

    promptAction.showToast({ message: '密码修改成功，请重新登录' });
    this.username = this.phone;
    this.password = this.newPassword;
    this.currentMode = 'login';
  }

  @Builder TermsCheckbox() {
    Row() {
      Checkbox({ name: 'terms', group: 'terms' })
        .select(this.agreedToTerms)
        .shape(CheckBoxShape.CIRCLE)
        .onChange((value: boolean) => {
          this.agreedToTerms = value;
        })
      Text('已阅读并同意')
        .fontSize(AppFontSize.Caption)
        .fontColor(AppColors.TextTertiary)
      Text('《用户协议》')
        .fontSize(AppFontSize.Caption)
        .fontColor(AppColors.Primary)
        .onClick(() => router.pushUrl({ url: 'pages/AgreementPage', params: { type: 'user' } }))
      Text('与')
        .fontSize(AppFontSize.Caption)
        .fontColor(AppColors.TextTertiary)
      Text('《隐私政策》')
        .fontSize(AppFontSize.Caption)
        .fontColor(AppColors.Primary)
        .onClick(() => router.pushUrl({ url: 'pages/AgreementPage', params: { type: 'privacy' } }))
    }
    .width('80%')
    .margin({ top: AppSpacing.SM, bottom: AppSpacing.LG })
    .justifyContent(FlexAlign.Center)
  }

  @Builder LoginView() {
    Column() {
      // Logo
      Image($r('app.media.app_icon'))
        .width(100)
        .height(100)
        .borderRadius(AppRadius.LG)
        .margin({ top: 40, bottom: AppSpacing.LG })

      Text('鸿蒙慧田')
        .fontSize(AppFontSize.Hero)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.SM })
      Text('智慧农业 · IoT 管理平台')
        .fontSize(AppFontSize.Caption)
        .fontColor(AppColors.TextTertiary)
        .margin({ bottom: 36 })

      if (!this.serverAvailable) {
        this.ServerUnavailableHint()
      }

      TextInput({ placeholder: '请输入用户名或手机号', text: this.username })
        .type(InputType.Normal)
        .width('80%')
        .height(AppSize.InputHeight)
        .margin({ bottom: AppSpacing.LG })
        .borderRadius(AppRadius.MD)
        .onChange((value: string) => {
          this.username = value;
        })

      TextInput({ placeholder: '请输入密码', text: this.password })
        .type(InputType.Password)
        .width('80%')
        .height(AppSize.InputHeight)
        .margin({ bottom: AppSpacing.LG })
        .borderRadius(AppRadius.MD)
        .onChange((value: string) => {
          this.password = value;
        })

      Row() {
        Row() {
          Checkbox({ name: 'rememberPassword', group: 'login' })
            .select(this.rememberPassword)
            .onChange((value: boolean) => {
              this.rememberPassword = value;
              if (!value) this.autoLogin = false;
            })
          Text('记住密码').fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
        }.margin({ right: AppSpacing.MD })

        Row() {
          Checkbox({ name: 'autoLogin', group: 'login' })
            .select(this.autoLogin)
            .onChange((value: boolean) => {
              this.autoLogin = value;
              if (value) this.rememberPassword = true;
            })
          Text('自动登录').fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
        }
      }
      .width('80%')
      .margin({ bottom: AppSpacing.XL })
      .justifyContent(FlexAlign.Start)

      Button('登录')
        .width('80%')
        .height(AppSize.ButtonHeight)
        .backgroundColor(AppColors.Primary)
        .borderRadius(AppRadius.MD)
        .fontSize(AppFontSize.Body)
        .enabled(this.serverAvailable)
        .onClick(() => {
          this.onLoginClick();
        })

      Row() {
        Text('新用户注册')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.Primary)
          .opacity(this.serverAvailable ? 1 : 0.5)
          .onClick(() => {
            if (this.serverAvailable) {
              this.currentMode = 'register';
            }
          })
        Text('忘记密码?')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .opacity(this.serverAvailable ? 1 : 0.5)
          .onClick(() => {
            if (this.serverAvailable) {
              this.currentMode = 'forgot';
            }
          })
      }
      .width('80%')
      .margin({ top: AppSpacing.LG })
      .justifyContent(FlexAlign.SpaceBetween)

      Blank()
      this.TermsCheckbox()
    }
    .width('100%')
    .height('100%')
  }

  @Builder RegisterView() {
    Column() {
      // 头部返回
      Row() {
        Text('← 返回登录')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextSecondary)
          .onClick(() => this.currentMode = 'login')
        Blank()
      }
      .width('90%')
      .margin({ top: AppSpacing.LG, bottom: 36 })

      Text('新用户注册')
        .fontSize(AppFontSize.Hero)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: 36 })
        .width('80%')
        .textAlign(TextAlign.Start)

      if (!this.serverAvailable) {
        this.ServerUnavailableHint()
      }

      TextInput({ placeholder: '请输入手机号', text: this.phone })
        .type(InputType.PhoneNumber)
        .width('80%')
        .height(AppSize.InputHeight)
        .borderRadius(AppRadius.MD)
        .margin({ bottom: AppSpacing.LG })
        .onChange((value: string) => this.phone = value)

      Row() {
        TextInput({ placeholder: '请输入验证码', text: this.verifyCode })
          .type(InputType.Number)
          .width('60%')
          .height(AppSize.InputHeight)
          .borderRadius(AppRadius.MD)
          .onChange((value: string) => this.verifyCode = value)
        Button(this.codeCountdown > 0 ? `${this.codeCountdown}s` : (this.isSendingCode ? '发送中' : '获取'))
          .width('35%')
          .height(AppSize.InputHeight)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.MD)
          .enabled(this.serverAvailable && !this.isSendingCode && this.codeCountdown === 0)
          .onClick(() => {
            void this.onSendVerifyCodeClick();
          })
      }
      .width('80%')
      .margin({ bottom: AppSpacing.LG })
      .justifyContent(FlexAlign.SpaceBetween)

      TextInput({ placeholder: '请设置密码', text: this.newPassword })
        .type(InputType.Password)
        .width('80%')
        .height(AppSize.InputHeight)
        .borderRadius(AppRadius.MD)
        .margin({ bottom: 36 })
        .onChange((value: string) => this.newPassword = value)

      Button('注册并登录')
        .width('80%')
        .height(AppSize.ButtonHeight)
        .backgroundColor(AppColors.Primary)
        .borderRadius(AppRadius.MD)
        .fontSize(AppFontSize.Body)
        .enabled(this.serverAvailable)
        .onClick(() => {
          this.onRegisterClick();
        })

      Blank()
      this.TermsCheckbox()
    }
    .width('100%')
    .height('100%')
  }

  @Builder ForgotView() {
    Column() {
      // 头部返回
      Row() {
        Text('← 返回登录')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextSecondary)
          .onClick(() => this.currentMode = 'login')
        Blank()
      }
      .width('90%')
      .margin({ top: AppSpacing.LG, bottom: 36 })

      Text('找回密码')
        .fontSize(AppFontSize.Hero)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: 36 })
        .width('80%')
        .textAlign(TextAlign.Start)

      if (!this.serverAvailable) {
        this.ServerUnavailableHint()
      }

      TextInput({ placeholder: '请输入手机号', text: this.phone })
        .type(InputType.PhoneNumber)
        .width('80%')
        .height(AppSize.InputHeight)
        .borderRadius(AppRadius.MD)
        .margin({ bottom: AppSpacing.LG })
        .onChange((value: string) => this.phone = value)

      Row() {
        TextInput({ placeholder: '请输入验证码', text: this.verifyCode })
          .type(InputType.Number)
          .width('60%')
          .height(AppSize.InputHeight)
          .borderRadius(AppRadius.MD)
          .onChange((value: string) => this.verifyCode = value)
        Button(this.codeCountdown > 0 ? `${this.codeCountdown}s` : (this.isSendingCode ? '发送中' : '获取'))
          .width('35%')
          .height(AppSize.InputHeight)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.MD)
          .enabled(this.serverAvailable && !this.isSendingCode && this.codeCountdown === 0)
          .onClick(() => {
            void this.onSendVerifyCodeClick();
          })
      }
      .width('80%')
      .margin({ bottom: AppSpacing.LG })
      .justifyContent(FlexAlign.SpaceBetween)

      TextInput({ placeholder: '请输入新密码', text: this.newPassword })
        .type(InputType.Password)
        .width('80%')
        .height(AppSize.InputHeight)
        .borderRadius(AppRadius.MD)
        .margin({ bottom: 36 })
        .onChange((value: string) => this.newPassword = value)

      Button('确认修改')
        .width('80%')
        .height(AppSize.ButtonHeight)
        .backgroundColor(AppColors.Primary)
        .borderRadius(AppRadius.MD)
        .fontSize(AppFontSize.Body)
        .enabled(this.serverAvailable)
        .onClick(() => {
          this.onForgotPasswordClick();
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder ServerUnavailableHint() {
    Row() {
      Text('服务器连接不可用，登录相关功能暂不可用')
        .fontSize(AppFontSize.Caption)
        .fontColor(AppColors.AlertCritical)
        .layoutWeight(1)

      Button(this.isCheckingServer ? '检查中' : '重试')
        .height(AppSize.ButtonHeightSM)
        .backgroundColor(AppColors.AlertWarning)
        .fontSize(AppFontSize.Caption)
        .enabled(!this.isCheckingServer)
        .onClick(() => {
          void this.onRetryServerClick();
        })
    }
    .width('80%')
    .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.SM, bottom: AppSpacing.SM })
    .margin({ bottom: AppSpacing.MD })
    .backgroundColor(AppColors.AlertCriticalBg)
    .borderRadius(AppRadius.MD)
  }

  build() {
    Column() {
      if (this.isCheckingServer) {
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .color(AppColors.Primary)
          Text('正在检查服务器...')
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.TextTertiary)
            .margin({ top: AppSpacing.MD })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.isAutoLoggingIn) {
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .color(AppColors.Primary)
          Text('正在登录...')
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.TextTertiary)
            .margin({ top: AppSpacing.MD })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        if (this.currentMode === 'login') {
          this.LoginView()
        } else if (this.currentMode === 'register') {
          this.RegisterView()
        } else if (this.currentMode === 'forgot') {
          this.ForgotView()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
