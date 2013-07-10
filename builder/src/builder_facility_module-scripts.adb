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

with GNATCOLL.Scripts;           use GNATCOLL.Scripts;

with Build_Configurations;       use Build_Configurations;
with Commands.Builder.Scripts;   use Commands.Builder.Scripts;
with GPS.Kernel;                 use GPS.Kernel;
with GPS.Kernel.Scripts;         use GPS.Kernel.Scripts;
with GPS.Intl;                   use GPS.Intl;

package body Builder_Facility_Module.Scripts is

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Shell_Handler
     (Data    : in out Callback_Data'Class;
      Command : String);
   --  Shell command handler

   -------------------
   -- Shell_Handler --
   -------------------

   procedure Shell_Handler
     (Data    : in out Callback_Data'Class;
      Command : String)
   is
      Target_Class : constant Class_Type :=
                       Get_Target_Class (Get_Kernel (Data));
      Kernel       : constant Kernel_Handle := Get_Kernel (Data);
   begin
      if Command = "hide" then
         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Get_Target_Name (Inst);
            Ref  : constant Target_Access
              := Get_Target_From_Name (Registry, Name);
         begin
            if Ref = null then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Visible (Ref, False);

            Refresh_Graphical_Elements;
         end;

      elsif Command = "show" then
         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Get_Target_Name (Inst);
            Ref  : constant Target_Access
              := Get_Target_From_Name (Registry, Name);
         begin
            if Ref = null then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Visible (Ref, True);

            Refresh_Graphical_Elements;
         end;

      elsif Command = "remove" then
         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Get_Target_Name (Inst);
         begin
            if Name = "" then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Remove_Target (Registry, Name);

            Refresh_Graphical_Elements;
            Save_Targets;
         end;

      elsif Command = "clone" then
         declare
            Inst : constant Class_Instance := Nth_Arg (Data, 1, Target_Class);
            Name : constant String := Get_Target_Name (Inst);
            New_Name     : constant String := Nth_Arg (Data, 2);
            New_Category : constant String := Nth_Arg (Data, 3);
         begin
            if Name = "" then
               Set_Error_Msg (Data, -"Invalid target");
               return;
            end if;

            Duplicate_Target (Registry, Name, New_Name, New_Category);

            Refresh_Graphical_Elements;
            Save_Targets;
         end;

      elsif Command = "set_build_mode" then
         Kernel.Set_Build_Mode (Nth_Arg (Data, 1, ""));
      end if;
   end Shell_Handler;

   -----------------------
   -- Register_Commands --
   -----------------------

   procedure Register_Commands (Kernel : GPS.Kernel.Kernel_Handle) is
      Target_Class : constant Class_Type := Get_Target_Class (Kernel);
   begin
      Commands.Builder.Scripts.Register_Commands (Kernel);

      Register_Command
        (Kernel, "hide",
         Minimum_Args => 0,
         Maximum_Args => 0,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "show",
         Minimum_Args => 0,
         Maximum_Args => 0,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "remove",
         Minimum_Args => 0,
         Maximum_Args => 0,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Register_Command
        (Kernel, "clone",
         Minimum_Args => 1,
         Maximum_Args => 2,
         Class        => Target_Class,
         Handler      => Shell_Handler'Access);

      Bind_Default_Key (Kernel      => Kernel,
                        Action      => (-"Build Main Number 1"),
                        Default_Key => "F4");
      Bind_Default_Key (Kernel      => Kernel,
                        Action      => (-"Run Main Number 1"),
                        Default_Key => "shift-F2");
      Bind_Default_Key (Kernel      => Kernel,
                        Action      => -"Custom Build...",
                        Default_Key => "F9");
      Bind_Default_Key (Kernel      => Kernel,
                        Action      => -"Compile File",
                        Default_Key => "shift-F4");

      --  Global commands

      Register_Command (Kernel        => Kernel,
                        Command       => "set_build_mode",
                        Minimum_Args  => 1,
                        Maximum_Args  => 1,
                        Handler       => Shell_Handler'Access);
   end Register_Commands;

end Builder_Facility_Module.Scripts;
