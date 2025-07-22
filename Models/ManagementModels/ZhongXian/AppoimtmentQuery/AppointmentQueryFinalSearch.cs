﻿using Microsoft.CodeAnalysis;
using Microsoft.EntityFrameworkCore;
using Microsoft.SqlServer.Server;
using System.Diagnostics;
using test2.Models.ManagementModels.ZhongXian.AppoimtmentQuery;
using test2.Models.ManagementModels.ZhongXian.Normal;

namespace test2.Models.ManagementModels.ZhongXian.AppoimtmentQuery
{
    public class AppointmentQueryFinalSearch
    {
        public async Task<QueryViewModel> AppointmentQuerySearch(Test2Context context, AppoimtmentQueryFilter filter)
        {
            bool AppointmentEmptyFilter()
            {
                return filter.appointment_reservationId == null &&
                    filter.appointment_UserID == null &&
                    filter.appointment_bookCode == null &&
                    filter.appointment_initDate == null &&
                    filter.appointment_lastDate == null &&
                    filter.appointment_state == "ALL";
            }  
            var result =   context.Reservations.Include(x => x.Book).Include(y => y.Collection).Include(z => z.ReservationStatus).Select(final => new AppointmentQueryResultDTO()
            {
                appointmentId = final.ReservationId,
                bookCode = final.Book!.BookCode,
                title = final.Collection.Title,
                cid = final.CId,
                appointmentDate = final.ReservationDate,
                appointmentDue = final.DueDateR,
                appointmentStatus = final.ReservationStatus.ReservationStatus1
            }).AsQueryable();
            if (AppointmentEmptyFilter()) { result = result.Where(ap => ap.appointmentDate <= DateTime.Now && ap.appointmentDate >= DateTime.Now.AddMonths(-10)); }
            if (filter.appointment_reservationId != null) { result = result.Where(x => x.appointmentId == filter.appointment_reservationId); }
            if (filter.appointment_UserID != null) { result = result.Where(x => x.cid == filter.appointment_UserID); }
            if (filter.appointment_bookCode != null) { result = result.Where(x => x.bookCode!.Contains( filter.appointment_bookCode)); }
            if (filter.appointment_state != "ALL") { result = result.Where(x => x.appointmentStatus == filter.appointment_state); }
            if (filter.appointment_initDate != null || filter.appointment_lastDate != null)
            {
                if (filter.appointment_initDate <= filter.appointment_lastDate) { result = result.Where(x => filter.appointment_initDate <= x.appointmentDate && x.appointmentDate <= filter.appointment_lastDate); }
                if (filter.appointment_initDate >= filter.appointment_lastDate) { result = result.Where(x => filter.appointment_initDate >= x.appointmentDate && x.appointmentDate >= filter.appointment_lastDate); }
            }
            if (filter.appointment_orderDate == "desc") { result = result.OrderByDescending(x => x.appointmentDate); }
            else { result = result.OrderBy(x => x.appointmentDate); }
            var totalCount = await result.CountAsync();
            var finalResult = await result.Skip((filter.page  - 1) * filter.appointment_perPage ).Take(filter.appointment_perPage).ToListAsync();
            var AppointmentViewModels = new QueryViewModel()
            {
                AppointmentQueryResultDTOs = finalResult,
                PageCounts = new List<PageCount>(){ new PageCount(){TotalCount = totalCount,CurrentPage = filter.page, perPage = filter.appointment_perPage}}
            };
            return AppointmentViewModels;
        }
    }
}
