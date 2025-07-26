using System.Text.Encodings.Web;
using System.Text.Unicode;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.EntityFrameworkCore;
using test2.Models;
using test2.Services;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.AspNetCore.Authentication.Facebook;
using test2.Models.ManagementModels.Services;

var facebookAppId = Environment.GetEnvironmentVariable("FACEBOOK_APP_ID");
var facebookAppSecret = Environment.GetEnvironmentVariable("FACEBOOK_APP_SECRET");
var googleClentId = Environment.GetEnvironmentVariable("GOOGLE_CLIENT_ID");
var googleClientSecret = Environment.GetEnvironmentVariable("GOOGLE_CLIENT_SECRET");

var builder = WebApplication.CreateBuilder(args);

#region 註冊自訂服務 和 增加外部驗證設定
// 註冊 ActivityService
builder.Services.AddScoped<ActivityService>();

// 註冊 AnnouncementService
builder.Services.AddScoped<AnnouncementService>();

// 註冊 AnnouncementService
builder.Services.AddScoped<UserService>();

// cookie service ( Google 驗證設定)
builder.Services.AddAuthentication(options => // 修改：將 AddAuthentication 調整為接收 options 委派
{
    // 設定預設的驗證方案為 Cookie 認證
    options.DefaultAuthenticateScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultSignInScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    // 設定預設的挑戰方案為 Google 驗證，當需要外部登入時會使用
    options.DefaultChallengeScheme = GoogleDefaults.AuthenticationScheme;
})

.AddGoogle(googleOptions => // 新增：Google 驗證設定
{
    googleOptions.ClientId = googleClentId!;
    googleOptions.ClientSecret = googleClientSecret!;

    // 設定要向 Google 請求的使用者資料範圍
    // "profile" 包含姓名、頭像等基本資料
    // "email" 包含使用者的電子郵件地址
    googleOptions.Scope.Add("profile");
    googleOptions.Scope.Add("email");
})

.AddFacebook(facebookOptions => // 新增：Facebook 驗證設定
{
    facebookOptions.AppId = facebookAppId!;
    facebookOptions.AppSecret = facebookAppSecret!;

    // 只要求公開個人資料 (包含姓名)。
    // Facebook 的 'public_profile' 範圍預設包含姓名。
    facebookOptions.Scope.Add("public_profile");
    facebookOptions.Scope.Add("email");
});
#endregion

//database service
builder.Services.AddDbContext<Test2Context>(options => options.UseSqlServer(builder.Configuration.GetConnectionString("Test2ConnString")));

// Add services to the container.
builder.Services.AddControllersWithViews().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = null;
    options.JsonSerializerOptions.Encoder = JavaScriptEncoder.Create(UnicodeRanges.All);
});

//memory service
builder.Services.AddDistributedMemoryCache();

//主要逾期預約排程
builder.Services.AddHostedService<ScheduleServices>();

//session service
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromSeconds(10);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

//cookie service
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie(options =>
{
    options.ExpireTimeSpan = TimeSpan.FromHours(1);
    options.SlidingExpiration = true;
    options.LoginPath = "/Frontend/Home/Index";
    options.ExpireTimeSpan = TimeSpan.FromMinutes(10);
    options.SlidingExpiration = true;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseRouting();

app.MapStaticAssets();

//session start
app.UseSession();

//cookie start
app.UseAuthentication();
app.UseAuthorization();

//fronted area
app.MapControllerRoute(
    name: "FrontendArea",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}",
    defaults: new { area = "Frontend" }
);

//backed area
app.MapControllerRoute(
    name: "BackendArea",
    pattern: "{area:exists}/{controller=Manage}/{action=Index}/{id?}",
    defaults: new { area = "Backend" }
);

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}").WithStaticAssets();

app.Run();