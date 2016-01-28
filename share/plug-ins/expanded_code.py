"""
This file provides support for displaying Ada expanded code as generated by
GNAT (-gnatGL switch).
"""


import os
import os.path
import distutils.dep_util
import GPS
from gps_utils import *


def create_dg(f, str):
    res = file(f, 'wb')
    first = str.find(
        "\n", str.find("\n", str.find("Source recreated from tree")) + 1) + 2

    if first > 2:
        last = str.find("Source recreated from tree", first)
        res.write(str[first:last - 1])

    res.close()

expanded_code_marks = {}
# A dictionary that associates a source filename with a list of marks

highlighting = "Editor code annotations"
# Name of the style we want to apply for expanded code


def subprogram_bounds(cursor):
    """Return the first and last line of the current subprogram, and (0,0) if
       the current subprogram could not be determined."""
    blocks = {"CAT_PROCEDURE": 1, "CAT_FUNCTION": 1, "CAT_ENTRY": 1,
              "CAT_PROTECTED": 1, "CAT_TASK": 1, "CAT_PACKAGE": 1}

    if cursor.block_type() == "CAT_UNKNOWN":
        return 0, 0

    min = cursor.buffer().beginning_of_buffer()
    while not (cursor.block_type() in blocks) and cursor > min:
        cursor = cursor.block_start() - 1

    if cursor > min:
        return cursor.block_start_line(), cursor.block_end_line()
    else:
        return 0, 0


def clear_dg(source_filename):
    """ Clear dg information for filename """
    global expanded_code_marks

    if source_filename in expanded_code_marks:
        # Remove special lines

        srcbuf = GPS.EditorBuffer.get(GPS.File(source_filename))

        for (mark, lines) in expanded_code_marks[source_filename]:
            srcbuf.remove_special_lines(mark, lines)

        # Empty entry in the dictionary

        expanded_code_marks[source_filename] = []


def edit_dg(dg, source_filename, line, for_subprogram, in_external_editor):
    global highlighting, expanded_code_marks

    # If we are showing the dg in an external editor, simply open this editor
    # and jump to the line
    if in_external_editor:
        buf = GPS.EditorBuffer.get(GPS.File(dg))
        loc = buf.at(1, 1)
        try:
            (frm, to) = loc.search("^-- " + repr(line) + ":", regexp=True)
            if frm:
                buf.current_view().goto(frm.forward_line(1))
        except Exception:
            pass

        return

    clear_dg(source_filename)

    srcbuf = GPS.EditorBuffer.get(GPS.File(source_filename))

    if for_subprogram:
        (block_first, block_last) = subprogram_bounds(
            srcbuf.current_view().cursor())
    else:
        (block_first, block_last) = (0, 0)

    # Read the text of the dg file
    f = open(dg)
    txt = f.read()
    f.close()

    current_code = []
    current_line = 1
    lines = 0

    for line in txt.split("\n"):
        if line.startswith("-- "):
            if current_code:
                if (block_first == 0
                        or (block_first < current_line < block_last)):
                    mark = srcbuf.add_special_line(current_line + 1,
                                                   "\n".join(current_code),
                                                   highlighting)

                    # Add mark to the list of marks

                    mark_num = (mark, len(current_code))

                    if source_filename in expanded_code_marks:
                        expanded_code_marks[source_filename] += [mark_num]
                    else:
                        expanded_code_marks[source_filename] = [mark_num]

            current_line = int(line[3:line.find(":")])
            current_code = []
        else:
            if line != "":
                lines += 1
                current_code.append(line)


# noinspection PyUnusedLocal
def on_exit(process, status, full_output):
    create_dg(process.dg, full_output)
    edit_dg(process.dg, process.source_filename,
            process.line, process.for_subprogram, process.in_external_editor)


def show_gnatdg(for_subprogram=False, in_external_editor=False):
    """Show the .dg file of the current file"""
    GPS.MDI.save_all(False)
    context = GPS.current_context()
    local_file = context.file().name()
    file = context.file().name("Build_Server")
    line = context.location().line()

    try:
        if context.project():
            l = context.project().object_dirs(False)
            prj = ' -P """' + \
                GPS.Project.root().file().name("Build_Server") + '"""'
        else:
            l = GPS.Project.root().object_dirs(False)
            prj = " -a"
    except Exception:
        GPS.Console("Messages").write(
            "Could not obtain project information for this file")
        return

    if l:
        objdir = l[0]
    else:
        objdir = GPS.get_tmp_dir()
        GPS.Console("Messages").write(
            "Could not find an object directory for %s, reverting to %s" %
            (file, objdir))

    dg = os.path.join(objdir, os.path.basename(local_file)) + '.dg'

    if distutils.dep_util.newer(local_file, dg):
        cmd = 'gprbuild -q %s -f -c -u -gnatcdx -gnatws -gnatGL """%s"""' % (
            prj, file)

        GPS.Console("Messages").write("Generating " + dg + "...\n")
        proc = GPS.Process(cmd, on_exit=on_exit, remote_server="Build_Server")
        proc.source_filename = local_file
        proc.dg = dg
        proc.line = line
        proc.for_subprogram = for_subprogram
        proc.in_external_editor = in_external_editor
    else:
        edit_dg(dg, local_file, line, for_subprogram, in_external_editor)

#################################
# Register the contextual menus #
#################################


@interactive("Ada", in_ada_file, contextual="Expanded code/Show subprogram",
             name="show expanded code for subprogram", before="Align")
def show_gnatdg_subprogram():
    """Show the expanded code of the current subprogram"""
    show_gnatdg(True)


@interactive("Ada", in_ada_file, contextual="Expanded code/Show entire file",
             name="show expanded code for file", before="Align")
def show_gnatdg_file():
    """Show the .dg file of the current file"""
    show_gnatdg(False)


@interactive(
    "Ada", in_ada_file, contextual="Expanded code/Show in separate editor",
    name="show expanded code in separate editor", before="Align")
def show_gnatdg_separate_editor():
    """Show the expanded code of the current subprogram"""
    show_gnatdg(False, True)


@interactive("Ada", in_ada_file, contextual="Expanded code/Clear",
             name="clear expanded code", before="Align")
def clear_expanded_code():
    """Show the expanded code of the current subprogram"""

    context = GPS.current_context()
    clear_dg(context.file().name())
