BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot 'math-tool.ps1'
    $dotSourceOutput = . $scriptPath
}

Describe 'math-tool loading' {
    It 'writes no output when dot-sourced' {
        $dotSourceOutput | Should -BeNullOrEmpty
    }
}

Describe 'Get-Fibonacci' {
    It 'returns <Expected> for <N>' -TestCases @(
        @{ N = 0; Expected = 0 }
        @{ N = 1; Expected = 1 }
        @{ N = 6; Expected = 8 }
        @{ N = 100; Expected = [System.Numerics.BigInteger]::Parse('354224848179261915075') }
    ) {
        param($N, $Expected)

        Get-Fibonacci -N $N | Should -Be $Expected
    }

    It 'rejects negative inputs' {
        { Get-Fibonacci -N -1 } | Should -Throw
    }

    It 'rejects fractional inputs' {
        { Get-Fibonacci -N 1.5 } | Should -Throw
    }
}

Describe 'math-tool CLI' {
    It 'writes exactly one result line for <N>' -TestCases @(
        @{ N = 0; Expected = 0 }
        @{ N = 1; Expected = 1 }
        @{ N = 6; Expected = 8 }
        @{ N = 100; Expected = [System.Numerics.BigInteger]::Parse('354224848179261915075') }
    ) {
        param($N, $Expected)

        $standardErrorPath = Join-Path $TestDrive "math-tool-$N.stderr"
        $standardOutput = & pwsh -NoLogo -NoProfile -File $scriptPath -N $N 2> $standardErrorPath
        $exitCode = $LASTEXITCODE

        $exitCode | Should -Be 0
        (Get-Content -LiteralPath $standardErrorPath -Raw) | Should -BeNullOrEmpty
        @($standardOutput).Count | Should -Be 1
        $standardOutput | Should -Be "Fibonacci($N) = $Expected"
    }

    It 'rejects fractional inputs' {
        $standardErrorPath = Join-Path $TestDrive 'math-tool-fractional.stderr'
        $standardOutput = & pwsh -NoLogo -NoProfile -File $scriptPath -N 1.5 2> $standardErrorPath
        $exitCode = $LASTEXITCODE

        $exitCode | Should -Not -Be 0
        $standardOutput | Should -BeNullOrEmpty
        (Get-Content -LiteralPath $standardErrorPath -Raw) | Should -Not -BeNullOrEmpty
    }
}
