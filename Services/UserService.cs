using Microsoft.EntityFrameworkCore;

using test2.Models;
using test2.Areas.Frontend.Models.Dtos;

using Isopoh.Cryptography.Argon2;


namespace test2.Services
{
    public class RegisterResult
    {
        public bool IsSuccess;
        public string FailMessage = "無錯誤訊息";
        public string SuccessMessage = "無成功訊息";
    }
    public class UserService
    {
        private readonly Test2Context _dbContext;

        public UserService(Test2Context dbContext)
        {
            _dbContext = dbContext;
        }

        /// <summary>
        /// 使用 EF core 將新的用戶資料傳入資料庫
        /// </summary>
        /// 
        public async Task<RegisterResult> UserRegister(string phoneNumber, string email, string password)
        {
            RegisterResult result = new RegisterResult();

            var foundUser = await _dbContext.Clients.FirstOrDefaultAsync(c => c.CAccount == email);

            if (foundUser != null)
            {
                result.IsSuccess = false;
                result.FailMessage = "電子信箱已經註冊過";
                return result;
            }

            else 
            {
                var newUser = new Client
                {
                    CName = string.Empty,
                    CAccount = email,
                    CPassword = Argon2.Hash(password), // 使用 Argon2 加密
                    CPhone = phoneNumber,
                    Permission = 1
                };

                _dbContext.Clients.Add(newUser);
                await _dbContext.SaveChangesAsync();

                result.IsSuccess = true;
                result.SuccessMessage = "註冊成功！";

                return result;
            }
        }
    }
}
