using System.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.VisualStudio.Web.CodeGenerators.Mvc.Templates.BlazorIdentity.Pages.Manage;
using test2.Models.ManagementModels.GmailSMTP;
using test2.Models.ManagementModels.ZhongXian.Normal;

namespace test2.Models.ManagementModels.Services
{
    public class LateRetrunClass
    {
        private readonly Test2Context _context;
        public LateRetrunClass(Test2Context context)
        {
            _context = context;
        }
        EmailSender EmailSenders = new EmailSender();
        public async Task<MessageDTO> LateRetrunStart()
        {
            Debug.WriteLine("開始進行逾期還書檢查.....");
            // ***非必要請不要啟動****
            // 檢查逾期、更改並站內通知
            var LateReturnList = await _context.Set<ReturnDTO>().FromSqlRaw($"EXEC LateReturn2Email").ToListAsync();
            if (LateReturnList[0].ResultCode == 0) { return new MessageDTO() { Message = "今天無逾期未還" }; }
            Debug.WriteLine("今天逾期人數: " + LateReturnList.Count);
            foreach (var x in LateReturnList)
            {
                Debug.WriteLine($"逾期還書者:{x.cName} _ 書名: {x.title} _ 信箱 : {x.cAccount}");
            }
            //// Email發送
            //foreach (var user in LateReturnList)
            //{
            //    string subject = "【逾期警告通知】";
            //    string body = $"親愛的 {user.cName}，您所借閱的  {user.Title} \r\n已經愈期，請盡速還書。\r\n圖書館管理系統 敬上。";
            //    await EmailSenders.SendAsync(user.cAccount!, subject, body);
            //}

            // 以下可以測試用
            //string subject = "【逾期警告通知】";
            //string body = $"親愛的 {users[0].ClientName}，您所借閱的  {users[0].Title} \r\n已經愈期，請盡速還書。\r\n圖書館管理系統 敬上。";
            //int UserCount = users.Count();
            //string myEmail = "你的Email";
            //await EmailSenders.SendAsync(myEmail, subject, body);

            return new MessageDTO() { Message = "逾期未還檢查結束!" };
        }
    }
}
