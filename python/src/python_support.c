/*-------------------------------------------------------------------
                               G P S                               --
                                                                   --
                     Copyright (C) 2003                            --
                            ACT-Europe                             --
                                                                   --
 GPS is free  software; you can  redistribute it and/or modify  it --
 under the terms of the GNU General Public License as published by --
 the Free Software Foundation; either version 2 of the License, or --
 (at your option) any later version.                               --
                                                                   --
 This program is  distributed in the hope that it will be  useful, --
 but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
 General Public License for more details. You should have received --
 a copy of the GNU General Public License along with this library; --
 if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
 Place - Suite 330, Boston, MA 02111-1307, USA.                    --
---------------------------------------------------------------------*/

#include <Python.h>

void ada_py_incref (PyObject* obj) {
  Py_INCREF (obj);
}

void ada_py_decref (PyObject* obj) {
  Py_DECREF (obj);
}

void ada_py_xincref (PyObject* obj) {
  Py_XINCREF (obj);
}

void ada_py_xdecref (PyObject* obj) {
  Py_XDECREF (obj);
}

int ada_pystring_check (PyObject* obj) {
  return PyString_Check (obj);
}

int ada_pyint_check (PyObject* obj) {
  return PyInt_Check (obj);
}

int ada_pyfunction_check (PyObject* obj) {
  return PyFunction_Check (obj);
}

PyObject* ada_pyfunction_get_globals (PyObject* obj) {
  return PyFunction_GET_GLOBALS (obj);
}

PyObject* ada_pyfunction_get_code (PyObject* obj) {
  return PyFunction_GET_CODE (obj);
}

PyObject* ada_pyfunction_get_closure (PyObject* obj) {
  return PyFunction_GET_CLOSURE (obj);
}

PyObject* ada_pyfunction_get_defaults (PyObject* obj) {
  return PyFunction_GET_DEFAULTS (obj);
}

PyObject* ada_PyEval_EvalCodeEx
  (PyObject *co,
   PyObject *globals,
   PyObject *locals,
   PyObject *args,
   PyObject *kwds,
   PyObject *defs,
   PyObject *closure)
{
  PyObject **k, **d;
  PyObject* result;
  int nk, nd;

  if (defs != NULL && PyTuple_Check(defs)) {
     d = &PyTuple_GET_ITEM((PyTupleObject *)defs, 0);
     nd = PyTuple_Size(defs);
  } else {
     d = NULL;
     nd = 0;
  }

  if (kwds != NULL && PyDict_Check(kwds)) {
     int pos, i;
     nk = PyDict_Size(kwds);
     k  = PyMem_NEW(PyObject *, 2*nk);
     if (k == NULL) {
        PyErr_NoMemory();
        return NULL;
     }
     pos = i = 0;
     while (PyDict_Next(kwds, &pos, &k[i], &k[i+1]))
        i += 2;
      nk = i/2;
      /* XXX This is broken if the caller deletes dict items! */
  } else {
     k = NULL;
     nk = 0;
  }

  result = (PyObject*) PyEval_EvalCodeEx
    (co, globals, locals,
    &PyTuple_GET_ITEM (args, 0), PyTuple_Size (args), k, nk, d, nd, closure);

  if (k != NULL) {
    PyMem_DEL (k);
  }

  return result;
}


int ada_pycobject_check (PyObject* obj) {
  return PyCObject_Check (obj);
}

int ada_pytuple_check (PyObject* obj) {
  return PyTuple_Check (obj);
}

int ada_pylist_check (PyObject* obj) {
  return PyList_Check (obj);
}

int ada_pyinstance_check (PyObject* obj) {
  return PyInstance_Check (obj);
}

PyTypeObject* ada_gettypeobject (PyObject* obj) {
  return (PyTypeObject*)(obj->ob_type);
}

int ada_python_api_version () {
  return PYTHON_API_VERSION;
}

PyObject* ada_py_none () {
  return Py_None;
}

PyObject* ada_py_false() {
  return Py_False;
}

PyObject* ada_py_true() {
  return Py_True;
}
