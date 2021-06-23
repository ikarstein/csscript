//<csscript>
//  <debug/>
//  <references>
//    <reference>System</reference>
////    <reference>System.Core</reference>
//    <reference>System.Data</reference>
////    <reference>System.Data.DataSetExtensions</reference>
//    <reference>System.Xml</reference>
////    <reference>System.Xml.Linq</reference>
//  </references>
//  <mode>exe</mode>
//  <files>
//      <file>Class1.cs</file>
////      <file>Test</file>
//  </files>
//</csscript>

using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;

namespace test
{
    class Program
    {

        static void Main(string[] args)
        {
#if(DEBUG)
            System.Diagnostics.Debugger.Break();
#endif

            for (int i = 0; i < 3; i++)
            {
                Class1 c1 = new Class1();
                Console.Write(c1.TestString());
                Console.Write(c1.TestCharArray());
                Console.Write(c1.TestFloat());
                Console.Write(true);
                Console.Write(DateTime.Now);
                Console.WriteLine(i);
                
                System.Threading.Thread.Sleep(100);
                
            }
			
			int j = 1;
			foreach(string s in args){
				Console.WriteLine( "Param {0}: \"{1}\"", j, s);
				j++;
			}
        }
    }
}
