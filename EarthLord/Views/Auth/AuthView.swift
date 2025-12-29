import SwiftUI

/// 认证页面（登录/注册）
struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager

    // MARK: - State

    /// 当前选中的 Tab（登录/注册）
    @State private var selectedTab: AuthTab = .login

    /// 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    /// 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    /// 注册流程步骤（1: 邮箱, 2: 验证码, 3: 密码）
    @State private var registerStep = 1

    /// 验证码倒计时
    @State private var otpCountdown = 0
    @State private var otpTimer: Timer?

    /// 忘记密码弹窗
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var forgotOTP = ""
    @State private var forgotNewPassword = ""
    @State private var forgotConfirmPassword = ""
    @State private var forgotStep = 1
    @State private var forgotCountdown = 0
    @State private var forgotTimer: Timer?

    /// Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 60)

                    // Logo 和标题
                    logoSection

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == .login {
                        loginTabContent
                    } else {
                        registerTabContent
                    }

                    // 第三方登录
                    thirdPartyLoginSection

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 30)
            }

            // 加载指示器
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { isVerified in
            if isVerified && selectedTab == .register {
                // 注册验证成功，进入设置密码步骤
                registerStep = 3
            }
        }
        .onChange(of: authManager.errorMessage) { error in
            if let error = error {
                showToastMessage(error)
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 标题
            VStack(spacing: 8) {
                Text("地球新主")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("EARTH LORD")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .tracking(3)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button(action: {
                withAnimation {
                    selectedTab = .login
                    authManager.resetState()
                }
            }) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(selectedTab == .login ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == .login ?
                        ApocalypseTheme.cardBackground : Color.clear
                    )
                    .cornerRadius(8)
            }

            // 注册 Tab
            Button(action: {
                withAnimation {
                    selectedTab = .register
                    authManager.resetState()
                    registerStep = 1
                }
            }) {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(selectedTab == .register ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == .register ?
                        ApocalypseTheme.cardBackground : Color.clear
                    )
                    .cornerRadius(8)
            }
        }
        .padding(4)
        .background(ApocalypseTheme.background)
        .cornerRadius(10)
    }

    // MARK: - Login Tab Content

    private var loginTabContent: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 忘记密码
            HStack {
                Spacer()
                Button("忘记密码？") {
                    showForgotPassword = true
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            }

            // 登录按钮
            Button(action: handleLogin) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
            .opacity((loginEmail.isEmpty || loginPassword.isEmpty) ? 0.5 : 1.0)
        }
    }

    // MARK: - Register Tab Content

    private var registerTabContent: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            StepIndicator(currentStep: registerStep, totalSteps: 3)

            if registerStep == 1 {
                // 第一步：输入邮箱
                registerStep1
            } else if registerStep == 2 {
                // 第二步：输入验证码
                registerStep2
            } else {
                // 第三步：设置密码
                registerStep3
            }
        }
    }

    // MARK: - Register Step 1: Email

    private var registerStep1: some View {
        VStack(spacing: 20) {
            Text("输入邮箱获取验证码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            Button(action: handleSendRegisterOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
            .opacity((registerEmail.isEmpty || !isValidEmail(registerEmail)) ? 0.5 : 1.0)
        }
    }

    // MARK: - Register Step 2: OTP

    private var registerStep2: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(registerEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 6位验证码输入
            OTPInputField(otp: $registerOTP)

            // 验证按钮
            Button(action: handleVerifyRegisterOTP) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerOTP.count != 6)
            .opacity(registerOTP.count != 6 ? 0.5 : 1.0)

            // 重新发送倒计时
            if otpCountdown > 0 {
                Text("\(otpCountdown)秒后可重新发送")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Button("重新发送验证码") {
                    handleSendRegisterOTP()
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - Register Step 3: Password

    private var registerStep3: some View {
        VStack(spacing: 20) {
            Text("设置登录密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "设置密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            Button(action: handleCompleteRegistration) {
                Text("完成注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(!isPasswordValid())
            .opacity(isPasswordValid() ? 1.0 : 0.5)
        }
    }

    // MARK: - Third Party Login

    private var thirdPartyLoginSection: some View {
        VStack(spacing: 20) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted)
                    .frame(height: 1)
                Spacer()
                Text("或者使用以下方式登录")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Rectangle()
                    .fill(ApocalypseTheme.textMuted)
                    .frame(height: 1)
            }

            // Apple 登录
            Button(action: {
                showToastMessage("Apple 登录即将开放")
            }) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("使用 Apple 登录")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录
            Button(action: {
                showToastMessage("Google 登录即将开放")
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("使用 Google 登录")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Forgot Password Sheet

    private var forgotPasswordSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        Spacer()
                            .frame(height: 20)

                        // 步骤指示器
                        StepIndicator(currentStep: forgotStep, totalSteps: 3)

                        if forgotStep == 1 {
                            forgotPasswordStep1
                        } else if forgotStep == 2 {
                            forgotPasswordStep2
                        } else {
                            forgotPasswordStep3
                        }
                    }
                    .padding(.horizontal, 30)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showForgotPassword = false
                        resetForgotPasswordForm()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    private var forgotPasswordStep1: some View {
        VStack(spacing: 20) {
            Text("输入邮箱获取验证码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $forgotEmail,
                keyboardType: .emailAddress
            )

            Button(action: handleSendResetOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(forgotEmail.isEmpty || !isValidEmail(forgotEmail))
            .opacity((forgotEmail.isEmpty || !isValidEmail(forgotEmail)) ? 0.5 : 1.0)
        }
    }

    private var forgotPasswordStep2: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(forgotEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            OTPInputField(otp: $forgotOTP)

            Button(action: handleVerifyResetOTP) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(forgotOTP.count != 6)
            .opacity(forgotOTP.count != 6 ? 0.5 : 1.0)

            if forgotCountdown > 0 {
                Text("\(forgotCountdown)秒后可重新发送")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Button("重新发送验证码") {
                    handleSendResetOTP()
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    private var forgotPasswordStep3: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $forgotNewPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $forgotConfirmPassword
            )

            Button(action: handleResetPassword) {
                Text("重置密码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(!isForgotPasswordValid())
            .opacity(isForgotPasswordValid() ? 1.0 : 0.5)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("加载中...")
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Toast View

    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - Actions

    private func handleLogin() {
        Task {
            await authManager.signIn(email: loginEmail, password: loginPassword)
        }
    }

    private func handleSendRegisterOTP() {
        Task {
            await authManager.sendRegisterOTP(email: registerEmail)
            if authManager.otpSent {
                registerStep = 2
                startOTPCountdown()
            }
        }
    }

    private func handleVerifyRegisterOTP() {
        Task {
            await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
            // 验证成功后会自动触发 onChange，显示第三步
        }
    }

    private func handleCompleteRegistration() {
        Task {
            await authManager.completeRegistration(password: registerPassword)
        }
    }

    private func handleSendResetOTP() {
        Task {
            await authManager.sendResetOTP(email: forgotEmail)
            if authManager.otpSent {
                forgotStep = 2
                startForgotCountdown()
            }
        }
    }

    private func handleVerifyResetOTP() {
        Task {
            await authManager.verifyResetOTP(email: forgotEmail, code: forgotOTP)
            if authManager.otpVerified {
                forgotStep = 3
            }
        }
    }

    private func handleResetPassword() {
        Task {
            await authManager.resetPassword(newPassword: forgotNewPassword)
            if authManager.isAuthenticated {
                showForgotPassword = false
                resetForgotPasswordForm()
            }
        }
    }

    // MARK: - Helper Methods

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isPasswordValid() -> Bool {
        return registerPassword.count >= 6 &&
               registerPassword == registerConfirmPassword
    }

    private func isForgotPasswordValid() -> Bool {
        return forgotNewPassword.count >= 6 &&
               forgotNewPassword == forgotConfirmPassword
    }

    private func startOTPCountdown() {
        otpCountdown = 60
        otpTimer?.invalidate()
        otpTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if otpCountdown > 0 {
                otpCountdown -= 1
            } else {
                otpTimer?.invalidate()
            }
        }
    }

    private func startForgotCountdown() {
        forgotCountdown = 60
        forgotTimer?.invalidate()
        forgotTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if forgotCountdown > 0 {
                forgotCountdown -= 1
            } else {
                forgotTimer?.invalidate()
            }
        }
    }

    private func resetForgotPasswordForm() {
        forgotEmail = ""
        forgotOTP = ""
        forgotNewPassword = ""
        forgotConfirmPassword = ""
        forgotStep = 1
        forgotCountdown = 0
        forgotTimer?.invalidate()
        authManager.resetState()
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - Supporting Types

enum AuthTab {
    case login
    case register
}

// MARK: - Custom Components

/// 自定义文本输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }
}

/// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }
}

/// 6位验证码输入框
struct OTPInputField: View {
    @Binding var otp: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.cardBackground)
                        .frame(width: 45, height: 55)

                    if index < otp.count {
                        Text(String(otp[otp.index(otp.startIndex, offsetBy: index)]))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
        }
        .overlay(
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .onChange(of: otp) { newValue in
                    otp = String(newValue.prefix(6))
                }
        )
    }
}

/// 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager(supabase: SupabaseConfig.shared))
}
