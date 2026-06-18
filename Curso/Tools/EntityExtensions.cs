using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;

namespace Curso.Tools;

public static class EntityExtensions {
    public static string ToPrint(this object obj) {
        var valores = obj.GetType()
            .GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .Select(p => $"{p.Name}: {p.GetValue(obj) ?? "null"}");
        return $"{obj.GetType().Name} {{ {string.Join(", ", valores)} }}";
    } 
}
