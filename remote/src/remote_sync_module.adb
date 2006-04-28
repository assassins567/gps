-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2006                         --
--                              AdaCore                              --
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

with Ada.Exceptions;         use Ada.Exceptions;
with GNAT.OS_Lib;            use GNAT.OS_Lib;
with GNAT.Regpat;            use GNAT.Regpat;
with GNAT.Expect;            use GNAT.Expect;
pragma Warnings (Off);
with GNAT.Expect.TTY.Remote; use GNAT.Expect.TTY.Remote;
pragma Warnings (On);

with Glib;               use Glib;
with Glib.Xml_Int;       use Glib.Xml_Int;
with Gtk.Box;            use Gtk.Box;
with Gtk.Dialog;         use Gtk.Dialog;
with Gtk.Label;          use Gtk.Label;
with Gtk.Progress_Bar;   use Gtk.Progress_Bar;
with Gtk.Main;

with GPS.Intl;           use GPS.Intl;
with GPS.Kernel.Console; use GPS.Kernel.Console;
with GPS.Kernel.Hooks;   use GPS.Kernel.Hooks;
with GPS.Kernel.Modules; use GPS.Kernel.Modules;
with GPS.Kernel.Remote;  use GPS.Kernel.Remote;
with GPS.Kernel.Timeout; use GPS.Kernel.Timeout;

with Commands;           use Commands;
with Filesystem;         use Filesystem;
with Password_Manager;   use Password_Manager;
with String_Utils;       use String_Utils;
with Traces;             use Traces;
with VFS;                use VFS;

package body Remote_Sync_Module is

   Me : constant Debug_Handle := Create ("remote_sync_module");

   type Rsync_Module_Record is new Module_ID_Record with record
      Kernel     : Kernel_Handle;
      Rsync_Args : String_List_Access;
   end record;
   type Rsync_Module_ID is access all Rsync_Module_Record'Class;

   procedure Customize
     (Module : access Rsync_Module_Record;
      File   : VFS.Virtual_File;
      Node   : Node_Ptr;
      Level  : Customization_Level);
   --  See doc for inherited subprogram

   Rsync_Module : Rsync_Module_ID := null;

   type Rsync_Dialog_Record is new Gtk.Dialog.Gtk_Dialog_Record with record
      Progress : Gtk.Progress_Bar.Gtk_Progress_Bar;
   end record;
   type Rsync_Dialog is access all Rsync_Dialog_Record'Class;

   procedure Gtk_New (Dialog : out Rsync_Dialog;
                      Kernel : access Kernel_Handle_Record'Class;
                      Src_Path, Dest_Path : String);
   --  Creates a new Rsync_Dialog

   type Rsync_Callback_Data is new Callback_Data_Record with record
      Network_Name      : String_Access;
      User_Name         : String_Access;
      Nb_Password_Tries : Natural;
      Synchronous       : Boolean;
      Dialog            : Rsync_Dialog;
      Dialog_Shown      : Boolean;
      Status            : Integer;
   end record;

   function On_Rsync_Hook
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class) return Boolean;
   --  run RSync hook

   procedure Parse_Rsync_Output
     (Data : Process_Data; Output : String);
   --  Called whenever new output from rsync is available

   procedure Rsync_Terminated
     (Data : Process_Data; Status : Integer);
   --  Called when rsync exits.

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module (Kernel : Kernel_Handle) is
   begin
      --  Register the module
      Rsync_Module := new Rsync_Module_Record;
      Rsync_Module.Kernel := Kernel;
      Register_Module
        (Rsync_Module, Kernel, "rsync");

      Add_Hook (Kernel, Rsync_Action_Hook,
                Wrapper (On_Rsync_Hook'Access),
                "rsync");
   end Register_Module;

   ---------------
   -- Customize --
   ---------------

   procedure Customize
     (Module : access Rsync_Module_Record;
      File   : VFS.Virtual_File;
      Node   : Node_Ptr;
      Level  : Customization_Level)
   is
      pragma Unreferenced (File, Level);
      Child   : Node_Ptr;
   begin
      if Node.Tag.all = "rsync_configuration" then
         Trace (Me, "Customize: 'rsync_configuration'");
         Child := Find_Tag (Node.Child, "arguments");
         if Child /= null then
            Module.Rsync_Args := Argument_String_To_List (Child.Value.all);
         end if;
      end if;
   end Customize;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New (Dialog : out Rsync_Dialog;
                      Kernel : access Kernel_Handle_Record'Class;
                      Src_Path, Dest_Path : String) is
      Label : Gtk_Label;
   begin
      Dialog := new Rsync_Dialog_Record;
      Initialize (Dialog, -"Synchronisation in progress",
                  Get_Main_Window (Kernel), 0);
      Set_Has_Separator (Dialog, False);
      Gtk_New (Label, -"Synchronisation with remote host in progress.");
      Pack_Start (Get_Vbox (Dialog), Label);
      Gtk_New (Label);
      Set_Markup (Label, (-"From: ") & "<span foreground=""blue"">" &
                  Src_Path & "</span>");
      Pack_Start (Get_Vbox (Dialog), Label);
      Gtk_New (Label);
      Set_Markup (Label, (-"To: ") & "<span foreground=""blue"">" &
                  Dest_Path & "</span>");
      Pack_Start (Get_Vbox (Dialog), Label);
      Gtk_New (Dialog.Progress);
      Pack_Start (Get_Vbox (Dialog), Dialog.Progress);
   end Gtk_New;

   -------------------
   -- On_Rsync_Hook --
   -------------------

   function On_Rsync_Hook
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class) return Boolean
   is
      Rsync_Data    : Rsync_Hooks_Args renames Rsync_Hooks_Args (Data.all);
      Src_Path      : String_Access;
      Dest_Path     : String_Access;
      Src_FS        : Filesystem_Access;
      Dest_FS       : Filesystem_Access;
      Machine       : Machine_Descriptor;
      Success       : Boolean;
      Transport_Arg : String_Access;
      Cb_Data       : Rsync_Callback_Data;

      function  Build_Arg return String_List;
      --  Build rsync arguments

      ---------------
      -- Build_Arg --
      ---------------

      function Build_Arg return String_List is
         Rsync_Args    : constant String_List
           := Clone (Rsync_Module.Rsync_Args.all);
      begin
         if Transport_Arg /= null then
            if Rsync_Data.Sync_Deleted then
               return (1 => new String'("--delete")) &
                      Rsync_Args & Transport_Arg & Src_Path & Dest_Path;
            else
               return (1 => new String'("--update")) &
                      Rsync_Args & Transport_Arg & Src_Path & Dest_Path;
            end if;
         else
            if Rsync_Data.Sync_Deleted then
               return (1 => new String'("--delete")) &
                      Rsync_Args & Src_Path & Dest_Path;
            else
               return (1 => new String'("--update")) &
                      Rsync_Args & Src_Path & Dest_Path;
            end if;
         end if;
      end Build_Arg;
   begin
      --  Check that we want to use rsync
      if Rsync_Data.Tool_Name /= "rsync" then
         return False;
      end if;

      --  Check the module configuration
      if Rsync_Module = null or else Rsync_Module.Rsync_Args = null then
         Insert (Kernel, "Invalid rsync configuration. Cannot use rsync.",
                 Mode => Error);
         return False;
      end if;

      if Rsync_Data.Src_Name = "" then
         --  Local src machine, remote dest machine
         Machine := Get_Machine_Descriptor (Rsync_Data.Dest_Name);
         Src_FS    := new Filesystem_Record'Class'(Get_Local_Filesystem);
         Src_Path  := new String'
           (To_Unix (Src_FS.all, Rsync_Data.Src_Path, True));
         Dest_FS   := new Filesystem_Record'Class'
           (Get_Filesystem (Rsync_Data.Dest_Name));
         if Machine.User_Name.all /= "" then
            Dest_Path := new String'
              (Machine.User_Name.all & "@" &
               Machine.Network_Name.all & ":" &
               To_Unix (Dest_FS.all, Rsync_Data.Dest_Path, True));
         else
            Dest_Path := new String'
              (Machine.Network_Name.all & ":" &
               To_Unix (Dest_FS.all, Rsync_Data.Dest_Path, True));
         end if;
      else
         --  Remote src machine, local dest machine
         Machine := Get_Machine_Descriptor (Rsync_Data.Src_Name);
         Src_FS    := new Filesystem_Record'Class'
           (Get_Filesystem (Rsync_Data.Src_Name));
         if Machine.User_Name.all /= "" then
            Src_Path  := new String'
              (Machine.User_Name.all & "@" &
               Machine.Network_Name.all & ":" &
               To_Unix (Src_FS.all, Rsync_Data.Src_Path, True));
         else
            Src_Path  := new String'
              (Machine.Network_Name.all & ":" &
               To_Unix (Src_FS.all, Rsync_Data.Src_Path, True));
         end if;
         Dest_FS   := new Filesystem_Record'Class'(Get_Local_Filesystem);
         Dest_Path := new String'
           (To_Unix (Dest_FS.all, Rsync_Data.Dest_Path, True));
      end if;

      if Machine = null then
         return False;
      end if;

      if Machine.Access_Name.all = "ssh" then
         Transport_Arg := new String'("--rsh=ssh");
      end if;

      Cb_Data := (Network_Name      => Machine.Network_Name,
                  User_Name         => Machine.User_Name,
                  Nb_Password_Tries => 0,
                  Synchronous       => Rsync_Data.Synchronous,
                  Dialog            => null,
                  Dialog_Shown      => False,
                  Status            => 0);

      if Rsync_Data.Synchronous then
         Gtk_New (Cb_Data.Dialog, Kernel, Src_Path.all, Dest_Path.all);
      end if;

      --  Do not set Line_By_Line as this will prevent the password prompt
      --  catch.
      Launch_Process
        (Kernel_Handle (Kernel),
         Command       => "rsync",
         Arguments     => Build_Arg,
         Console       => Get_Console (Kernel),
         Show_Command  => False,
         Show_Output   => False,
         Success       => Success,
         Line_By_Line  => False,
         Callback      => Parse_Rsync_Output'Access,
         Exit_Cb       => Rsync_Terminated'Access,
         Callback_Data => new Rsync_Callback_Data'(Cb_Data),
         Queue_Id      => Rsync_Data.Queue_Id,
         Synchronous   => Rsync_Data.Synchronous,
         Timeout       => Machine.Timeout);

      Free (Src_Path);
      Free (Dest_Path);
      Free (Transport_Arg);

      if Rsync_Data.Synchronous and then Cb_Data.Status /= 0 then
         Success := False;
      end if;
      --  ??? Free rsync_data structure

      return Success;
   end On_Rsync_Hook;

   ------------------------
   -- Parse_Rsync_Output --
   ------------------------

   procedure Parse_Rsync_Output
     (Data : Process_Data; Output : String)
   is
      Progress_Regexp : constant Pattern_Matcher := Compile
        ("^.*\(([0-9]*), [0-9.%]* of ([0-9]*)", Multiple_Lines);
      Matched         : Match_Array (0 .. 2);
      File_Nb         : Natural;
      Total_Files     : Natural;
      Force           : Boolean;
      Cb_Data         : Rsync_Callback_Data renames
        Rsync_Callback_Data (Data.Callback_Data.all);
      Dead            : Boolean;
      pragma Unreferenced (Dead);
   begin
      Trace (Me, "Parse_Rsync_Output: '" & Output & "'");

      if not Data.Process_Died then
         --  Retrieve password prompt if any
         Match (Get_Default_Password_Regexp,
                Output,
                Matched);
         if Matched (0) /= No_Match then
            Force := Cb_Data.Nb_Password_Tries > 0;
            Cb_Data.Nb_Password_Tries := Cb_Data.Nb_Password_Tries + 1;

            declare
               Password : constant String :=
                            Get_Password (Get_Main_Window (Data.Kernel),
                                          Cb_Data.Network_Name.all,
                                          Cb_Data.User_Name.all,
                                          Force);
            begin
               if Password = "" then
                  Interrupt (Data.Descriptor.all);
               else
                  Send (Data.Descriptor.all, Password);
               end if;
            end;

            return;
         end if;

         --  Retrieve passphrase prompt if any
         Match (Get_Default_Passphrase_Regexp,
                Output,
                Matched);
         if Matched (0) /= No_Match then
            Force := Cb_Data.Nb_Password_Tries > 0;
            Cb_Data.Nb_Password_Tries := Cb_Data.Nb_Password_Tries + 1;

            declare
               Password : constant String :=
                            Get_Passphrase
                              (Get_Main_Window (Data.Kernel),
                               Output (Matched (1).First .. Matched (1).Last),
                               Force);
            begin
               if Password = "" then
                  Interrupt (Data.Descriptor.all);
               else
                  Send (Data.Descriptor.all, Password);
               end if;
            end;

            return;
         end if;

         --  Retrieve progression.
         Match (Progress_Regexp,
                Output,
                Matched);

         if Matched (0) /= No_Match then
            File_Nb := Natural'Value
              (Output (Matched (1).First .. Matched (1).Last));
            Total_Files := Natural'Value
              (Output (Matched (2).First .. Matched (2).Last));

            if Cb_Data.Synchronous then
               if not Cb_Data.Dialog_Shown then
                  Cb_Data.Dialog_Shown := True;
                  Show_All (Cb_Data.Dialog);
                  Gtk.Main.Grab_Add (Cb_Data.Dialog);
               end if;

               Set_Fraction (Cb_Data.Dialog.Progress,
                             Gdouble (File_Nb) / Gdouble (Total_Files));
               Set_Text (Cb_Data.Dialog.Progress,
                         Natural'Image (File_Nb) & "/" &
                         Natural'Image (Total_Files));

               while Gtk.Main.Events_Pending loop
                  Dead := Gtk.Main.Main_Iteration;
               end loop;

            else
               Set_Progress (Data.Command,
                             Progress => (Activity => Running,
                                          Current  => File_Nb,
                                          Total    => Total_Files));
            end if;
         end if;
      end if;
   end Parse_Rsync_Output;

   ----------------------
   -- Rsync_Terminated --
   ----------------------

   procedure Rsync_Terminated
     (Data : Process_Data; Status : Integer)
   is
      Cb_Data : Rsync_Callback_Data renames
        Rsync_Callback_Data (Data.Callback_Data.all);
   begin
      Cb_Data.Status := Status;

      if Status /= 0 then
         Trace (Me, "rsync terminated with incorrect status");
         GPS.Kernel.Console.Insert
           (Data.Kernel,
            -("Directories are not synchronized properly: rsync " &
              "failed. Please verify your network configuration"),
            Mode => Error);
      end if;

      if Cb_Data.Synchronous then
         if Cb_Data.Dialog_Shown then
            Gtk.Main.Grab_Remove (Cb_Data.Dialog);
         end if;

         Unref (Cb_Data.Dialog);
      end if;

   exception
      when E : others =>
         Trace (Exception_Handle, Exception_Information (E));
   end Rsync_Terminated;

end Remote_Sync_Module;
