using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

namespace Curso.Tools;

public static class ValidationExtensions {
    public static IEnumerable<ValidationResult> Validate(this object obj) {
        var validationResults = new List<ValidationResult>();
        var context = new ValidationContext(obj, null, null);
        Validator.TryValidateObject(obj, context, validationResults, true);
        return validationResults;
    }
    public static bool IsValid(this object obj) {
        return !IsInvalid(obj);
    }
    public static bool IsInvalid(this object obj) {
        return Validate(obj).Any();
    }
}

[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter,
        AllowMultiple = false)]
public class NIFAttribute : ValidationAttribute {
    public NIFAttribute() : this("No es un NIF válido.") { }
    public NIFAttribute(Func<string> errorMessageAccessor) : base(errorMessageAccessor) { }
    public NIFAttribute(string errorMessage) : base(errorMessage) { }
    public string DefaultErrorMessage => ErrorMessageString;
    protected override ValidationResult IsValid(object value, ValidationContext validationContext) {
        if(value == null) return ValidationResult.Success;
        if(value is String cad) {
            cad = cad.ToUpper();
            if(Regex.IsMatch(cad, @"^\d{2,8}[A-Z]$") &&
                cad[^1] == "TRWAGMYFPDXBNJZSQVHLCKE"[(int)(long.Parse(cad[0..^1]) % 23)])
                return ValidationResult.Success;
        }
        return new ValidationResult($"{validationContext.DisplayName}: {ErrorMessageString}");
    }
}
