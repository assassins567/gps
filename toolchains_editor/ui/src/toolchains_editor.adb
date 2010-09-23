-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                    Copyright (C) 2010, AdaCore                    --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Characters.Handling;  use Ada.Characters.Handling;
with Ada.Unchecked_Deallocation;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Fixed;        use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;    use Ada.Strings.Unbounded;
with GNAT.Expect;              use GNAT.Expect;
pragma Warnings (Off);
with GNAT.Expect.TTY.Remote;   use GNAT.Expect.TTY.Remote;
pragma Warnings (On);
with GNAT.OS_Lib;

with Glib;                     use Glib;
with Glib.Object;              use Glib.Object;
with Glib.Values;              use Glib.Values;
with Gdk.Event;
with Gtk.Button;               use Gtk.Button;
with Gtk.Cell_Renderer_Toggle; use Gtk.Cell_Renderer_Toggle;
with Gtk.Cell_Renderer_Text;   use Gtk.Cell_Renderer_Text;
with Gtk.Combo_Box_Entry;      use Gtk.Combo_Box_Entry;
with Gtk.Dialog;               use Gtk.Dialog;
with Gtk.Editable;
with Gtk.Enums;                use Gtk.Enums;
with Gtk.Frame;                use Gtk.Frame;
with Gtk.GEntry;               use Gtk.GEntry;
with Gtk.Handlers;
with Gtk.Image;                use Gtk.Image;
with Gtk.Label;                use Gtk.Label;
with Gtk.Scrolled_Window;      use Gtk.Scrolled_Window;
with Gtk.Stock;                use Gtk.Stock;
with Gtk.Tree_Model;           use Gtk.Tree_Model;
with Gtk.Tree_Selection;       use Gtk.Tree_Selection;
with Gtk.Tree_View_Column;     use Gtk.Tree_View_Column;
with Gtk.Widget;               use Gtk.Widget;
with Gtk.Window;               use Gtk.Window;
with Gtkada.Handlers;          use Gtkada.Handlers;

with GNATCOLL.Arg_Lists;       use GNATCOLL.Arg_Lists;
with GNATCOLL.Traces;
with GNATCOLL.VFS;             use GNATCOLL.VFS;

with GPS.Intl;                 use GPS.Intl;
with GPS.Kernel.Remote;

with GUI_Utils;                use GUI_Utils;
with Language_Handlers;        use Language_Handlers;
with Remote;                   use Remote;
with Toolchains;               use Toolchains;
with Traces;                   use Traces;

package body Toolchains_Editor is

   Me : constant Debug_Handle :=
          Traces.Create ("Toolchains_Editor", GNATCOLL.Traces.On);

   Active_Column   : constant := 0;
   Name_Column     : constant := 1;
   Label_Column    : constant := 2;
   Location_Column : constant := 3;
   Version_Column  : constant := 4;

   Lang_Column_Types : constant GType_Array :=
                         (Active_Column => GType_Boolean,
                          Name_Column   => GType_String);

   Column_Types : constant GType_Array :=
                    (Active_Column   => GType_Boolean,
                     Name_Column     => GType_String,
                     Label_Column    => GType_String,
                     Location_Column => GType_String,
                     Version_Column  => GType_String);

   type Tool_Kind is (Tool_Kind_Tool, Tool_Kind_Compiler);

   type Tool_Callback_User_Object is record
      Kind      : Tool_Kind;
      Tool_Name : Toolchains.Tools;
      Lang      : Unbounded_String;
      Label     : Gtk_Label;
      Value     : Gtk_Entry;
      Icon      : Gtk_Image;
      Reset_Btn : Gtk_Button;
   end record;

   package Tool_Callback is new Gtk.Handlers.User_Callback
     (Widget_Type => Toolchains_Edit_Record,
      User_Type   => Tool_Callback_User_Object);

   type GPS_Toolchain_Manager_Record is
     new Toolchains.Toolchain_Manager_Record with record
      Kernel : Kernel_Handle;
   end record;

   overriding function Execute
     (This       : GPS_Toolchain_Manager_Record;
      Command    : String;
      Timeout_MS : Integer) return String;
   --  Executes the command and returns the result.

   procedure Set_Project
     (Editor    : Toolchains_Edit;
      Project   : GNATCOLL.Projects.Project_Type);
   --  Sets the current project

   procedure Add_Toolchain
     (Editor         : Toolchains_Edit;
      Tc             : Toolchains.Toolchain;
      Force_Selected : Boolean);
   --  Adds or update a toolchain in the editor

   procedure Set_Detail
     (Label      : Gtk_Label;
      GEntry     : Gtk_Entry;
      Icon       : Gtk_Image;
      Reset_Btn  : Gtk_Button;
      Kind       : Tool_Kind;
      Tool       : Toolchains.Tools;
      Lang       : String;
      Value      : String;
      Is_Default : Boolean;
      Is_Valid   : Boolean);

   procedure Update_Details
     (Editor : Toolchains_Edit);

   function Get_Selected_Toolchain
     (Editor : access Toolchains_Edit_Record'Class) return Toolchain;

   procedure On_Lang_Clicked
     (W      : access GObject_Record'Class;
      Params : Glib.Values.GValues;
      Data   : Glib.Gint);
   --  Executed when a toggle renderer is selected

   procedure On_Toolchain_Clicked
     (W      : access GObject_Record'Class;
      Params : Glib.Values.GValues;
      Data   : Glib.Gint);
   --  Executed when a toolchain is selected

   procedure On_Scan_Clicked (W : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Executed when the 'Scan' button is clicked

   procedure On_Add_Clicked (W : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Executed when the 'Add' button is clicked

   procedure On_Tool_Value_Changed
     (Widget    : access Toolchains_Edit_Record'Class;
      Params    : Glib.Values.GValues;
      User_Data : Tool_Callback_User_Object);
   --  Executed when a value is changed in the Details view

   procedure On_Reset
     (Widget    : access Toolchains_Edit_Record'Class;
      Params    : Glib.Values.GValues;
      User_Data : Tool_Callback_User_Object);
   --  Executed when the reset button is clicked

   -------------
   -- Gtk_New --
   -------------

   function Create_Language_Page
     (Project     : Project_Type;
      Kernel      : access Kernel_Handle_Record'Class)
      return Toolchains_Edit
   is
      Editor          : Toolchains_Edit;
      Tc_Box          : Gtk.Box.Gtk_Hbox;
      Btn_Box         : Gtk.Box.Gtk_Vbox;
      Btn             : Gtk.Button.Gtk_Button;
      Col             : Gtk_Tree_View_Column;
      Col_Number      : Gint;
      pragma Unreferenced (Col_Number);
      Toggle_Renderer : Gtk_Cell_Renderer_Toggle;
      String_Renderer : Gtk_Cell_Renderer_Text;
      Frame           : Gtk_Frame;
      Scroll          : Gtk_Scrolled_Window;

   begin
      Editor := new Toolchains_Edit_Record;
      Gtk.Box.Initialize_Vbox (Editor);

      Editor.Kernel := GPS.Kernel.Kernel_Handle (Kernel);
      Editor.Mgr    := new GPS_Toolchain_Manager_Record;
      GPS_Toolchain_Manager_Record (Editor.Mgr.all).Kernel :=
        Editor.Kernel;

      --  Init the language selection part

      Gtk_New (Frame, -"Languages");
      Editor.Pack_Start (Frame, Expand => True, Fill => True, Padding => 5);
      Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Frame.Add (Scroll);

      Gtk.Tree_Store.Gtk_New (Editor.Lang_Model, Lang_Column_Types);
      Gtk.Tree_View.Gtk_New (Editor.Languages, Editor.Lang_Model);
      Scroll.Add (Editor.Languages);
      Editor.Languages.Get_Selection.Set_Mode (Gtk.Enums.Selection_None);

      Gtk_New (Col);
      Col_Number := Editor.Languages.Append_Column (Col);
      Gtk_New (Toggle_Renderer);
      Col.Pack_Start (Toggle_Renderer, False);
      Col.Add_Attribute (Toggle_Renderer, "active", Active_Column);
      Tree_Model_Callback.Object_Connect
        (Toggle_Renderer, Signal_Toggled,
         On_Lang_Clicked'Access,
         Slot_Object => Editor,
         User_Data   => Active_Column);

      Gtk_New (Col);
      Col_Number := Editor.Languages.Append_Column (Col);
      Gtk_New (String_Renderer);
      Col.Set_Title (-"Language");
      Col.Pack_Start (String_Renderer, False);
      Col.Add_Attribute (String_Renderer, "text", Name_Column);

      declare
         Langs : GNAT.OS_Lib.Argument_List :=
                   Language_Handlers.Known_Languages
                     (Get_Language_Handler (Kernel));
         Iter  : Gtk_Tree_Iter := Null_Iter;

      begin
         for J in Langs'Range loop
            Editor.Lang_Model.Append (Iter, Null_Iter);
            Editor.Lang_Model.Set (Iter, Active_Column, False);
            Editor.Lang_Model.Set (Iter, Name_Column, Langs (J).all);
            GNAT.OS_Lib.Free (Langs (J));
         end loop;
      end;

      --  Init the toolchains part

      Gtk_New (Frame, -"Toolchains");
      Editor.Pack_Start (Frame, Expand => True, Fill => True, Padding => 5);

      Gtk.Box.Gtk_New_Hbox (Tc_Box);
      Frame.Add (Tc_Box);

      Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Tc_Box.Pack_Start
        (Scroll, Expand => True, Fill => True, Padding => 0);

      Gtk.Tree_Store.Gtk_New (Editor.Model, Column_Types);
      Gtk.Tree_View.Gtk_New (Editor.Toolchains_Tree, Editor.Model);
      Scroll.Add (Editor.Toolchains_Tree);
      Editor.Toolchains_Tree.Get_Selection.Set_Mode (Gtk.Enums.Selection_None);

      --  Add columns to the tree view and connect them to the tree model
      Gtk_New (Col);
      Col_Number := Editor.Toolchains_Tree.Append_Column (Col);
      Gtk_New (Toggle_Renderer);
      Col.Pack_Start (Toggle_Renderer, False);
      Col.Add_Attribute (Toggle_Renderer, "active", Active_Column);
      Set_Radio_And_Callback
        (Editor.Model, Toggle_Renderer, Active_Column);
      Tree_Model_Callback.Object_Connect
        (Toggle_Renderer, Signal_Toggled,
         On_Toolchain_Clicked'Access,
         Slot_Object => Editor,
         User_Data   => Active_Column);

      Gtk_New (Col);
      Col_Number := Editor.Toolchains_Tree.Append_Column (Col);
      Gtk_New (String_Renderer);
      Col.Set_Title (-"Name");
      Col.Pack_Start (String_Renderer, False);
      Col.Add_Attribute (String_Renderer, "text", Label_Column);

      Gtk_New (Col);
      Col_Number := Editor.Toolchains_Tree.Append_Column (Col);
      Gtk_New (String_Renderer);
      Col.Set_Title (-"Location");
      Col.Pack_Start (String_Renderer, False);
      Col.Add_Attribute (String_Renderer, "text", Location_Column);

      Gtk_New (Col);
      Col_Number := Editor.Toolchains_Tree.Append_Column (Col);
      Gtk_New (String_Renderer);
      Col.Set_Title (-"Version");
      Col.Pack_Start (String_Renderer, False);
      Col.Add_Attribute (String_Renderer, "text", Version_Column);

      --  Now add the buttons for the toolchains
      Gtk.Box.Gtk_New_Vbox (Btn_Box);
      Tc_Box.Pack_Start (Btn_Box, Expand => False, Padding => 10);

      Gtk.Button.Gtk_New_From_Stock (Btn, Gtk.Stock.Stock_Find);
      Btn_Box.Pack_Start (Btn, Expand => False, Padding => 5);
      Widget_Callback.Object_Connect
        (Btn, Gtk.Button.Signal_Clicked, On_Scan_Clicked'Access,
         Slot_Object => Editor);

      Gtk.Button.Gtk_New_From_Stock (Btn, Gtk.Stock.Stock_Add);
      Btn_Box.Pack_Start (Btn, Expand => False, Padding => 5);
      Widget_Callback.Object_Connect
        (Btn, Gtk.Button.Signal_Clicked, On_Add_Clicked'Access,
         Slot_Object => Editor);

      --  Add the 'Details' part
      Gtk_New (Frame, -"Details");
      Editor.Pack_Start
        (Frame, Expand => True, Fill => True, Padding => 5);
      Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Frame.Add (Scroll);
      Gtk.Table.Gtk_New
        (Editor.Details_View,
         Rows        => 1,
         Columns     => 3,
         Homogeneous => False);
      Scroll.Add_With_Viewport (Editor.Details_View);

      Editor.Show_All;

      Set_Project (Editor, Project);

      return Editor;
   end Create_Language_Page;

   -----------------
   -- Set_Project --
   -----------------

   procedure Set_Project
     (Editor    : Toolchains_Edit;
      Project   : GNATCOLL.Projects.Project_Type)
   is
      Languages : constant GNAT.Strings.String_List :=
                    GNATCOLL.Projects.Languages (Project);
      Toolchain : Toolchains.Toolchain;
      Iter      : Gtk_Tree_Iter;

   begin
      Trace (Me, "Setting editor with project and language information");

      Editor.Edited_Prj := Project;

      Iter := Editor.Lang_Model.Get_Iter_First;

      while Iter /= Null_Iter loop
         Editor.Lang_Model.Set (Iter, Active_Column, False);

         for J in Languages'Range loop
            if Ada.Strings.Equal_Case_Insensitive
              (Editor.Lang_Model.Get_String (Iter, Name_Column),
               Languages (J).all)
            then
               Editor.Lang_Model.Set (Iter, Active_Column, True);
               Editor.Mgr.Add_Language (Languages (J).all, Project);
               exit;
            end if;
         end loop;

         Editor.Lang_Model.Next (Iter);
      end loop;

      Toolchain := Get_Toolchain (Editor.Mgr, Project, Languages);
      Add_Toolchain (Editor, Toolchain, True);
   end Set_Project;

   -------------------
   -- Get_Languages --
   -------------------

   function Get_Languages (Editor : Toolchains_Edit)
                           return GNAT.Strings.String_List_Access
   is
      Iter    : Gtk_Tree_Iter;
      N_Items : Natural := 0;
      Val     : GNAT.Strings.String_List_Access;
   begin

      Iter := Editor.Lang_Model.Get_Iter_First;

      while Iter /= Null_Iter loop
         if Editor.Lang_Model.Get_Boolean (Iter, Active_Column) then
            N_Items := N_Items + 1;
         end if;
         Editor.Lang_Model.Next (Iter);
      end loop;

      Val := new GNAT.Strings.String_List (1 .. N_Items);
      N_Items := 0;
      Iter := Editor.Lang_Model.Get_Iter_First;

      while Iter /= Null_Iter loop
         if Editor.Lang_Model.Get_Boolean (Iter, Active_Column) then
            N_Items := N_Items + 1;
            Val (N_Items) :=
              new String'(Editor.Lang_Model.Get_String (Iter, Name_Column));
         end if;
         Editor.Lang_Model.Next (Iter);
      end loop;

      return Val;
   end Get_Languages;

   ----------------------
   -- Generate_Project --
   ----------------------

   function Generate_Project
     (Editor    : Toolchains_Edit;
      Project   : Project_Type;
      Scenarii  : Scenario_Variable_Array) return Boolean
   is
      Tc      : constant Toolchain := Get_Selected_Toolchain (Editor);
      Iter    : Gtk_Tree_Iter;
      Val     : GNAT.Strings.String_List_Access;
      Old     : constant GNAT.Strings.String_List :=
                  GNATCOLL.Projects.Languages (Project);
      Modified : Boolean := False;
      Tmp_Modif : Boolean := False;

      procedure Set_Attribute
        (Attr : Attribute_Pkg_String;
         Idx  : String;
         Val  : String);
      procedure Clear_Attribute
        (Attr : Attribute_Pkg_String;
         Idx  : String);

      procedure Set_Attribute
        (Attr : Attribute_Pkg_String;
         Idx  : String;
         Val  : String) is
      begin
         if GNATCOLL.Projects.Attribute_Value
           (Project, Attr, Idx, "dummy-default-val") /= Val
         then
            GNATCOLL.Projects.Set_Attribute
              (Project,
               Attribute => Attr,
               Value     => Val,
               Scenario  => Scenarii,
               Index     => Idx);
            Modified := True;
         end if;
      end Set_Attribute;

      procedure Clear_Attribute
        (Attr : Attribute_Pkg_String;
         Idx  : String)
      is
      begin
         --  Use Attribute_Value here with a dummy value as default, as
         --  calls to Has_Attribute seems to be incorrect when an index is
         --  specified.
         if GNATCOLL.Projects.Attribute_Value
           (Project, Attr, Idx, "dummy-default-val") /= "dummy-default-val"
         then
            GNATCOLL.Projects.Delete_Attribute
              (Project, Attr, Scenarii, Idx);
            Modified := True;
         end if;
      end Clear_Attribute;

   begin
      Trace (Me, "Generate project");

      --  First save defined languages

      Val := Get_Languages (Editor);

      if Val'Length = Old'Length then
         for J in Val'Range loop
            Tmp_Modif := True;
            for K in Old'Range loop
               if Ada.Strings.Equal_Case_Insensitive
                    (Old (K).all, Val (J).all)
               then
                  Tmp_Modif := False;

                  exit;
               end if;
            end loop;

            exit when Tmp_Modif;
         end loop;
      else
         Tmp_Modif := True;
      end if;

      if Tmp_Modif then
         GNATCOLL.Projects.Set_Attribute
           (Project,
            Attribute => GNATCOLL.Projects.Languages_Attribute,
            Values    => Val.all,
            Scenario  => Scenarii);
      end if;

      GNAT.Strings.Free (Val);

      Modified := Tmp_Modif;

      --  Now save the toolchain

      Trace (Me, "Saving the GNAT driver");
      if not Toolchains.Is_Native (Tc)
        or else not Is_Default (Tc, GNAT_Driver)
      then
         Set_Attribute
           (GNATCOLL.Projects.GNAT_Attribute, "",
            Get_Command (Tc, GNAT_Driver));

      else
         Clear_Attribute (GNATCOLL.Projects.GNAT_Attribute, "");
      end if;

      Trace (Me, "Saving the GNAT ls attribute");
      if not Toolchains.Is_Native (Tc)
        or else not Is_Default (Tc, GNAT_List)
      then
         Set_Attribute
           (GNATCOLL.Projects.Gnatlist_Attribute, "",
            Get_Command (Tc, GNAT_List));
      else
         Clear_Attribute (GNATCOLL.Projects.Gnatlist_Attribute, "");
      end if;

      Trace (Me, "Saving the Debugger attribute");
      if not Toolchains.Is_Native (Tc)
          or else not Is_Default (Tc, Debugger)
      then
         Set_Attribute
           (GNATCOLL.Projects.Debugger_Command_Attribute, "",
            Get_Command (Tc, Debugger));
      else
         Clear_Attribute (GNATCOLL.Projects.Debugger_Command_Attribute, "");
      end if;

      --  Now see if individual compiler drivers have been explicitely set

      Iter := Editor.Lang_Model.Get_Iter_First;

      while Iter /= Null_Iter loop
         declare
            Lang : constant String :=
                     To_Lower
                       (Editor.Lang_Model.Get_String (Iter, Name_Column));
         begin
            if Editor.Lang_Model.Get_Boolean (Iter, Active_Column) then
               if not Is_Native (Tc)
                 or else not Is_Default (Tc, Lang)
               then
                  Set_Attribute
                    (GNATCOLL.Projects.Compiler_Driver_Attribute,
                     Lang,
                     Get_Exe (Get_Compiler (Tc, Lang)));
               else
                  Clear_Attribute
                    (GNATCOLL.Projects.Compiler_Driver_Attribute, Lang);
               end if;

               --  Remove the compiler command attribute from the IDE package
               --  if needed
               Clear_Attribute
                 (GNATCOLL.Projects.Compiler_Command_Attribute, Lang);

            else
               Clear_Attribute
                 (GNATCOLL.Projects.Compiler_Driver_Attribute, Lang);
               Clear_Attribute
                 (GNATCOLL.Projects.Compiler_Command_Attribute, Lang);
            end if;
         end;

         Editor.Lang_Model.Next (Iter);
      end loop;

--        if not Is_Native (Tc) then
--           GNATCOLL.Projects.Set_Attribute
--             (Project,
--              Attribute => GNATCOLL.Projects.Compiler_Command_Attribute,
--              Value     => Get_Exe (Get_Compiler (Tc, "Ada")),
--              Scenario  => Scenarii,
--              Index     => "Ada");
--        end if;
      return Modified;
   end Generate_Project;

   -------------------
   -- Add_Toolchain --
   -------------------

   procedure Add_Toolchain
     (Editor          : Toolchains_Edit;
      Tc              : Toolchains.Toolchain;
      Force_Selected : Boolean)
   is
      Iter      : Gtk_Tree_Iter;
      Infos     : Ada_Library_Info_Access;
      Name      : constant String := Toolchains.Get_Name (Tc);

   begin
      Toolchains.Compute_Predefined_Paths (Tc);
      Infos := Toolchains.Get_Library_Information (Tc);

      if Force_Selected then
         --  First deselect any previously selected toolchain
         Iter := Editor.Model.Get_Iter_First;
         while Iter /= Null_Iter loop
            Editor.Model.Set (Iter, Active_Column, False);
            Editor.Model.Next (Iter);
         end loop;
      end if;

      Iter := Editor.Model.Get_Iter_First;
      while Iter /= Null_Iter loop
         exit when Editor.Model.Get_String (Iter, Name_Column) = Name;
         Editor.Model.Next (Iter);
      end loop;

      if Iter = Null_Iter then
         Editor.Model.Append (Iter, Null_Iter);
      end if;

      if Force_Selected then
         Editor.Model.Set
           (Iter, Active_Column, True);
         Editor.Toolchain := Tc;
      end if;

      Editor.Model.Set
        (Iter, Name_Column,
         Toolchains.Get_Name (Tc));
      Editor.Model.Set
        (Iter, Label_Column,
         Toolchains.Get_Label (Tc));
      Editor.Model.Set
        (Iter, Location_Column,
         Toolchains.Get_Install_Path (Infos.all).Display_Full_Name (True));
      Editor.Model.Set
        (Iter, Version_Column,
         Toolchains.Get_Version (Infos.all));

      Update_Details (Editor);
   end Add_Toolchain;

   ----------------
   -- Set_Detail --
   ----------------

   procedure Set_Detail
     (Label      : Gtk_Label;
      GEntry     : Gtk_Entry;
      Icon       : Gtk_Image;
      Reset_Btn  : Gtk_Button;
      Kind       : Tool_Kind;
      Tool       : Toolchains.Tools;
      Lang       : String;
      Value      : String;
      Is_Default : Boolean;
      Is_Valid   : Boolean)
   is
      function Get_String return String;

      function Format_String return String;

      function Get_String return String is
      begin
         if Kind = Tool_Kind_Tool then
            case Tool is
               when GNAT_Driver =>
                  return "GNAT Driver:";
               when GNAT_List =>
                  return "GNAT List:";
               when Debugger =>
                  return "Debugger:";
               when CPP_Filt =>
                  return "C++ Filt:";
               when Unknown =>
                  return "";
            end case;

         else
            return Lang & ":";
         end if;
      end Get_String;

      function Format_String return String is
      begin
         if not Is_Valid then
            return
              "<span color=""red"">" & Get_String & "</span>";
         else
            return Get_String;
         end if;
      end Format_String;

   begin
      Label.Set_Text (Format_String);
      Label.Set_Use_Markup (True);
      Label.Set_Alignment (0.0, 0.0);

      GEntry.Set_Text (Value);
      if Kind = Tool_Kind_Tool and then Tool = GNAT_Driver then
         GEntry.Set_Sensitive (False);
      end if;

      if not Is_Valid then
         Set (Icon, Stock_Dialog_Warning, Icon_Size_Button);

         if Value = "" then
            Label.Set_Tooltip_Text
              (-"Value not defined for this target");
            GEntry.Set_Tooltip_Text
              (-"Value not defined for this target");
            Icon.Set_Tooltip_Text
              (-"Value not defined for this target");
         else
            Label.Set_Tooltip_Text
              (Value & (-" cannot be found on the PATH"));
            GEntry.Set_Tooltip_Text
              (Value & (-" cannot be found on the PATH"));
            Icon.Set_Tooltip_Text
              (Value & (-" cannot be found on the PATH"));
         end if;
      else
         Set (Icon, "", Icon_Size_Button);
         Label.Set_Has_Tooltip (False);
         GEntry.Set_Has_Tooltip (False);
         Icon.Set_Has_Tooltip (False);
      end if;

      if Reset_Btn /= null then
         Reset_Btn.Set_Sensitive (not Is_Default);
      end if;
   end Set_Detail;

   --------------------
   -- Update_Details --
   --------------------

   procedure Update_Details
     (Editor : Toolchains_Edit)
   is
      W      : Gtk_Widget;
      Iter   : Gtk_Tree_Iter;
      Tc     : constant Toolchain := Get_Selected_Toolchain (Editor);
      Lbl    : Gtk_Label;
      N_Rows : Guint := 0;
      N_Cols : constant Guint := 4;

      procedure Add_Detail
        (Kind       : Tool_Kind;
         Tool       : Toolchains.Tools;
         Lang       : String;
         Value      : String;
         Is_Default : Boolean;
         Is_Valid   : Boolean);

      procedure Add_Detail
        (Kind       : Tool_Kind;
         Tool       : Toolchains.Tools;
         Lang       : String;
         Value      : String;
         Is_Default : Boolean;
         Is_Valid   : Boolean)
      is
         Lbl : Gtk_Label;
         Ent : Gtk_Entry;
         Icn : Gtk_Image;
         Btn : Gtk_Button := null;

      begin
         N_Rows := N_Rows + 1;
         Editor.Details_View.Resize (N_Rows, N_Cols);

         Gtk_New (Lbl);
         Editor.Details_View.Attach
           (Child         => Lbl,
            Left_Attach   => 0,
            Right_Attach  => 1,
            Top_Attach    => N_Rows - 1,
            Bottom_Attach => N_Rows,
            Xoptions      => Gtk.Enums.Fill,
            Xpadding      => 20);

         Gtk_New (Ent);
         Editor.Details_View.Attach
           (Child         => Ent,
            Left_Attach   => 1,
            Right_Attach  => 2,
            Top_Attach    => N_Rows - 1,
            Bottom_Attach => N_Rows);
         Ent.Add_Events (Gdk.Event.Leave_Notify_Mask);

         Gtk_New (Icn);
         Editor.Details_View.Attach
           (Child         => Icn,
            Left_Attach   => 2,
            Right_Attach  => 3,
            Top_Attach    => N_Rows - 1,
            Bottom_Attach => N_Rows,
            Xoptions      => 0);

         if Kind /= Tool_Kind_Tool
           or else Tool /= GNAT_Driver
         then
            Gtk_New (Btn, "reset");
            Editor.Details_View.Attach
              (Child         => Btn,
               Left_Attach   => 3,
               Right_Attach  => 4,
               Top_Attach    => N_Rows - 1,
               Bottom_Attach => N_Rows,
               Xoptions      => 0);
            Tool_Callback.Object_Connect
              (Btn, Gtk.Button.Signal_Clicked,
               On_Reset'Access,
               Slot_Object => Editor,
               User_Data   => Tool_Callback_User_Object'
                 (Kind      => Kind,
                  Lang      => To_Unbounded_String (Lang),
                  Tool_Name => Tool,
                  Label     => Lbl,
                  Value     => Ent,
                  Icon      => Icn,
                  Reset_Btn => Btn));
         end if;

         Tool_Callback.Object_Connect
           (Ent, Gtk.Editable.Signal_Changed,
            On_Tool_Value_Changed'Access,
            Slot_Object => Editor,
            User_Data   => Tool_Callback_User_Object'
              (Kind      => Kind,
               Lang      => To_Unbounded_String (Lang),
               Tool_Name => Tool,
               Label     => Lbl,
               Value     => Ent,
               Icon      => Icn,
               Reset_Btn => Btn));

         Set_Detail
           (Lbl, Ent, Icn, Btn, Kind, Tool, Lang, Value, Is_Default, Is_Valid);
      end Add_Detail;

   begin
      Trace (Me, "Update_Details called");

      Editor.Updating := True;

      while Gtk.Widget.Widget_List.Length
        (Editor.Details_View.Children) > 0
      loop
         W := Gtk.Widget.Widget_List.Get_Data (Editor.Details_View.Children);
         Editor.Details_View.Remove (W);
      end loop;

      Editor.Updating := False;

      if Tc = Null_Toolchain then
         return;
      end if;

      N_Rows := N_Rows + 1;
      Editor.Details_View.Resize (N_Rows, N_Cols);

      Gtk_New
        (Lbl,
         -("<i>This section allows you to modify individual tools for the" &
           " selected toolchain." & ASCII.LF &
           "To select a full toolchain, use the 'Add' or 'Scan' buttons " &
           "above</i>"));
      Lbl.Set_Use_Markup (True);
      Lbl.Set_Alignment (0.0, 0.5);
      Editor.Details_View.Attach
        (Child         => Lbl,
         Left_Attach   => 0,
         Right_Attach  => N_Cols,
         Top_Attach    => N_Rows - 1,
         Bottom_Attach => N_Rows,
         Xpadding      => 0,
         Ypadding      => 5);

      N_Rows := N_Rows + 1;
      Editor.Details_View.Resize (N_Rows, N_Cols);

      Gtk_New
        (Lbl, "<b>Tools:</b>");
      Lbl.Set_Use_Markup (True);
      Lbl.Set_Alignment (0.0, 0.5);
      Editor.Details_View.Attach
        (Child         => Lbl,
         Left_Attach   => 0,
         Right_Attach  => N_Cols,
         Top_Attach    => N_Rows - 1,
         Bottom_Attach => N_Rows,
         Xpadding      => 0,
         Ypadding      => 5);

      for J in Tools range GNAT_Driver .. Debugger loop
         Add_Detail
           (Tool_Kind_Tool,
            Tool       => J,
            Lang       => "",
            Value      => Get_Command (Tc, J),
            Is_Default => Is_Default (Tc, J),
            Is_Valid   => Is_Valid (Tc, J));
      end loop;

      N_Rows := N_Rows + 1;
      Editor.Details_View.Resize (N_Rows, N_Cols);

      Gtk_New
        (Lbl,
         "<b>Compilers:</b>");
      Lbl.Set_Use_Markup (True);
      Lbl.Set_Alignment (0.0, 0.5);
      Editor.Details_View.Attach
        (Child         => Lbl,
         Left_Attach   => 0,
         Right_Attach  => N_Cols,
         Top_Attach    => N_Rows - 1,
         Bottom_Attach => N_Rows,
         Xpadding      => 0,
         Ypadding      => 5);

      Iter := Get_Iter_First (Editor.Lang_Model);

      while Iter /= Null_Iter loop
         if Get_Boolean (Editor.Lang_Model, Iter, Active_Column) then
            declare
               Lang : constant String :=
                        Get_String (Editor.Lang_Model, Iter, Name_Column);
               C    : constant Compiler := Get_Compiler (Tc, Lang);
            begin
               Add_Detail
                 (Tool_Kind_Compiler,
                  Tool       => Unknown,
                  Lang       => Lang,
                  Value      => Get_Exe (C),
                  Is_Default => Is_Default (Tc, Lang),
                  Is_Valid   => Is_Valid (C));
            end;
         end if;

         Editor.Lang_Model.Next (Iter);
      end loop;

      Editor.Details_View.Show_All;
   end Update_Details;

   ---------------------------
   -- On_Tool_Value_Changed --
   ---------------------------

   procedure On_Tool_Value_Changed
     (Widget    : access Toolchains_Edit_Record'Class;
      Params    : Glib.Values.GValues;
      User_Data : Tool_Callback_User_Object)
   is
      pragma Unreferenced (Params);
      Tc   : constant Toolchain := Get_Selected_Toolchain (Widget);
      Val  : constant String := User_Data.Value.Get_Text;
      Lang : constant String := To_String (User_Data.Lang);

   begin
      if Widget.Updating then
         return;
      end if;

      Trace (Me, "Tool value lost focus, verify its state");
      case User_Data.Kind is
         when Tool_Kind_Tool =>
            if Toolchains.Get_Command (Tc, User_Data.Tool_Name) /= Val then
               Toolchains.Set_Command (Tc, User_Data.Tool_Name, Val);
               Set_Detail
                 (Label      => User_Data.Label,
                  GEntry     => User_Data.Value,
                  Icon       => User_Data.Icon,
                  Reset_Btn  => User_Data.Reset_Btn,
                  Kind       => User_Data.Kind,
                  Tool       => User_Data.Tool_Name,
                  Lang       => Lang,
                  Value      => Val,
                  Is_Default => Is_Default (Tc, User_Data.Tool_Name),
                  Is_Valid   => Is_Valid (Tc, User_Data.Tool_Name));
            end if;

         when Tool_Kind_Compiler =>
            if Get_Exe (Get_Compiler (Tc, Lang)) /= Val then
               Set_Compiler (Tc, Lang, Val);
               Set_Detail
                 (Label      => User_Data.Label,
                  GEntry     => User_Data.Value,
                  Icon       => User_Data.Icon,
                  Reset_Btn  => User_Data.Reset_Btn,
                  Kind       => User_Data.Kind,
                  Tool       => User_Data.Tool_Name,
                  Lang       => Lang,
                  Value      => Val,
                  Is_Default => Is_Default (Tc, Lang),
                  Is_Valid   => Is_Valid (Get_Compiler (Tc, Lang)));
            end if;

      end case;

   exception
      when E : others =>
         Trace (Exception_Handle, E);
   end On_Tool_Value_Changed;

   --------------
   -- On_Reset --
   --------------

   procedure On_Reset
     (Widget    : access Toolchains_Edit_Record'Class;
      Params    : Glib.Values.GValues;
      User_Data : Tool_Callback_User_Object)
   is
      pragma Unreferenced (Params);
      Tc   : constant Toolchain := Get_Selected_Toolchain (Widget);
      Lang : constant String := To_String (User_Data.Lang);
   begin
      case User_Data.Kind is
         when Tool_Kind_Tool =>
            Toolchains.Reset_To_Default (Tc, User_Data.Tool_Name);
            Set_Detail
              (Label      => User_Data.Label,
               GEntry     => User_Data.Value,
               Icon       => User_Data.Icon,
               Reset_Btn  => User_Data.Reset_Btn,
               Kind       => User_Data.Kind,
               Tool       => User_Data.Tool_Name,
               Lang       => Lang,
               Value      => Get_Command (Tc, User_Data.Tool_Name),
               Is_Default => Is_Default (Tc, User_Data.Tool_Name),
               Is_Valid   => Is_Valid (Tc, User_Data.Tool_Name));

         when Tool_Kind_Compiler =>
            Toolchains.Reset_To_Default (Tc, Lang);
            Set_Detail
              (Label      => User_Data.Label,
               GEntry     => User_Data.Value,
               Icon       => User_Data.Icon,
               Reset_Btn  => User_Data.Reset_Btn,
               Kind       => User_Data.Kind,
               Tool       => User_Data.Tool_Name,
               Lang       => Lang,
               Value      => Get_Exe (Get_Compiler (Tc, Lang)),
               Is_Default => Is_Default (Tc, Lang),
               Is_Valid   => Is_Valid (Get_Compiler (Tc, Lang)));
      end case;
   end On_Reset;

   ----------------------------
   -- Get_Selected_Toolchain --
   ----------------------------

   function Get_Selected_Toolchain
     (Editor : access Toolchains_Edit_Record'Class) return Toolchain
   is
   begin
      return Editor.Toolchain;
   end Get_Selected_Toolchain;

   ---------------------
   -- Toggle_Callback --
   ---------------------

   procedure On_Lang_Clicked
     (W      : access GObject_Record'Class;
      Params : Glib.Values.GValues;
      Data   : Glib.Gint)
   is
      Editor      : constant Toolchains_Edit := Toolchains_Edit (W);
      Iter        : Gtk_Tree_Iter;
      Path_String : constant String := Get_String (Nth (Params, 1));

   begin
      Iter := Get_Iter_From_String (Editor.Lang_Model, Path_String);

      if Iter /= Null_Iter then
         Set (Editor.Lang_Model, Iter, Data,
              not Get_Boolean (Editor.Lang_Model, Iter, Data));

         declare
            Lang : constant String :=
                     Get_String (Editor.Lang_Model, Iter, Name_Column);
         begin
            if Get_Boolean (Editor.Lang_Model, Iter, Data) then
               Editor.Mgr.Add_Language (Lang, Editor.Edited_Prj);
            end if;
         end;
      end if;

      Update_Details (Editor);

   exception
      when E : others => Trace (Exception_Handle, E);
   end On_Lang_Clicked;

   --------------------------
   -- On_Toolchain_Clicked --
   --------------------------

   procedure On_Toolchain_Clicked
     (W      : access GObject_Record'Class;
      Params : Glib.Values.GValues;
      Data   : Glib.Gint)
   is
      pragma Unreferenced (Data);
      Editor      : constant Toolchains_Edit := Toolchains_Edit (W);
      Iter        : Gtk_Tree_Iter;
      Path_String : constant String := Get_String (Nth (Params, 1));

   begin
      Iter := Get_Iter_From_String (Editor.Model, Path_String);

      if Iter /= Null_Iter then
         Editor.Toolchain :=
           Get_Toolchain
             (Editor.Mgr, Editor.Model.Get_String (Iter, Label_Column));
      else
         Editor.Toolchain := Null_Toolchain;
      end if;

      Trace (Me, "Toolchain clicked");
      Update_Details (Editor);
   end On_Toolchain_Clicked;

   ---------------------
   -- On_Scan_Clicked --
   ---------------------

   procedure On_Scan_Clicked (W : access Gtk.Widget.Gtk_Widget_Record'Class) is
      Editor : constant Toolchains_Edit := Toolchains_Edit (W);

   begin
      Scan_Toolchains (Editor.Mgr);

      declare
         TC_Array : constant Toolchain_Array := Get_Toolchains (Editor.Mgr);
      begin
         for J in TC_Array'Range loop
            if not Has_Errors (Get_Library_Information (TC_Array (J)).all) then
               Add_Toolchain (Editor, TC_Array (J), False);
            end if;
         end loop;
      end;

      Update_Details (Editor);

   exception
      when E : others => Trace (Exception_Handle, E);
   end On_Scan_Clicked;

   --------------------
   -- On_Add_Clicked --
   --------------------

   procedure On_Add_Clicked (W : access Gtk.Widget.Gtk_Widget_Record'Class) is
      Editor     : constant Toolchains_Edit := Toolchains_Edit (W);
      Dialog     : Gtk.Dialog.Gtk_Dialog;
      Name_Entry : Gtk.Combo_Box_Entry.Gtk_Combo_Box_Entry;
      Name_Model : Gtk.Tree_Store.Gtk_Tree_Store;
      Btn        : Gtk_Widget;
      Res        : Gtk_Response_Type;
      Iter       : Gtk_Tree_Iter := Null_Iter;
      pragma Unreferenced (Btn);

   begin
      Gtk.Dialog.Gtk_New
        (Dialog, -"New toolchain",
         Gtk_Window (Editor.Get_Toplevel),
         Modal);
      Gtk.Tree_Store.Gtk_New (Name_Model, (0 => GType_String));
      Gtk.Combo_Box_Entry.Gtk_New_With_Model (Name_Entry, Name_Model, 0);
      Dialog.Get_Content_Area.Pack_Start (Name_Entry, False, False, 5);

      for J in Known_Toolchains'Range loop
         Name_Model.Append (Iter, Null_Iter);
         Name_Model.Set (Iter, 0, Known_Toolchains (J).all);
      end loop;

      Btn := Dialog.Add_Button
        (Gtk.Stock.Stock_Ok, Response_Id => Gtk_Response_OK);
      Btn := Dialog.Add_Button
        (Gtk.Stock.Stock_Cancel, Response_Id => Gtk_Response_Cancel);

      Dialog.Show_All;
      Res := Dialog.Run;
      Dialog.Hide;

      if Res = Gtk_Response_OK then
         declare
            Name : constant String := Name_Entry.Get_Active_Text;
            Tc   : Toolchain;
         begin
            if Name = "" or else Index (Name, "native") in Name'Range then
               Trace (Me, "Adding a native toolchain");
               Tc := Editor.Mgr.Get_Native_Toolchain;

            elsif Is_Known_Toolchain_Name (Name) then
               Trace (Me, "Adding a known toolchain");
               Tc := Get_Toolchain (Editor.Mgr, Name);

            else
               Trace (Me, "Adding a new toolchain");
               Tc := Create_Empty_Toolchain (Editor.Mgr);
               Set_Name (Tc, Name);
               Set_Command (Tc, GNAT_Driver, Name & "-gnat");
               Editor.Mgr.Add_Toolchain (Tc);
            end if;

            Add_Toolchain (Editor, Tc, True);
         end;
      end if;
   end On_Add_Clicked;

   -------------
   -- Execute --
   -------------

   overriding function Execute
     (This       : GPS_Toolchain_Manager_Record;
      Command    : String;
      Timeout_MS : Integer) return String
   is
      procedure Free is new Ada.Unchecked_Deallocation
        (GNAT.Expect.Process_Descriptor'Class,
         GNAT.Expect.Process_Descriptor_Access);
      Status    : Boolean;
      Pd        : GNAT.Expect.Process_Descriptor_Access;
      Match     : Expect_Match := 0;
      Ret       : Unbounded_String;
      Args      : constant Arg_List :=
                    GNATCOLL.Arg_Lists.Parse_String (Command, Separate_Args);

   begin
      --  If no such command exist, no need to try to spawn it
      if Locate_On_Path (+Get_Command (Args), Get_Nickname (Build_Server)) =
        No_File
      then
         raise GNAT.Expect.Process_Died;
      end if;

      GPS.Kernel.Remote.Spawn
        (This.Kernel, GNATCOLL.Arg_Lists.Parse_String (Command, Separate_Args),
         Remote.Build_Server, Pd, Status);

      if not Status then
         raise GNAT.Expect.Process_Died;
      else
         declare
         begin
            loop
               Expect (Pd.all, Match, "\n", Timeout_MS);

               if Match = Expect_Timeout then
                  Status := False;
                  Close (Pd.all);
                  exit;
               end if;

               Ada.Strings.Unbounded.Append (Ret, Expect_Out (Pd.all));
            end loop;
         exception
            when Process_Died =>
               Free (Pd);
         end;

         return To_String (Ret);
      end if;
   end Execute;

end Toolchains_Editor;
