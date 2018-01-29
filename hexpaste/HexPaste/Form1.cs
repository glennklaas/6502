using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace HexPaste
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void button2_Click(object sender, EventArgs e)
        {
            textBox2.Text = "";
            string txt = textBox1.Text;
            string[] lst = txt.Split(new Char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);

            int curAddress = Convert.ToInt32(txtStartAddress.Text, 16);


            foreach (string myArr in lst)
            {
                string rec_intelType = myArr.Substring(0, 1);
                string rec_recLen = myArr.Substring(1, 2);
                string rec_recAddr = myArr.Substring(3, 4);
                int decValue = Convert.ToInt32(rec_recLen, 16);
                string rec_Type = myArr.Substring(7, 2);
                string rec_dd = myArr.Substring(9, decValue * 2);

                if (rec_Type.Equals("00"))
                {

                    if (!myArr.Substring(3, 2).Equals("FF"))
                    {
                        textBox2.Text += curAddress.ToString("X") + ": ";

                        for (int i = 0; i < (decValue * 2) - 1; i++)
                        {
                            textBox2.Text += rec_dd.Substring(i, 2) + " ";
                            i++;
                            curAddress += 1;
                        }

                        textBox2.Text += "\r\n";
                    }
                }
            }

            System.Windows.Forms.Clipboard.SetText(textBox2.Text);
        }

        private void button1_Click(object sender, EventArgs e)
        {
            textBox1.Clear();
            textBox2.Clear();
        }
    }
}
