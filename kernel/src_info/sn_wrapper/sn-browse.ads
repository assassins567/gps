package SN.Browse is
   Unlink_Failure    : exception;
   Spawn_Failure     : exception;
   Temp_File_Failure : exception;

   DB_File_Name     : constant String := "data";
   --  Name of the SN database files

   Xref_Suffix      : constant String := ".xref";
   --  Extension used for cross reference files

   procedure Browse (File_Name, DB_Directory, Browser_Name,
                     DBUtils_Path : in String);
   --  Executes given browser on the file so that all database files
   --  should be placed in the specified directory.
   --  A number of exceptions may be thrown to signal error during
   --  process spawning, file unlinking...
   --  NOTE: directory names should not contain trailing slashes

   procedure Generate_Xrefs (DB_Directory, DBUtils_Path : in String);
   --  Removes .by and .to tables in the DB_Directory and
   --  executes "cat *.xref | dbimp" so that generated cross
   --  reference tables should lie in the DB_Directory.
   --  NOTE: directory names should not contain trailing slashes
end SN.Browse;

