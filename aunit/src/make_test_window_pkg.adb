------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                           Make_Test_Window_Pkg                           --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                            $Revision$
--                                                                          --
--                Copyright (C) 2001 Ada Core Technologies, Inc.            --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with GNAT;  see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- GNAT is maintained by Ada Core Technologies Inc (http://www.gnat.com).   --
--                                                                          --
------------------------------------------------------------------------------

with Gtk; use Gtk;
with Gtk.Widget;      use Gtk.Widget;
with Gtk.Enums;       use Gtk.Enums;
with Gtkada.Handlers; use Gtkada.Handlers;
with Callbacks_Aunit_Gui; use Callbacks_Aunit_Gui;
with Aunit_Gui_Intl; use Aunit_Gui_Intl;
with Make_Test_Window_Pkg.Callbacks; use Make_Test_Window_Pkg.Callbacks;

package body Make_Test_Window_Pkg is

procedure Gtk_New (Make_Test_Window : out Make_Test_Window_Access) is
begin
   Make_Test_Window := new Make_Test_Window_Record;
   Make_Test_Window_Pkg.Initialize (Make_Test_Window);
end Gtk_New;

procedure Initialize (Make_Test_Window : access Make_Test_Window_Record'Class) is
   pragma Suppress (All_Checks);
begin
   Gtk.Window.Initialize (Make_Test_Window, Window_Toplevel);
   Set_Title (Make_Test_Window, -"New test unit");
   Set_Policy (Make_Test_Window, False, True, False);
   Set_Position (Make_Test_Window, Win_Pos_None);
   Set_Modal (Make_Test_Window, False);
   Return_Callback.Connect
     (Make_Test_Window, "delete_event", On_Make_Test_Window_Delete_Event'Access);

   Gtk_New_Vbox (Make_Test_Window.Vbox0, False, 0);
   Add (Make_Test_Window, Make_Test_Window.Vbox0);

   Gtk_New_Hbox (Make_Test_Window.Hbox1, False, 0);
   Pack_Start (Make_Test_Window.Vbox0, Make_Test_Window.Hbox1, True, True, 0);

   Gtk_New_Vbox (Make_Test_Window.Vbox1, True, 0);
   Pack_Start (Make_Test_Window.Hbox1, Make_Test_Window.Vbox1, False, False, 5);

   Gtk_New (Make_Test_Window.Label1, -("Unit name : "));
   Set_Alignment (Make_Test_Window.Label1, 1.0, 0.5);
   Set_Padding (Make_Test_Window.Label1, 0, 0);
   Set_Justify (Make_Test_Window.Label1, Justify_Center);
   Set_Line_Wrap (Make_Test_Window.Label1, False);
   Pack_Start (Make_Test_Window.Vbox1, Make_Test_Window.Label1, False, False, 0);

   Gtk_New (Make_Test_Window.Label2, -("Description : "));
   Set_Alignment (Make_Test_Window.Label2, 1.0, 0.5);
   Set_Padding (Make_Test_Window.Label2, 0, 0);
   Set_Justify (Make_Test_Window.Label2, Justify_Center);
   Set_Line_Wrap (Make_Test_Window.Label2, False);
   Pack_Start (Make_Test_Window.Vbox1, Make_Test_Window.Label2, False, False, 0);

   Gtk_New (Make_Test_Window.Label3);
   Set_Alignment (Make_Test_Window.Label3, 0.5, 0.5);
   Set_Padding (Make_Test_Window.Label3, 0, 0);
   Set_Justify (Make_Test_Window.Label3, Justify_Center);
   Set_Line_Wrap (Make_Test_Window.Label3, False);
   Pack_Start (Make_Test_Window.Vbox1, Make_Test_Window.Label3, False, False, 0);

   Gtk_New (Make_Test_Window.Label4);
   Set_Alignment (Make_Test_Window.Label4, 0.5, 0.5);
   Set_Padding (Make_Test_Window.Label4, 0, 0);
   Set_Justify (Make_Test_Window.Label4, Justify_Center);
   Set_Line_Wrap (Make_Test_Window.Label4, False);
   Pack_Start (Make_Test_Window.Vbox1, Make_Test_Window.Label4, False, False, 0);

   Gtk_New_Vbox (Make_Test_Window.Vbox2, True, 0);
   Pack_Start (Make_Test_Window.Hbox1, Make_Test_Window.Vbox2, True, True, 3);

   Gtk_New (Make_Test_Window.Name_Entry);
   Set_Editable (Make_Test_Window.Name_Entry, True);
   Set_Max_Length (Make_Test_Window.Name_Entry, 0);
   Set_Text (Make_Test_Window.Name_Entry, -"New_Test");
   Set_Visibility (Make_Test_Window.Name_Entry, True);
   Pack_Start (Make_Test_Window.Vbox2, Make_Test_Window.Name_Entry, False, False, 0);
   Entry_Callback.Connect
     (Make_Test_Window.Name_Entry, "activate",
      Entry_Callback.To_Marshaller (On_Name_Entry_Activate'Access));

   Gtk_New (Make_Test_Window.Description_Entry);
   Set_Editable (Make_Test_Window.Description_Entry, True);
   Set_Max_Length (Make_Test_Window.Description_Entry, 0);
   Set_Text (Make_Test_Window.Description_Entry, -"(no description)");
   Set_Visibility (Make_Test_Window.Description_Entry, True);
   Pack_Start (Make_Test_Window.Vbox2, Make_Test_Window.Description_Entry, False, False, 0);
   Entry_Callback.Connect
     (Make_Test_Window.Description_Entry, "activate",
      Entry_Callback.To_Marshaller (On_Description_Entry_Activate'Access));

   Gtk_New (Make_Test_Window.Override_Tear_Down, -"Override Tear_Down");
   Set_Active (Make_Test_Window.Override_Tear_Down, False);
   Pack_Start (Make_Test_Window.Vbox2, Make_Test_Window.Override_Tear_Down, False, False, 0);

   Gtk_New (Make_Test_Window.Override_Set_Up, -"Override Set_up");
   Set_Active (Make_Test_Window.Override_Set_Up, False);
   Pack_Start (Make_Test_Window.Vbox2, Make_Test_Window.Override_Set_Up, False, False, 0);

   Gtk_New (Make_Test_Window.Hbuttonbox1);
   Set_Spacing (Make_Test_Window.Hbuttonbox1, 30);
   Set_Layout (Make_Test_Window.Hbuttonbox1, Buttonbox_Spread);
   Set_Child_Size (Make_Test_Window.Hbuttonbox1, 85, 27);
   Set_Child_Ipadding (Make_Test_Window.Hbuttonbox1, 7, 0);
   Pack_Start (Make_Test_Window.Vbox0, Make_Test_Window.Hbuttonbox1, True, True, 0);

   Gtk_New (Make_Test_Window.Ok, -"OK");
   Set_Flags (Make_Test_Window.Ok, Can_Default);
   Button_Callback.Connect
     (Make_Test_Window.Ok, "clicked",
      Button_Callback.To_Marshaller (On_Ok_Clicked'Access));
   Add (Make_Test_Window.Hbuttonbox1, Make_Test_Window.Ok);

   Gtk_New (Make_Test_Window.Cancel, -"Cancel");
   Set_Flags (Make_Test_Window.Cancel, Can_Default);
   Button_Callback.Connect
     (Make_Test_Window.Cancel, "clicked",
      Button_Callback.To_Marshaller (On_Cancel_Clicked'Access));
   Add (Make_Test_Window.Hbuttonbox1, Make_Test_Window.Cancel);

   Gtk_New (Make_Test_Window.Help, -"Help");
   Set_Flags (Make_Test_Window.Help, Can_Default);
   Button_Callback.Connect
     (Make_Test_Window.Help, "clicked",
      Button_Callback.To_Marshaller (On_Help_Clicked'Access));
   Add (Make_Test_Window.Hbuttonbox1, Make_Test_Window.Help);

end Initialize;

end Make_Test_Window_Pkg;
