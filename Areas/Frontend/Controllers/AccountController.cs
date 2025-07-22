using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.AspNetCore.Authentication.Facebook;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

[Area("Frontend")]
public class AccountController : Controller
{
    /// <summary>
    /// 啟動外部登入流程 (例如 Google 或 Facebook)
    /// </summary>
    /// <param name="provider">外部驗證提供者的名稱 (例如 "Google", "Facebook")</param>
    /// <returns></returns>
    [HttpPost]
    public IActionResult ExternalLogin(string provider)
    {
        // 建立 AuthenticationProperties 物件，指定登入成功後要重新導向的 URI
        var redirectUrl = Url.Action("ExternalLoginCallback", "Account", new { Area = "Frontend" });
        var properties = new AuthenticationProperties { RedirectUri = redirectUrl };

        // 觸發外部驗證流程
        // provider 會是 "Google" 或 "Facebook" (ASP.NET Core 會自動對應到 GoogleDefaults.AuthenticationScheme 或 FacebookDefaults.AuthenticationScheme)
        return Challenge(properties, provider);
    }

    /// <summary>
    /// 處理外部登入完成後的回呼
    /// 外部驗證提供者會將使用者導向到在其平台上設定的 /signin-google 或 /signin-facebook
    /// 然後 ASP.NET Core 的驗證中介軟體會處理它，並將使用者導向到這個 ExternalLoginCallback
    /// </summary>
    /// <returns></returns>
    [HttpGet]
    public async Task<IActionResult> ExternalLoginCallback()
    {
        // 嘗試取得外部登入的驗證結果
        // 這會從暫存的外部認證資訊中讀取。
        // 使用 CookieAuthenticationDefaults.AuthenticationScheme 是因為外部驗證成功後，
        // ASP.NET Core 會將外部身份暫時儲存在一個內部 Cookie 中，並使用預設的 Cookie 方案來讀取。
        var authenticateResult = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);

        // 如果沒有成功驗證，可能原因：使用者取消登入、網路問題等
        if (!authenticateResult.Succeeded)
        {
            // 導回登入頁面或其他錯誤頁面，並顯示錯誤訊息
            TempData["ErrorMessage"] = "外部登入失敗。";
            return RedirectToAction("LoginC", "Access", new { Area = "Frontend" });
        }

        // 取得外部登入的使用者身份資訊 (Claims)
        // 這些 Claims 包含了來自外部提供者的使用者資料，例如 Name, Email 等
        var externalClaims = authenticateResult.Principal.Claims;

        // **重要：在這裡處理你的應用程式登入邏輯**
        // 根據 externalClaims 來判斷這個外部帳號是否已經存在於你的系統中
        // 範例邏輯：
        // 1. 取得外部提供者的 User ID (通常是 ClaimTypes.NameIdentifier) 和 Email (ClaimTypes.Email)
        string externalUserId = externalClaims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier)?.Value;
        string email = externalClaims.FirstOrDefault(c => c.Type == ClaimTypes.Email)?.Value;
        string name = externalClaims.FirstOrDefault(c => c.Type == ClaimTypes.Name)?.Value;
        string providerName = authenticateResult.Properties?.Items[".AuthScheme"];

        // 2. 檢查你的資料庫中是否有這個 email 或外部 User ID 的使用者
        //    假設你有一個 UserService 或 Repository 來處理使用者資料
        //    var existingUser = _userService.GetUserByEmail(email);

        // 3. 如果沒有，則表示是新使用者，你可以自動註冊一個新帳號
        //    if (existingUser == null)
        //    {
        //        _userService.RegisterNewUser(externalUserId, email, name, providerName); // 儲存到你的資料庫
        //    }

        // 4. 然後為這個使用者在你的應用程式中建立一個新的身份 (ClaimsPrincipal)
        //    這裡只是簡單地將外部的 Claims 複製一份，並用 Cookie 方案重新登入

        var claimsIdentity = new ClaimsIdentity(externalClaims, CookieAuthenticationDefaults.AuthenticationScheme);
        var authProperties = new AuthenticationProperties
        {
            IsPersistent = true, // 設定 Cookie 是否為持久性 (例如：記住我)，讓使用者下次不用再登入
            ExpiresUtc = DateTimeOffset.UtcNow.AddHours(24) // 設定 Cookie 的過期時間，例如 24 小時
        };

        // 使用 HttpContext.SignInAsync() 讓使用者在應用程式中正式登入
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(claimsIdentity), authProperties);

        // 登入成功後，導向到首頁或其他需要登入才能訪問的頁面
        // TempData 可以傳遞一次性訊息到下一個請求的 View
        TempData["LoginSuccessMessage"] = $"您已成功使用 {providerName} 登入！歡迎 {name}。";
        return RedirectToAction("Index", "Home", new { Area = "Frontend" });
    }

    /// <summary>
    /// 登出功能
    /// </summary>
    /// <returns></returns>
    [HttpPost]
    [ValidateAntiForgeryToken] // 加上防偽造標記，避免 CSRF 攻擊
    public async Task<IActionResult> Logout()
    {
        // 清除所有驗證 Cookie，讓使用者登出
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

        // 登出後導向到首頁或登入頁面
        return RedirectToAction("LoginC", "Access", new { Area = "Frontend" });
    }

    /// <summary>
    /// 範例：顯示登入使用者資訊的頁面 (如果有需要的話)
    /// </summary>
    [HttpGet]
    [Microsoft.AspNetCore.Authorization.Authorize] // 只有登入後才能訪問
    public IActionResult Profile()
    {
        // 如果使用者已登入，這裡的 User 物件會有他們的 Claims
        return View(); // 可以顯示使用者名稱、電子郵件等資訊
    }
}