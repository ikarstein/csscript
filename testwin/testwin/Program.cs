//<csscript>
//  <nodebug/>
//  <references>
//    <reference>System</reference>
//    <reference>System.Core</reference>
//    <reference>System.Data</reference>
//    <reference>System.Data.DataSetExtensions</reference>
//    <reference>System.Xml</reference>
//    <reference>System.Xml.Linq</reference>
//    <reference>System.Windows.Forms</reference>
//    <reference>System.Drawing</reference>
//  </references>
//  <mode>winexe</mode>
//  <files>
//      <file>Form1.cs</file>
//      <file>Form1.Designer.cs</file>
////      <file>Test</file>
//  </files>
//</csscript>

using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Forms;

namespace testwin
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Form1(args));
        }
    }
}
