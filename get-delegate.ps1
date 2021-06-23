
param([type] $type, [ScriptBlock] $scriptBlock)

# Helper function to emit an IL opcode
function emit($opcode)
{
    if ( ! ($op = [System.Reflection.Emit.OpCodes]::($opcode)))
    {
        throw "new-method: opcode '$opcode' is undefined"
    }

    if ($args.Length -gt 0)
    {
        $ilg.Emit($op, $args[0])
    }
    else
    {
        $ilg.Emit($op)
    }
}

# Get the method info for this delegate invoke...
$delegateInvoke = $type.GetMethod("Invoke")

# Get the argument type signature for the delegate invoke
$parameters = @($delegateInvoke.GetParameters())
$returnType = $delegateInvoke.ReturnParameter.ParameterType

$argList = new-object Collections.ArrayList
[void] $argList.Add([ScriptBlock])
foreach ($p in $parameters)
{
    [void] $argList.Add($p.ParameterType);
}

$dynMethod = new-object reflection.emit.dynamicmethod ("",
    $returnType, $argList.ToArray(), [object], $false)
$ilg = $dynMethod.GetILGenerator()

# Place the scriptblock on the stack for the method call
emit Ldarg_0

emit Ldc_I4 ($argList.Count - 1)  # Create the parameter array
emit Newarr ([object])

for ($opCount = 1; $opCount -lt $argList.Count; $opCount++)
{
    emit Dup                    # Dup the array reference
    emit Ldc_I4 ($opCount - 1); # Load the index
    emit Ldarg $opCount         # Load the argument
    if ($argList[$opCount].IsValueType) # Box if necessary
	{
        emit Box
	}
    emit Stelem ([object])  # Store it in the array
}

# Now emit the call to the ScriptBlock invoke method
emit Call ([ScriptBlock].GetMethod("InvokeReturnAsIs"))

if ($returnType -eq [void])
{
    # If the return type is void, pop the returned object
    emit Pop
}
else
{
    # Otherwise emit code to convert the result type which looks
    # like LanguagePrimitives.ConvertTo(value, type)

    $signature = [object], [type]
    $convertMethod =
        [Management.Automation.LanguagePrimitives].GetMethod(
            "ConvertTo", $signature);
    $GetTypeFromHandle = [Type].GetMethod("GetTypeFromHandle");
    emit Ldtoken $returnType  # And the return type token...
    emit Call $GetTypeFromHandle
    emit Call $convertMethod
}
emit Ret

#
# Now return a delegate from this dynamic method...
#

$dynMethod.CreateDelegate($type, $scriptBlock)
