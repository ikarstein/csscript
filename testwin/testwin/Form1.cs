using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace testwin
{
    public partial class Form1 : Form
    {
        public Form1(string[] args)
        {
            InitializeComponent();

            listBox1.Items.Clear();

            foreach(string s in args)
                listBox1.Items.Add(s);
        }

        private void button1_Click(object sender, EventArgs e)
        {
            this.Close();
        }
    }
}
