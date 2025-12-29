# AuthManager 使用说明

## 📁 文件结构

```
EarthLord/
├── Models/
│   └── User.swift                    # 用户模型
├── Services/
│   ├── SupabaseConfig.swift          # Supabase 配置
│   └── AuthManager.swift             # 认证管理器
```

## 🚀 快速开始

### 1. 在 App 中初始化 AuthManager

```swift
import SwiftUI

@main
struct EarthLordApp: App {
    // 创建 AuthManager 实例
    @StateObject private var authManager = AuthManager(
        supabase: SupabaseConfig.shared
    )

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                // 已登录，显示主界面
                MainTabView()
                    .environmentObject(authManager)
            } else if authManager.needsPasswordSetup {
                // 需要设置密码
                SetPasswordView()
                    .environmentObject(authManager)
            } else {
                // 未登录，显示登录页
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
```

## 📝 使用示例

### 注册流程

```swift
struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var otpCode = ""
    @State private var password = ""

    var body: some View {
        VStack {
            if !authManager.otpSent {
                // 步骤 1: 输入邮箱，发送验证码
                TextField("邮箱", text: $email)
                Button("发送验证码") {
                    Task {
                        await authManager.sendRegisterOTP(email: email)
                    }
                }
            } else if !authManager.otpVerified {
                // 步骤 2: 输入验证码
                TextField("验证码", text: $otpCode)
                Button("验证") {
                    Task {
                        await authManager.verifyRegisterOTP(
                            email: email,
                            code: otpCode
                        )
                    }
                }
            }
        }
    }
}

struct SetPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack {
            SecureField("设置密码", text: $password)
            SecureField("确认密码", text: $confirmPassword)

            Button("完成注册") {
                guard password == confirmPassword else {
                    authManager.errorMessage = "密码不一致"
                    return
                }
                Task {
                    await authManager.completeRegistration(password: password)
                }
            }
        }
    }
}
```

### 登录流程

```swift
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack {
            TextField("邮箱", text: $email)
            SecureField("密码", text: $password)

            Button("登录") {
                Task {
                    await authManager.signIn(
                        email: email,
                        password: password
                    )
                }
            }

            // 错误提示
            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
    }
}
```

### 找回密码流程

```swift
struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var otpCode = ""
    @State private var newPassword = ""

    var body: some View {
        VStack {
            if !authManager.otpSent {
                // 步骤 1: 发送重置验证码
                TextField("邮箱", text: $email)
                Button("发送验证码") {
                    Task {
                        await authManager.sendResetOTP(email: email)
                    }
                }
            } else if !authManager.otpVerified {
                // 步骤 2: 验证验证码
                TextField("验证码", text: $otpCode)
                Button("验证") {
                    Task {
                        await authManager.verifyResetOTP(
                            email: email,
                            code: otpCode
                        )
                    }
                }
            } else if authManager.needsPasswordSetup {
                // 步骤 3: 设置新密码
                SecureField("新密码", text: $newPassword)
                Button("重置密码") {
                    Task {
                        await authManager.resetPassword(
                            newPassword: newPassword
                        )
                    }
                }
            }
        }
    }
}
```

### 退出登录

```swift
Button("退出登录") {
    Task {
        await authManager.signOut()
    }
}
```

### 检查会话（启动时）

```swift
struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView("检查登录状态...")
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await authManager.checkSession()
        }
    }
}
```

## 🔑 状态属性说明

| 属性 | 类型 | 说明 |
|------|------|------|
| `isAuthenticated` | Bool | 用户是否已完全认证（已登录且完成所有步骤） |
| `needsPasswordSetup` | Bool | 是否需要设置密码 |
| `currentUser` | User? | 当前登录用户信息 |
| `isLoading` | Bool | 是否正在加载 |
| `errorMessage` | String? | 错误信息 |
| `otpSent` | Bool | 验证码是否已发送 |
| `otpVerified` | Bool | 验证码是否已验证 |

## 📋 认证流程图

### 注册流程
```
输入邮箱 → 发送OTP → 输入验证码 → 验证成功（已登录） → 设置密码 → 完成注册
```

### 登录流程
```
输入邮箱+密码 → 登录成功 → 进入主页
```

### 找回密码流程
```
输入邮箱 → 发送重置OTP → 输入验证码 → 验证成功 → 设置新密码 → 完成重置
```

## ⚠️ 重要注意事项

1. **OTP 验证后的状态**
   - `verifyOTP` 成功后，用户已经登录到 Supabase
   - 但 `isAuthenticated` 保持 `false`，直到完成密码设置
   - 这确保注册流程必须完成密码设置

2. **密码重置的 OTP 类型**
   - 注册使用 `.email` 类型
   - 密码重置使用 `.recovery` 类型
   - 不要混淆！

3. **错误处理**
   - 所有异步方法都会捕获错误并设置 `errorMessage`
   - UI 应该监听 `errorMessage` 并显示给用户

4. **会话管理**
   - 应用启动时调用 `checkSession()` 恢复登录状态
   - Supabase 会自动处理 token 刷新

## 🔄 状态重置

在切换不同认证流程时，调用 `resetState()` 清空状态：

```swift
Button("返回登录") {
    authManager.resetState()
}
```

## 🎯 下一步

- 实现具体的 UI 界面（LoginView、RegisterView 等）
- 添加表单验证（邮箱格式、密码强度等）
- 实现 Apple/Google 第三方登录
- 添加用户资料编辑功能
