[CmdletBinding()]
param(
    [ValidateScript({
        $text = if ($_ -is [string] -or
            $_ -is [byte] -or $_ -is [uint16] -or $_ -is [uint32] -or $_ -is [uint64] -or
            $_ -is [sbyte] -or $_ -is [int16] -or $_ -is [int32] -or $_ -is [int64]) {
            [string]$_
        }
        else {
            return $false
        }

        [long]$parsed = 0
        $text -match '^[0-9]+$' -and
            [long]::TryParse(
                $text,
                [System.Globalization.NumberStyles]::None,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$parsed
            )
    })]
    [object]$N = 0
)

function Test-NonNegativeInt64 {
    param(
        [Parameter(Mandatory)]
        [object]$Value
    )

    if ($Value -isnot [string] -and
        $Value -isnot [byte] -and $Value -isnot [uint16] -and
        $Value -isnot [uint32] -and $Value -isnot [uint64] -and
        $Value -isnot [sbyte] -and $Value -isnot [int16] -and
        $Value -isnot [int32] -and $Value -isnot [int64]) {
        return $false
    }

    $text = [string]$Value
    [long]$parsed = 0
    return $text -match '^[0-9]+$' -and
        [long]::TryParse(
            $text,
            [System.Globalization.NumberStyles]::None,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$parsed
        )
}

function Get-Fibonacci {
    [OutputType([System.Numerics.BigInteger])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-NonNegativeInt64 -Value $_ })]
        [object]$N
    )

    [long]$validatedN = $N
    [System.Numerics.BigInteger]$previous = 0
    [System.Numerics.BigInteger]$current = 1

    for ([long]$index = 0; $index -lt $validatedN; $index++) {
        $next = $previous + $current
        $previous = $current
        $current = $next
    }

    return $previous
}

if ($MyInvocation.InvocationName -ne '.') {
    [long]$validatedN = $N
    $value = Get-Fibonacci -N $validatedN
    Write-Output "Fibonacci($validatedN) = $value"
}
