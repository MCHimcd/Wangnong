import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppSize } from '../common/DesignToken';

@Entry
@Component
struct LoginPage {
  @State currentMode: 'login' | 'register' | 'forgot' = 'login';
  @State username: string = '';
  @State password: string = '';
  @State rememberPassword: boolean = false;
  @State autoLogin: boolean = false;
  @State isAutoLoggingIn: boolean = true;
  @State agreedToTerms: boolean = false;
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';

  // 注册/找回专用
  @State phone: string = '';
  @State verifyCode: string = '';
  @State newPassword: string = '';
  @State isSendingCode: boolean = false;
  @State codeCountdown: number = 0;

  private codeTimerId: number = -1;

  private readonly PREF_NAME: string = 'AppPreferences';

  async aboutToAppear() {
    await this.checkAutoLogin();
  }

  aboutToDisappear(): void {
    this.stopCodeTimer();
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

    promptAction.showToast({ message: '验证码已发送（测试固定为1234）' });
    this.startCodeTimer();
  }

  async checkAutoLogin() {
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
        .onClick(() => {
          this.onLoginClick();
        })

      Row() {
        Text('新用户注册')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.Primary)
          .onClick(() => this.currentMode = 'register')
        Text('忘记密码?')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .onClick(() => this.currentMode = 'forgot')
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
          .enabled(!this.isSendingCode && this.codeCountdown === 0)
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
          .enabled(!this.isSendingCode && this.codeCountdown === 0)
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
        .onClick(() => {
          this.onForgotPasswordClick();
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder BrandPanel() {
    Column() {
      Image($r('app.media.app_icon'))
        .width(120)
        .height(120)
        .borderRadius(AppRadius.LG)
        .margin({ bottom: AppSpacing.XL })
      Text('鸿蒙慧田')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextOnPrimary)
        .margin({ bottom: AppSpacing.SM })
      Text('智慧农业 · IoT 监测管理平台')
        .fontSize(AppFontSize.Body)
        .fontColor('rgba(255,255,255,0.8)')
      Text('🌱 实时监控 · 智能预警 · 精准溯源')
        .fontSize(AppFontSize.Caption)
        .fontColor('rgba(255,255,255,0.6)')
        .margin({ top: AppSpacing.MD })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .linearGradient({
      angle: 135,
      colors: [[AppColors.GradientBannerStart, 0], [AppColors.GradientBannerEnd, 1]]
    })
  }

  build() {
    Column() {
      if (this.isAutoLoggingIn) {
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
      } else if (this.currentBreakpoint === 'lg') {
        Row() {
          // 左侧品牌区
          Column() {
            this.BrandPanel()
          }
          .width('42%')
          .height('100%')

          // 右侧表单区
          Column() {
            if (this.currentMode === 'login') {
              this.LoginView()
            } else if (this.currentMode === 'register') {
              this.RegisterView()
            } else if (this.currentMode === 'forgot') {
              this.ForgotView()
            }
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .layoutWeight(1)
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
