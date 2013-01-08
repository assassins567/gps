------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2008-2013, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with System;
with Interfaces.C.Strings;     use Interfaces.C.Strings;

with Glib.Object;              use Glib.Object;
with Gdk.Event;                use Gdk.Event;
with Gdk.Window;               use Gdk.Window;
with Gtk.Arrow;                use Gtk.Arrow;
with Gtk.Box;                  use Gtk.Box;
with Gtk.Handlers;             use Gtk.Handlers;
with Gtk.Image;                use Gtk.Image;
with Gtk.Label;                use Gtk.Label;
with Gtk.Menu_Item;            use Gtk.Menu_Item;
with Gtk.Menu_Shell;           use Gtk.Menu_Shell;
with Gtk.Style_Context;        use Gtk.Style_Context;
with Gtk.Tool_Item;            use Gtk.Tool_Item;
with Gtk.Widget;               use Gtk.Widget;

package body Gtkada.Combo_Tool_Button is

   use Strings_Vector;

   ----------------------
   -- Class definition --
   ----------------------

   Class_Record : Ada_GObject_Class := Uninitialized_Class;
   Signals : constant chars_ptr_array :=
               (1 => New_String (String (Signal_Clicked)),
                2 => New_String (String (Signal_Selection_Changed)));
   Signal_Parameters : constant Signal_Parameter_Types :=
                         (1 => (1 => GType_None),
                          2 => (1 => GType_None));

   ---------------
   -- Menu_Item --
   ---------------

   type Menu_Item_Record is new Gtk_Menu_Item_Record with record
      Stock_Id : Unbounded_String;
      Label    : Gtk_Label;
      Data     : User_Data;
   end record;
   type Menu_Item is access all Menu_Item_Record'Class;

   procedure Gtk_New
     (Item     : out Menu_Item;
      Label    : String;
      Stock_Id : String;
      Data     : User_Data);

   procedure Set_Highlight
     (Item  : access Menu_Item_Record'Class;
      State : Boolean);

   --------------
   -- Handlers --
   --------------

   package Tool_Button_Callback is new Gtk.Handlers.Callback
     (Gtkada_Combo_Tool_Button_Record);

   package Button_Callback is new Gtk.Handlers.User_Callback
     (Gtk_Button_Record, Gtkada_Combo_Tool_Button);

   package Items_Callback is new Gtk.Handlers.User_Callback
     (Menu_Item_Record, Gtkada_Combo_Tool_Button);

   package Menu_Callback is new Gtk.Handlers.User_Callback
     (Gtk_Menu_Record, Gtkada_Combo_Tool_Button);

   package Menu_Popup is new Popup_User_Data
     (Gtkada_Combo_Tool_Button);

   package Toggle_Button_Callback is new Gtk.Handlers.User_Callback
     (Gtk_Toggle_Button_Record, Gtkada_Combo_Tool_Button);

   package Toggle_Button_Return_Callback is
     new Gtk.Handlers.User_Return_Callback
       (Gtk_Toggle_Button_Record, Boolean, Gtkada_Combo_Tool_Button);

   ---------------------------
   -- Callback declarations --
   ---------------------------

   procedure On_State
     (Button : access Gtk_Button_Record'Class;
      Widget : Gtkada_Combo_Tool_Button);

   procedure On_Menu_Deactivate
     (Menu   : access Gtk_Menu_Record'Class;
      Widget : Gtkada_Combo_Tool_Button);

   function On_Button_Press
     (Button : access Gtk_Toggle_Button_Record'Class;
      Event  : Gdk_Event;
      Widget : Gtkada_Combo_Tool_Button) return Boolean;

   procedure On_Toggle
     (Button : access Gtk_Toggle_Button_Record'Class;
      Widget : Gtkada_Combo_Tool_Button);

   procedure Menu_Detacher
     (Attach_Widget : System.Address; Menu : System.Address);
   pragma Convention (C, Menu_Detacher);

   procedure Menu_Position
     (Menu    : not null access Gtk_Menu_Record'Class;
      X       : out Gint;
      Y       : out Gint;
      Push_In : out Boolean;
      Widget  : Gtkada_Combo_Tool_Button);

   procedure Set_Icon_Size
     (Button : access Gtkada_Combo_Tool_Button_Record'Class;
      Size   : Gtk_Icon_Size);

   procedure On_Toolbar_Reconfigured
     (Button : access Gtkada_Combo_Tool_Button_Record'Class);

   procedure On_Icon_Widget_Clicked
     (Button : access Gtk_Button_Record'Class;
      Widget : Gtkada_Combo_Tool_Button);

   procedure On_Menu_Item_Activated
     (Item   : access Menu_Item_Record'Class;
      Widget : Gtkada_Combo_Tool_Button);

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Item     : out Menu_Item;
      Label    : String;
      Stock_Id : String;
      Data     : User_Data)
   is
      Icon : Gtk_Image;
      Hbox : Gtk_Hbox;
      Child : Gtk_Widget;
   begin
      Item := new Menu_Item_Record;
      Gtk.Menu_Item.Initialize (Item, "");
      Item.Data     := Data;
      Item.Stock_Id := To_Unbounded_String (Stock_Id);

      Gtk_New_Hbox (Hbox, Homogeneous => False, Spacing => 5);

      --  Remove the existing widget if Gtk+ creates one by default

      Child := Item.Get_Child;
      if Child /= null then
         Item.Remove (Child);
      end if;

      Item.Add (Hbox);

      Gtk_New (Icon, Stock_Id, Icon_Size_Menu);
      Hbox.Pack_Start (Icon, False, False, 0);

      Gtk_New (Item.Label, Label);
      Item.Label.Set_Alignment (0.0, 0.5);
      Item.Label.Set_Use_Markup (True);
      Hbox.Pack_Start (Item.Label, True, True, 0);
      Show_All (Item);
   end Gtk_New;

   -------------------
   -- Set_Highlight --
   -------------------

   procedure Set_Highlight
     (Item  : access Menu_Item_Record'Class;
      State : Boolean) is
   begin
      if State then
         Item.Label.Set_Label ("<b>" & Item.Label.Get_Text & "</b>");
      else
         Item.Label.Set_Label (Item.Label.Get_Text);
      end if;
   end Set_Highlight;

   --------------
   -- On_State --
   --------------

   procedure On_State
     (Button : access Gtk_Button_Record'Class;
      Widget : Gtkada_Combo_Tool_Button)
   is
      State : constant Gtk_State_Type := Button.Get_State;
   begin
      if State = State_Active then
         Set_State (Widget.Menu_Button, State_Prelight);
         Set_State (Widget.Icon_Button, State_Prelight);
      else
         Set_State (Widget.Menu_Button, State);
         Set_State (Widget.Icon_Button, State);
      end if;
   end On_State;

   ------------------------
   -- On_Menu_Deactivate --
   ------------------------

   procedure On_Menu_Deactivate
     (Menu   : access Gtk_Menu_Record'Class;
      Widget : Gtkada_Combo_Tool_Button)
   is
      pragma Unreferenced (Menu);
   begin
      Widget.Menu_Button.Set_Active (False);
   end On_Menu_Deactivate;

   ---------------
   -- On_Toggle --
   ---------------

   function On_Button_Press
     (Button : access Gtk_Toggle_Button_Record'Class;
      Event  : Gdk_Event;
      Widget : Gtkada_Combo_Tool_Button) return Boolean
   is
      pragma Unreferenced (Button);
   begin
      if Get_Button (Event) = 1 then
         Menu_Popup.Popup
           (Widget.Menu,
            null, null, Menu_Position'Access,
            Widget,
            Get_Button (Event), Get_Time (Event));
         Widget.Menu.Select_Item (Widget.Menu.Get_Active);
         Widget.Menu_Button.Set_Active (True);
         Widget.Menu_Button.Set_State (State_Active);

         return True;
      end if;

      return False;
   end On_Button_Press;

   ---------------
   -- On_Toggle --
   ---------------

   procedure On_Toggle
     (Button : access Gtk_Toggle_Button_Record'Class;
      Widget : Gtkada_Combo_Tool_Button) is
   begin
      if Widget.Menu = null then
         return;
      end if;

      if Button.Get_Active
        and then not Get_Visible (Widget.Menu)
      then
         Menu_Popup.Popup
           (Widget.Menu,
            null, null, Menu_Position'Access, Widget,
            0, 0);
         Widget.Menu.Select_Item (Widget.Menu.Get_Active);
      end if;
   end On_Toggle;

   -------------------
   -- Menu_Detacher --
   -------------------

   procedure Menu_Detacher
     (Attach_Widget : System.Address; Menu : System.Address)
   is
      pragma Unreferenced (Menu);
      Stub : Gtkada_Combo_Tool_Button_Record;
      pragma Unmodified (Stub);
   begin
      Gtkada_Combo_Tool_Button
        (Get_User_Data (Attach_Widget, Stub)).Menu := null;
   end Menu_Detacher;

   -------------------
   -- Menu_Position --
   -------------------

   procedure Menu_Position
     (Menu    : not null access Gtk_Menu_Record'Class;
      X       : out Gint;
      Y       : out Gint;
      Push_In : out Boolean;
      Widget  : Gtkada_Combo_Tool_Button)
   is
      pragma Unreferenced (Menu, Push_In);
      Menu_Req    : Gtk_Requisition;
      Allo : Gtk_Allocation;

   begin
      Size_Request (Widget.Menu, Menu_Req);
      Get_Origin (Get_Window (Widget), X, Y);
      Get_Allocation (Widget, Allo);

      X := X + Allo.X;
      Y := Y + Allo.Y + Allo.Height;

      if Allo.Width > Menu_Req.Width then
         X := X + Allo.Width - Menu_Req.Width;
      end if;
   end Menu_Position;

   ----------------------------
   -- On_Icon_Widget_Clicked --
   ----------------------------

   procedure On_Icon_Widget_Clicked
     (Button : access Gtk_Button_Record'Class;
      Widget : Gtkada_Combo_Tool_Button)
   is
      pragma Unreferenced (Button);
   begin
      Tool_Button_Callback.Emit_By_Name (Widget, Signal_Clicked);
   end On_Icon_Widget_Clicked;

   ----------------------------
   -- On_Menu_Item_Activated --
   ----------------------------

   procedure On_Menu_Item_Activated
     (Item   : access Menu_Item_Record'Class;
      Widget : Gtkada_Combo_Tool_Button)
   is
   begin
      Select_Item (Widget, Item.Label.Get_Text);
      Tool_Button_Callback.Emit_By_Name (Widget, Signal_Clicked);
   end On_Menu_Item_Activated;

   -------------------
   -- Set_Icon_Size --
   -------------------

   procedure Set_Icon_Size
     (Button : access Gtkada_Combo_Tool_Button_Record'Class;
      Size   : Gtk_Icon_Size)
   is
      Icon  : Gtk_Image;
      Item  : constant Menu_Item := Menu_Item (Button.Menu.Get_Active);
   begin
      if Item /= null then
         Gtk_New (Icon, To_String (Item.Stock_Id), Size);
      else
         Gtk_New (Icon, To_String (Button.Stock_Id), Size);
      end if;

      Set_Image (Button.Icon_Button, Icon);
      Icon.Set_Alignment (0.5, 0.5);
   end Set_Icon_Size;

   -----------------------------
   -- On_Toolbar_Reconfigured --
   -----------------------------

   procedure On_Toolbar_Reconfigured
     (Button : access Gtkada_Combo_Tool_Button_Record'Class)
   is
   begin
      Set_Icon_Size (Button, Button.Get_Icon_Size);
   end On_Toolbar_Reconfigured;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Button       : out Gtkada_Combo_Tool_Button;
      Stock_Id     : String;
      Default_Size : Gtk_Icon_Size := Icon_Size_Large_Toolbar)
   is
   begin
      Button := new Gtkada_Combo_Tool_Button_Record;
      Initialize (Button, Stock_Id, Default_Size);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Button       : access Gtkada_Combo_Tool_Button_Record'Class;
      Stock_Id     : String;
      Default_Size : Gtk_Icon_Size := Icon_Size_Large_Toolbar)
   is
      Arrow       : Gtk_Arrow;
      Box : Gtk_Box;
   begin
      Gtk.Tool_Item.Initialize (Button);
      Initialize_Class_Record
        (Object       => Button,
         Signals      => Signals,
         Class_Record => Class_Record,
         Type_Name    => "GtkadaComboToolButton",
         Parameters   => Signal_Parameters);

      Get_Style_Context (Button).Add_Class ("gps-combo-tool-button");

      Set_Homogeneous (Button, False);
      Button.Items    := Empty_Vector;
      Button.Selected := No_Index;
      Button.Stock_Id := To_Unbounded_String (Stock_Id);

      Gtk_New_Hbox (Box, Homogeneous => False, Spacing => 0);
      Button.Add (Box);

      Gtk_New (Button.Icon_Button);
      Button.Icon_Button.Set_Relief (Relief_None);
      Box.Pack_Start (Button.Icon_Button, Expand => True, Fill => True);

      Gtk_New (Button.Menu_Button);
      Button.Menu_Button.Set_Relief (Relief_None);
      Box.Pack_Start (Button.Menu_Button, Expand => True, Fill => True);

      Gtk_New (Arrow, Arrow_Down, Shadow_None);
      Button.Menu_Button.Add (Arrow);

      --  Create a default menu widget.
      Clear_Items (Button);

      --  Set the default icon size. Upon attachment to a toolbar, this size
      --  might be overriden.
      Set_Icon_Size (Button, Default_Size);

      --  Update icon size upon toolbar reconfigured
      Tool_Button_Callback.Connect
        (Button, Signal_Toolbar_Reconfigured,
         On_Toolbar_Reconfigured'Access);
      --  Display menu upon toggle button toggled or clicked
      Toggle_Button_Callback.Connect
        (Button.Menu_Button, Signal_Toggled,
         On_Toggle'Access,
         Gtkada_Combo_Tool_Button (Button));
      Toggle_Button_Return_Callback.Connect
        (Button.Menu_Button, Signal_Button_Press_Event,
         Toggle_Button_Return_Callback.To_Marshaller (On_Button_Press'Access),
         Gtkada_Combo_Tool_Button (Button));
      --  Keep appearance of toggle button synchronized with icon button
      Button_Callback.Connect
        (Button.Icon_Button, Signal_State_Changed,
         On_State'Access,
         Gtkada_Combo_Tool_Button (Button));
      Button_Callback.Connect
        (Button.Menu_Button, Signal_State_Changed,
         On_State'Access,
         Gtkada_Combo_Tool_Button (Button));
      --  Handle single click on icon button
      Button_Callback.Connect
        (Button.Icon_Button, Signal_Clicked,
         On_Icon_Widget_Clicked'Access,
         Gtkada_Combo_Tool_Button (Button));

      Show_All (Button);
   end Initialize;

   --------------
   -- Add_Item --
   --------------

   procedure Add_Item
     (Widget   : access Gtkada_Combo_Tool_Button_Record;
      Item     : String;
      Stock_Id : String := "";
      Data     : User_Data := null)
   is
      First  : constant Boolean := Widget.Items.Is_Empty;
      M_Item : Menu_Item;

   begin
      if Stock_Id /= "" then
         Gtk_New (M_Item, Item, Stock_Id, Data);
      else
         Gtk_New (M_Item, Item, To_String (Widget.Stock_Id), Data);
      end if;

      Widget.Menu.Add (M_Item);
      Items_Callback.Connect
        (M_Item, Gtk.Menu_Item.Signal_Activate, On_Menu_Item_Activated'Access,
         Gtkada_Combo_Tool_Button (Widget));

      Widget.Items.Append (To_Unbounded_String (Item));

      if First then
         Widget.Menu_Button.Set_Sensitive (True);
         Widget.Select_Item (Item);
      end if;
   end Add_Item;

   -----------------
   -- Select_Item --
   -----------------

   procedure Select_Item
     (Widget : access Gtkada_Combo_Tool_Button_Record;
      Item   : String)
   is
      Elem   : constant Unbounded_String := To_Unbounded_String (Item);
      M_Item : Menu_Item;
   begin
      if Widget.Selected /= No_Index then
         --  A bit weird, but with Menu API, the only way to retrieve an item
         --  from its place number is to set it active first, then get the
         --  active menu_item ...
         Widget.Menu.Set_Active (Guint (Widget.Selected));
         Menu_Item (Widget.Menu.Get_Active).Set_Highlight (False);
      end if;

      for J in Widget.Items.First_Index .. Widget.Items.Last_Index loop
         if Widget.Items.Element (J) = Elem then
            Widget.Menu.Set_Active (Guint (J));
            M_Item := Menu_Item (Widget.Menu.Get_Active);
            M_Item.Set_Highlight (True);
            --  This updates the icon
            On_Toolbar_Reconfigured (Widget);
            Widget.Selected := J;

            Tool_Button_Callback.Emit_By_Name
              (Widget, Signal_Selection_Changed);

            return;

         end if;
      end loop;
      --  ??? raise something ?
   end Select_Item;

   -----------------
   -- Clear_Items --
   -----------------

   procedure Clear_Items (Widget : access Gtkada_Combo_Tool_Button_Record) is
   begin
      Widget.Items.Clear;

      if Widget.Menu /= null then
         if Get_Visible (Widget.Menu) then
            Deactivate (Widget.Menu);
         end if;

         Detach (Widget.Menu);
      end if;

      Gtk_New (Widget.Menu);

      Attach_To_Widget
        (Widget.Menu, Widget, Menu_Detacher'Access);
      Menu_Callback.Connect
        (Widget.Menu, Signal_Deactivate, On_Menu_Deactivate'Access,
         Gtkada_Combo_Tool_Button (Widget));
      Widget.Menu_Button.Set_Sensitive (False);
   end Clear_Items;

   -----------------------
   -- Get_Selected_Item --
   -----------------------

   function Get_Selected_Item
     (Widget : access Gtkada_Combo_Tool_Button_Record) return String
   is
      Item : constant Menu_Item := Menu_Item (Widget.Menu.Get_Active);
   begin
      if Item /= null then
         return Item.Label.Get_Text;
      else
         return "";
      end if;
   end Get_Selected_Item;

   ----------------------------
   -- Get_Selected_Item_Data --
   ----------------------------

   function Get_Selected_Item_Data
     (Widget : access Gtkada_Combo_Tool_Button_Record)
      return User_Data
   is
      Item : constant Menu_Item := Menu_Item (Widget.Menu.Get_Active);
   begin
      if Item /= null then
         return Item.Data;
      else
         return null;
      end if;
   end Get_Selected_Item_Data;

end Gtkada.Combo_Tool_Button;
