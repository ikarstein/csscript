//<csscript>
//  <references>
//    <reference>System</reference>
//    <reference>System.Web</reference>
//  </references>
//  <debug/>
//</csscript>

using System;
using System.Collections.Generic;
using System.Text;
using System.Web.Security;

namespace ik.SharePoint2010.fbatool
{
    class Program
    {
        static void Main(string[] args)
        {
            try
            {
                if( args.Length < 1 )
                {
                    Console.WriteLine(@"
WRITTEN BY INGO KARSTEIN (ikarstein >AT< hotmail.com)
No warranty. Provided as ""as is"". Use it at your own risk!

-------------------------------------------------------------------
#create user
cu username password email question answer 

-------------------------------------------------------------------
#create role
cr rolename

-------------------------------------------------------------------
#list users
lu

-------------------------------------------------------------------
#list roles
lr

-------------------------------------------------------------------
#add user to role
au username rolename

-------------------------------------------------------------------
#list user roles
ur username

-------------------------------------------------------------------
#delete user
du username

-------------------------------------------------------------------
#delete role
dr rolename

-------------------------------------------------------------------
#delete user from role  (""role remove"")
rr username rolename

-------------------------------------------------------------------
#reset password
rp username [answer]

-------------------------------------------------------------------
#unlock user (""UNlock user"")
un username
");

                    return;
                }

                if( args[0] == "cu" )
                {
                    MembershipCreateStatus status;
                    Membership.CreateUser(args[1], args[2], args[3], args[4], args[5], true, out status);
                    Console.WriteLine(status.ToString());
                }

                if( args[0] == "cr" )
                {
                    Roles.CreateRole(args[1]);
                }

                if( args[0] == "lu" )
                {
                    foreach( MembershipUser u in Membership.GetAllUsers() )
                    {
                        Console.WriteLine(u.UserName);
                    }
                }

                if( args[0] == "au" )
                {
                    Roles.AddUsersToRole(new string[] { args[1] }, args[2]);
                }

                if( args[0] == "ur" )
                {
                    foreach( var u in Roles.GetRolesForUser(args[1]) )
                    {
                        Console.WriteLine(u);
                    }
                }

                if( args[0] == "du" )
                {
                    Membership.DeleteUser(args[1]);
                }

                if( args[0] == "dr" )
                {
                    Roles.DeleteRole(args[1]);
                }

                if( args[0] == "rr" )
                {
                    Roles.RemoveUserFromRole(args[1], args[2]);
                }

                if( args[0] == "rp" )
                {
                    if( string.IsNullOrEmpty(args[2]) )
                        Console.WriteLine(Membership.GetUser(args[1]).ResetPassword());
                    else
                        Console.WriteLine(Membership.GetUser(args[1]).ResetPassword(args[2]));
                }

                if( args[0] == "un" )
                {
                    Membership.GetUser(args[1]).UnlockUser();
                }

                if( args[0] == "lr" )
                {
                    foreach( var u in Roles.GetAllRoles() )
                    {
                        Console.WriteLine(u);
                    }
                }


            }
            catch( Exception ex )
            {
                var c = Console.ForegroundColor;
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(ex.Message);
                Console.ForegroundColor = c;
            }
        }
    }
}
