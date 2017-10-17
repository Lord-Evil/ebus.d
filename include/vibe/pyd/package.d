import std.stdio;
import std.range;

import vibe.data.bson;

import pyd.pyd, pyd.embedded;
import deimos.python.Python;

PyObject* vibe_json_to_python(Json json) {
    switch(json.type) {
        case Json.Type.undefined: 
            return d_to_python!Object(null);
        case Json.Type.null_: 
            return d_to_python!Object(null);
        case Json.Type.bool_: 
            return d_to_python(json.get!bool);
        case Json.Type.int_: 
            return d_to_python(json.get!int);
        case Json.Type.float_: 
            return d_to_python(json.get!double);
        case Json.Type.string: 
            return d_to_python(json.get!string);
        case Json.Type.array: 
            return d_to_python(json.get!(Json[]));
        case Json.Type.object: 
            return d_to_python(json.get!(Json[string]));
        default:
            PyErr_SetString(PyExc_RuntimeError, (
                "D conversion function vibe_json_to_python failed with type " 
                ~ typeid(Json).toString()).ptr);
            return null;
    }
}

Json python_to_vibe_json(PyObject* py) {
    if (py == cast(PyObject*) Py_None()) {
        return Json(null);
    }else if(PyBool_Check(py)) {
        return Json(python_to_d!bool(py));
    }else if(PyFloat_Check(py)) {
        return Json(python_to_d!double(py));
    }else if(isPyNumber(py)) {
        return Json(python_to_d!long(py));
    } else if (PyBytes_Check(py) || PyUnicode_Check(py)) {
        return Json(python_to_d!string(py));
    }else if(PySequence_Check(py)) {
        return Json(python_to_d!(Json[])(py));
    }else if (PyDict_Check(py) || PyMapping_Check(py)) {
        return Json(python_to_d!(Json[string])(py));
    }else {
        could_not_convert!(Json)(py);
        assert(0);
    }
}

version(unittest) {
static this() {
    py_init();
    ex_d_to_python(&vibe_json_to_python);
    ex_python_to_d(&python_to_vibe_json);
}
}

unittest {
    auto context = new InterpContext();
    context.i = Json(1);
    Json i = context.i.to_d!Json();
    assert(i.get!int == 1);
}

unittest {
    auto context = new InterpContext();
    context.i = Json(1.1);
    Json i = context.i.to_d!Json();
    assert(i.get!double == 1.1);
}

unittest {
    auto context = new InterpContext();
    context.i = Json("hi mom");
    Json i = context.i.to_d!Json();
    assert(i.get!string == "hi mom");
}

unittest {
    auto context = new InterpContext();
    context.i = Json([Json("hi mom")]);
    Json i = context.i.to_d!Json();
    assert(i.get!(Json[])[0].get!string == "hi mom");
}

unittest {
    auto context = new InterpContext();
    Json json = Json.emptyObject;
    json.foobar = "hi mom";
    context.i = json;
    Json i = context.i.to_d!Json();
    assert(i.get!(Json[string])["foobar"].get!string == "hi mom");
}
