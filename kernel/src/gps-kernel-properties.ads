-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2005                            --
--                              AdaCore                              --
--                                                                   --
-- GPS is free  software; you  can redistribute it and/or modify  it --
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

--  This package provides file-specific properties, optionaly persistent

with Glib.Xml_Int;

package GPS.Kernel.Properties is

   ----------------
   -- Properties --
   ----------------

   type Property_Record is abstract tagged null record;
   type Property_Access is access all Property_Record'Class;
   --  A general property that can be associated with a file.
   --  Such properties can be marked as persistent, that is they will exist
   --  from one session of GPS to the next, transparently.

   function Save
     (Property : access Property_Record) return Glib.Xml_Int.Node_Ptr
     is abstract;
   --  Save the property to an XML node. This is the child node of the node
   --  associated with the property.
   --  Null should be returned if the property cannot be saved.
   --  In the end, the XML file will contain something like:
   --     <properties file="...">
   --        <property name="...">save1</property>
   --        <property name="...">save2</property>
   --     </properties>
   --  where "save1" and "save2" are results of Save.

   procedure Load
     (Property : in out Property_Record; From : Glib.Xml_Int.Node_Ptr)
     is abstract;
   --  Load a property from an XML node.
   --  From has been found automatically by GPS based on the property node. If
   --  it doesn't match the type expected by Property, it is likely because two
   --  properties have the same name. In this case, an error message should be
   --  written in the console.

   procedure Destroy (Property : in out Property_Record);
   --  Free the memory occupied by the property. You should always call the
   --  parent's Destroy handler.

   ---------------------------------------
   -- Associating properties with files --
   ---------------------------------------

   procedure Set_File_Property
     (File       : VFS.Virtual_File;
      Name       : String;
      Property   : access Property_Record'Class;
      Persistent : Boolean := False);
   --  Associate a given property with File, so that it can be queries later
   --  through Get_File_Property.
   --  If Persistent is True, the property will be preserved from one session
   --  of GPS to the next.
   --  Property names are case sensitive.

   procedure Get_File_Property
     (Property : out Property_Record'Class;
      File     : VFS.Virtual_File;
      Name     : String;
      Found    : out Boolean);
   --  Return the given named property associated with File.
   --  Found is set to False if there is no such property.
   --  Property names are case sensitive.

   -----------------------------
   -- Specific property types --
   -----------------------------
   --  These are provided for convenience

   type Integer_Property is new Property_Record with record
      Value : Integer;
   end record;
   type Integer_Property_Access is access all Integer_Property'Class;

   type String_Property is new Property_Record with record
      Value : GNAT.OS_Lib.String_Access;
   end record;
   type String_Property_Access is access all String_Property'Class;

   type Boolean_Property is new Property_Record with record
      Value : Boolean;
   end record;
   type Boolean_Property_Access is access all Boolean_Property'Class;

   -----------------------------------------
   -- Saving and restoring all properties --
   -----------------------------------------

   procedure Save_Persistent_Properties
     (Kernel : access Kernel_Handle_Record'Class);
   --  Save all persistent properties for all files in the current project.
   --  This clears the current cache, so that no property will be available
   --  after this call, not even non-persistent ones.
   --  This subprogram should only be called by the kernel itself.

   procedure Restore_Persistent_Properties
     (Kernel : access Kernel_Handle_Record'Class);
   --  Restore persistent properties for the files in the current project.
   --  This subprogram should only be called by the kernel itself.

private
   procedure Destroy (Property : in out String_Property);
   function Save
     (Property : access String_Property) return Glib.Xml_Int.Node_Ptr;
   procedure Load
     (Property : in out String_Property; From : Glib.Xml_Int.Node_Ptr);
   --  See inherited documentation

   function Save
     (Property : access Integer_Property) return Glib.Xml_Int.Node_Ptr;
   procedure Load
     (Property : in out Integer_Property; From : Glib.Xml_Int.Node_Ptr);
   --  See inherited documentation

   function Save
     (Property : access Boolean_Property) return Glib.Xml_Int.Node_Ptr;
   procedure Load
     (Property : in out Boolean_Property; From : Glib.Xml_Int.Node_Ptr);
   --  See inherited documentation

end GPS.Kernel.Properties;
