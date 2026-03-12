import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State rememberPassword: boolean = false;
  @State autoLogin: boolean = false;
  @State isAutoLoggingIn: boolean = true;
  private readonly PREF_NAME: string = 'AppPreferences';

  async aboutToAppear() {
    await this.checkAutoLogin();
  }

  async checkAutoLogin() {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let dataPreferences = await preferences.getPreferences(context, this.PREF_NAME);
      let savedUsername = await dataPreferences.get('username', '') as string;
      let savedPassword = await dataPreferences.get('password', '') as string;
      let savedRememberPassword = await dataPreferences.get('rememberPassword', false) as boolean;
      let savedAutoLogin = await dataPreferences.get('autoLogin', false) as boolean;

      if (savedAutoLogin && savedUsername === 'admin' && savedPassword === '123456') {
        // Validation passes
        router.replaceUrl({ url: 'pages/Index' });
        return;
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
    if (this.username === 'admin' && this.password === '123456') {
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
      router.replaceUrl({ url: 'pages/Index' });
    } else {
      promptAction.showToast({ message: '用户名或密码错误' });
    }
  }

  build() {
    Column() {
      if (this.isAutoLoggingIn) {
        LoadingProgress()
          .width(80)
          .height(80)
      } else {
        Text('系统登录')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 100, bottom: 50 })

        TextInput({ placeholder: '请输入用户名 (默认 admin)', text: this.username })
          .type(InputType.Normal)
          .width('80%')
          .height(50)
          .margin({ bottom: 20 })
          .onChange((value: string) => {
            this.username = value;
          })

        TextInput({ placeholder: '请输入密码 (默认 123456)', text: this.password })
          .type(InputType.Password)
          .width('80%')
          .height(50)
          .margin({ bottom: 20 })
          .onChange((value: string) => {
            this.password = value;
          })

        Row() {
          Row() {
            Checkbox({ name: 'rememberPassword', group: 'login' })
              .select(this.rememberPassword)
              .onChange((value: boolean) => {
                this.rememberPassword = value;
                if (!value) {
                  this.autoLogin = false; // 如果取消记住密码，自动登录也必须取消
                }
              })
            Text('记住密码')
              .fontSize(16)
              .fontColor('#666')
          }.margin({ right: 20 })

          Row() {
            Checkbox({ name: 'autoLogin', group: 'login' })
              .select(this.autoLogin)
              .onChange((value: boolean) => {
                this.autoLogin = value;
                if (value) {
                  this.rememberPassword = true; // 如果开启自动登录，必须记住密码
                }
              })
            Text('自动登录')
              .fontSize(16)
              .fontColor('#666')
          }
        }
        .width('80%')
        .margin({ bottom: 30 })
        .justifyContent(FlexAlign.SpaceBetween)

        Button('登录')
          .width('80%')
          .height(50)
          .backgroundColor('#4CAF50')
          .onClick(() => {
            this.onLoginClick();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
