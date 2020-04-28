Function Test-Function {
    param (
        [Parameter(Position=0)]
        [String]
        $First,

        [Parameter(Position=1)]
        [String]
        $Second,

        [Int]
        $Third,

        [Switch]
        $Switch
    )

    "First: $First, Second: $Second, Third: $Third, Switch: $($Switch.IsPresent)"
}

# 1. Basic splatting - same as 'New-Item -Path /tmp/test_dir -ItemType Directory -Force
$params = @{
    First = 'first value'
    Second = 'second value'
    Switch = $true
}
Test-Function @params

# 2. Splatting with an array
$params = @('first value', 'second value')
Test-Function @params

# 3. Multiple splats
$params1 = @{
    First = 'first value'
}
$params2 = @{
    Second = 'second value'
}
Test-Function @params1 @params2

Test-Function @params1 @params2 -Third 3

Test-Function -Switch @params1 @params2

# 4. Splatting with optional parameters
function Get-Conditional {
    $true
}

$params = @{ First = 'first value' }
if (Get-Conditional) {
    $params.Second = 'second value'
}
Test-Function @params

# 5. Removing a parameter in a splat
$params.Remove('First')
Test-Function @params

# 6. Passing along a splatted argument
Function Test-SuperFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Prefix,

        [String]
        $First,

        [String]
        $Second
    )

    # Because -Prefix isn't a valid parameter for Test-Function we need to remove it
    $null = $PSBoundParameters.Remove('Prefix')

    "$($Prefix): $(Test-Function @PSBoundParameters -Switch)"
}

$params = @{
    Prefix = 'My prefix'
    First = 'first'
}
Test-SuperFunction @params -Second 'second'
