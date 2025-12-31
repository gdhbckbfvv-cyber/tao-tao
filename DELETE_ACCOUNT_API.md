# 删除账户 API 文档

## 边缘函数信息

- **函数名称**: `delete-account`
- **URL**: `https://vlfvceeqwnahwcnbahth.supabase.co/functions/v1/delete-account`
- **方法**: POST
- **版本**: 3
- **状态**: ✅ ACTIVE

## 功能说明

此边缘函数允许已认证用户删除自己的账户。删除操作：
- 验证用户身份（通过 JWT token）
- 要求明确确认（`confirm: true`）
- 使用 service_role 权限删除用户
- 返回详细的成功/错误响应

## API 调用方式

### 请求

```http
POST https://vlfvceeqwnahwcnbahth.supabase.co/functions/v1/delete-account
Authorization: Bearer <USER_ACCESS_TOKEN>
Content-Type: application/json

{
  "confirm": true
}
```

### 请求参数

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| confirm | boolean | 是 | 必须设置为 `true` 以确认删除操作 |

### 请求头

| Header | 值 | 说明 |
|--------|-----|------|
| Authorization | Bearer <token> | 用户的 JWT access token |
| Content-Type | application/json | 请求体格式 |

## 响应格式

### 成功响应 (200 OK)

```json
{
  "success": true,
  "message": "Account deleted successfully",
  "deleted_user_id": "254514f1-6eca-42c2-871a-6b4f6728e06a",
  "deleted_email": "user@example.com"
}
```

### 错误响应

#### 401 Unauthorized - 未提供认证信息

```json
{
  "error": "Missing authorization header"
}
```

#### 401 Unauthorized - Token 无效

```json
{
  "error": "Invalid or expired token",
  "details": "JWT expired"
}
```

#### 400 Bad Request - 未确认删除

```json
{
  "error": "Confirmation required",
  "message": "Please set \"confirm\": true in the request body to delete your account"
}
```

#### 405 Method Not Allowed - 使用了错误的 HTTP 方法

```json
{
  "error": "Method not allowed"
}
```

#### 500 Internal Server Error - 删除失败

```json
{
  "error": "Failed to delete account",
  "details": "具体错误信息"
}
```

## Swift 代码示例

### 调用删除账户函数

```swift
import Supabase

class AccountManager {
    let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// 删除当前用户账户
    func deleteAccount() async throws {
        // 获取当前会话
        let session = try await supabase.auth.session

        // 调用删除账户边缘函数
        let response: DeleteAccountResponse = try await supabase.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                body: ["confirm": true]
            )
        )

        print("账户已删除: \\(response.deletedUserId)")
    }
}

// 响应结构
struct DeleteAccountResponse: Codable {
    let success: Bool
    let message: String
    let deletedUserId: String
    let deletedEmail: String

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case deletedUserId = "deleted_user_id"
        case deletedEmail = "deleted_email"
    }
}
```

### 在 UI 中使用

```swift
struct SettingsView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Button("删除账户", role: .destructive) {
            showDeleteConfirmation = true
        }
        .alert("确认删除账户？", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("此操作无法撤销。您的所有数据将被永久删除。")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil

        do {
            let accountManager = AccountManager(supabase: supabase)
            try await accountManager.deleteAccount()

            // 删除成功，退出登录或导航到欢迎页面
            print("账户已成功删除")
        } catch {
            errorMessage = "删除账户失败: \\(error.localizedDescription)"
        }

        isDeleting = false
    }
}
```

## cURL 测试示例

```bash
# 1. 先登录获取 access token
ACCESS_TOKEN=$(curl -s -X POST "https://vlfvceeqwnahwcnbahth.supabase.co/auth/v1/token?grant_type=password" \\
  -H "apikey: sb_publishable_zIKWJgysMWGtqXRVGEMpsQ_Ln7COtmo" \\
  -H "Content-Type: application/json" \\
  -d '{"email":"user@example.com","password":"password123"}' \\
  | jq -r '.access_token')

# 2. 调用删除账户函数
curl -X POST "https://vlfvceeqwnahwcnbahth.supabase.co/functions/v1/delete-account" \\
  -H "Authorization: Bearer $ACCESS_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{"confirm": true}'
```

## 注意事项

⚠️ **重要提示**：

1. **不可逆操作**: 账户删除后无法恢复，所有用户数据将被永久删除
2. **立即生效**: 删除操作立即生效，用户会话将失效
3. **级联删除**: 根据数据库配置，相关联的用户数据（如 profiles、territories 等）可能会被级联删除
4. **需要确认**: 必须在请求体中包含 `"confirm": true`，否则请求会被拒绝
5. **安全性**: 函数已禁用自动 JWT 验证，采用手动验证方式以确保兼容性

## 测试脚本

测试脚本位于: `/Users/Zhuanz/Desktop/test_delete_account.sh`

使用方法:
```bash
./test_delete_account.sh <email> <password>
```

## 部署信息

- **项目 ID**: vlfvceeqwnahwcnbahth
- **函数 ID**: 03963a70-a828-4ddc-b492-2a8ae8eaf030
- **当前版本**: 3
- **部署时间**: 2025-12-31
- **JWT 验证**: 手动验证（verify_jwt: false）
- **CORS**: 已启用，允许所有来源

## 日志和监控

查看函数日志:
```bash
# 在 Supabase Dashboard 中
# Edge Functions → delete-account → Logs
```

或使用 Supabase CLI:
```bash
supabase functions logs delete-account
```
